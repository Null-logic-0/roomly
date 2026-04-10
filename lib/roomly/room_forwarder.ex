defmodule Roomly.RoomForwarder do
  use GenServer

  alias ExWebRTC.{PeerConnection, MediaStreamTrack, SessionDescription, ICECandidate}

  @ice_servers [%{urls: "stun:stun.l.google.com:19302"}]

  def start_link(slug) do
    GenServer.start_link(__MODULE__, slug, name: via(slug))
  end

  def via(slug), do: {:via, Registry, {Roomly.Registry, "forwarder:#{slug}"}}

  def handle_offer(slug, user_id, offer_json) do
    GenServer.call(via(slug), {:offer, user_id, offer_json})
  end

  def handle_answer(slug, user_id, answer_json) do
    GenServer.cast(via(slug), {:answer, user_id, answer_json})
  end

  def handle_ice_candidate(slug, user_id, candidate_json) do
    GenServer.cast(via(slug), {:ice_candidate, user_id, candidate_json})
  end

  def remove_peer(slug, user_id) do
    GenServer.cast(via(slug), {:remove_peer, user_id})
  end

  def ensure_started(slug) do
    case DynamicSupervisor.start_child(Roomly.ForwarderSupervisor, {__MODULE__, slug}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  # GenServer callbacks

  def init(slug) do
    {:ok,
     %{
       slug: slug,
       peer_connections: %{},
       connected_peers: MapSet.new(),
       out_tracks: %{},
       in_tracks: %{},
       seq_counters: %{}
     }}
  end

  def handle_call({:offer, user_id, offer_json}, _from, state) do
    state =
      case Map.get(state.peer_connections, user_id) do
        nil ->
          state

        old_pc ->
          safe_close(old_pc)
          cleanup_user(state, user_id)
      end

    {:ok, pc} =
      PeerConnection.start_link(
        ice_servers: @ice_servers,
        controlling_process: self()
      )

    Process.monitor(pc)

    state =
      Enum.reduce(state.peer_connections, state, fn {other_id, _other_pc}, acc ->
        stream_id = MediaStreamTrack.generate_stream_id()
        audio_track = MediaStreamTrack.new(:audio, [stream_id])
        video_track = MediaStreamTrack.new(:video, [stream_id])
        {:ok, _} = PeerConnection.add_track(pc, audio_track)
        {:ok, _} = PeerConnection.add_track(pc, video_track)

        Phoenix.PubSub.broadcast(
          Roomly.PubSub,
          "participants:#{acc.slug}",
          {:peer_stream_id, other_id, stream_id, user_id}
        )

        acc
        |> put_in([:out_tracks, {user_id, other_id, :audio}], audio_track.id)
        |> put_in([:out_tracks, {user_id, other_id, :video}], video_track.id)
      end)

    offer =
      offer_json
      |> Jason.decode!()
      |> SessionDescription.from_json()

    :ok = PeerConnection.set_remote_description(pc, offer)
    {:ok, answer} = PeerConnection.create_answer(pc)
    :ok = PeerConnection.set_local_description(pc, answer)

    answer_json =
      answer
      |> SessionDescription.to_json()
      |> Jason.encode!()

    state = put_in(state, [:peer_connections, user_id], pc)

    state =
      Enum.reduce(state.peer_connections, state, fn {other_id, other_pc}, acc ->
        if other_id == user_id do
          acc
        else
          if pc_alive?(other_pc) do
            stream_id = MediaStreamTrack.generate_stream_id()
            audio_track = MediaStreamTrack.new(:audio, [stream_id])
            video_track = MediaStreamTrack.new(:video, [stream_id])
            {:ok, _} = PeerConnection.add_track(other_pc, audio_track)
            {:ok, _} = PeerConnection.add_track(other_pc, video_track)

            Phoenix.PubSub.broadcast(
              Roomly.PubSub,
              "participants:#{acc.slug}",
              {:peer_stream_id, user_id, stream_id, other_id}
            )

            {:ok, renego_offer} = PeerConnection.create_offer(other_pc)
            :ok = PeerConnection.set_local_description(other_pc, renego_offer)

            offer_json_out = renego_offer |> SessionDescription.to_json() |> Jason.encode!()

            Phoenix.PubSub.broadcast(
              Roomly.PubSub,
              "participants:#{acc.slug}",
              {:webrtc_renegotiate, other_id, offer_json_out}
            )

            acc
            |> put_in([:out_tracks, {other_id, user_id, :audio}], audio_track.id)
            |> put_in([:out_tracks, {other_id, user_id, :video}], video_track.id)
          else
            safe_close(other_pc)
            cleanup_user(acc, other_id)
          end
        end
      end)

    {:reply, {:ok, answer_json}, state}
  end

  def handle_cast({:answer, user_id, answer_json}, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        {:noreply, state}

      pc ->
        if pc_alive?(pc) do
          answer =
            answer_json
            |> Jason.decode!()
            |> SessionDescription.from_json()

          :ok = PeerConnection.set_remote_description(pc, answer)
        end

        {:noreply, state}
    end
  end

  def handle_cast({:ice_candidate, user_id, candidate_json}, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        {:noreply, state}

      pc ->
        if pc_alive?(pc) do
          candidate =
            candidate_json
            |> Jason.decode!()
            |> ICECandidate.from_json()

          _ = PeerConnection.add_ice_candidate(pc, candidate)
        end

        {:noreply, state}
    end
  end

  def handle_cast({:remove_peer, user_id}, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        {:noreply, state}

      pc ->
        safe_close(pc)
        {:noreply, cleanup_user(state, user_id)}
    end
  end

  def handle_info({:DOWN, _ref, :process, pc_pid, _reason}, state) do
    {:noreply, maybe_remove_pc(state, pc_pid)}
  end

  # ICE candidate gathered -> push to browser
  def handle_info({:ex_webrtc, pc_pid, {:ice_candidate, candidate}}, state) do
    case find_user_by_pc(state, pc_pid) do
      nil ->
        {:noreply, state}

      user_id ->
        candidate_json = candidate |> ICECandidate.to_json() |> Jason.encode!()

        Phoenix.PubSub.broadcast(
          Roomly.PubSub,
          "participants:#{state.slug}",
          {:webrtc_signal, user_id, %{type: "ice_candidate", candidate: candidate_json}}
        )

        {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:track, track}}, state) do
    case find_user_by_pc(state, pc_pid) do
      nil ->
        {:noreply, state}

      user_id ->
        state = put_in(state, [:in_tracks, track.id], {user_id, track.kind})
        {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:rtp, track_id, _rid, packet}}, state) do
    case find_user_by_pc(state, pc_pid) do
      nil ->
        {:noreply, state}

      source_user_id ->
        case Map.get(state.in_tracks, track_id) do
          {^source_user_id, kind} ->
            state =
              Enum.reduce(state.peer_connections, state, fn {receiver_id, receiver_pc}, acc ->
                if receiver_id == source_user_id do
                  acc
                else
                  out_track_id = Map.get(acc.out_tracks, {receiver_id, source_user_id, kind})

                  peer_ready =
                    out_track_id &&
                      pc_alive?(receiver_pc) &&
                      MapSet.member?(acc.connected_peers, receiver_id)

                  if peer_ready do
                    counter_key = {receiver_id, source_user_id, kind}
                    seq = Map.get(acc.seq_counters, counter_key, 0)
                    next_seq = rem(seq + 1, 65_536)
                    rewritten_packet = %{packet | sequence_number: next_seq}

                    try do
                      PeerConnection.send_rtp(receiver_pc, out_track_id, rewritten_packet)
                    rescue
                      _ -> :ok
                    catch
                      :exit, _ -> :ok
                    end

                    put_in(acc, [:seq_counters, counter_key], next_seq)
                  else
                    acc
                  end
                end
              end)

            {:noreply, state}

          _ ->
            {:noreply, state}
        end
    end
  end

  def handle_info(
        {:ex_webrtc, pc_pid, {:connection_state_change, new_state}},
        state
      ) do
    state =
      case find_user_by_pc(state, pc_pid) do
        nil ->
          state

        user_id ->
          if new_state == :connected do
            update_in(state, [:connected_peers], &MapSet.put(&1, user_id))
          else
            update_in(state, [:connected_peers], &MapSet.delete(&1, user_id))
          end
      end

    if new_state in [:failed, :closed] do
      {:noreply, maybe_remove_pc(state, pc_pid)}
    else
      {:noreply, state}
    end
  end

  def handle_info(
        {:ex_webrtc, pc_pid, {:ice_connection_state_change, ice_state}},
        state
      ) do
    if ice_state in [:failed, :closed] do
      {:noreply, maybe_remove_pc(state, pc_pid)}
    else
      {:noreply, state}
    end
  end

  def handle_info(
        {:ex_webrtc, pc_pid, {:signaling_state_change, :closed}},
        state
      ) do
    {:noreply, maybe_remove_pc(state, pc_pid)}
  end

  def handle_info({:ex_webrtc, _pc_pid, _event}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}

  # ---- Private ----

  defp safe_close(pc) do
    PeerConnection.close(pc)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp pc_alive?(pc) do
    is_pid(pc) && Process.alive?(pc)
  end

  defp find_user_by_pc(state, pc_pid) do
    Enum.find_value(state.peer_connections, fn {user_id, pc} ->
      if pc == pc_pid, do: user_id
    end)
  end

  defp maybe_remove_pc(state, pc_pid) do
    case find_user_by_pc(state, pc_pid) do
      nil ->
        state

      user_id ->
        safe_close(pc_pid)
        cleanup_user(state, user_id)
    end
  end

  defp cleanup_user(state, user_id) do
    in_tracks =
      state.in_tracks
      |> Enum.reject(fn {_track_id, {uid, _kind}} -> uid == user_id end)
      |> Map.new()

    out_tracks =
      state.out_tracks
      |> Enum.reject(fn {{receiver_id, sender_id, _kind}, _} ->
        receiver_id == user_id or sender_id == user_id
      end)
      |> Map.new()

    seq_counters =
      state.seq_counters
      |> Enum.reject(fn {{receiver_id, sender_id, _kind}, _} ->
        receiver_id == user_id or sender_id == user_id
      end)
      |> Map.new()

    state
    |> update_in([:peer_connections], &Map.delete(&1, user_id))
    |> update_in([:connected_peers], &MapSet.delete(&1, user_id))
    |> Map.put(:out_tracks, out_tracks)
    |> Map.put(:in_tracks, in_tracks)
    |> Map.put(:seq_counters, seq_counters)
  end
end
