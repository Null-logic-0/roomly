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

  def init(slug) do
    {:ok,
     %{
       slug: slug,
       peer_connections: %{},
       connected_peers: MapSet.new(),
       out_tracks: %{},
       in_tracks: %{}
     }}
  end

  def handle_call({:offer, user_id, offer_json}, _from, state) do
    state =
      case Map.get(state.peer_connections, user_id) do
        nil ->
          state

        old_pc ->
          safe_stop(old_pc)
          cleanup_user(state, user_id)
      end

    {:ok, pc} =
      PeerConnection.start_link(
        ice_servers: @ice_servers,
        controlling_process: self()
      )

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

          send_pli_for_user(user_id, acc)

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
        end
      end)

    {:reply, {:ok, answer_json}, state}
  end

  def handle_cast({:answer, user_id, answer_json}, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        {:noreply, state}

      pc ->
        answer =
          answer_json
          |> Jason.decode!()
          |> SessionDescription.from_json()

        :ok = PeerConnection.set_remote_description(pc, answer)
        {:noreply, state}
    end
  end

  def handle_cast({:ice_candidate, user_id, candidate_json}, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        {:noreply, state}

      pc ->
        candidate =
          candidate_json
          |> Jason.decode!()
          |> ICECandidate.from_json()

        _ = PeerConnection.add_ice_candidate(pc, candidate)
        {:noreply, state}
    end
  end

  def handle_cast({:remove_peer, user_id}, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        {:noreply, state}

      pc ->
        safe_stop(pc)
        {:noreply, cleanup_user(state, user_id)}
    end
  end

  def handle_info({:DOWN, _ref, :process, pc_pid, _reason}, state) do
    {:noreply, maybe_remove_pc(state, pc_pid)}
  end

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

  def handle_info({:ex_webrtc, _pc_pid, {:rtp, track_id, _rid, packet}}, state) do
    case Map.get(state.in_tracks, track_id) do
      nil ->
        {:noreply, state}

      {source_user_id, kind} ->
        Enum.each(state.peer_connections, fn {receiver_id, receiver_pc} ->
          if receiver_id != source_user_id do
            out_track_id = Map.get(state.out_tracks, {receiver_id, source_user_id, kind})

            if out_track_id && MapSet.member?(state.connected_peers, receiver_id) do
              PeerConnection.send_rtp(receiver_pc, out_track_id, packet)
            end
          end
        end)

        {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:rtcp, packets}}, state) do
    case find_user_by_pc(state, pc_pid) do
      nil ->
        {:noreply, state}

      receiver_id ->
        for packet <- packets do
          case packet do
            {_track_id, %ExRTCP.Packet.PayloadFeedback.PLI{}} ->
              Enum.each(state.peer_connections, fn {source_id, source_pc} ->
                if source_id != receiver_id do
                  case Map.get(state.in_tracks, find_in_track(state, source_id, :video)) do
                    {^source_id, :video} ->
                      PeerConnection.send_pli(
                        source_pc,
                        find_in_track(state, source_id, :video)
                      )

                    _ ->
                      :ok
                  end
                end
              end)

            _ ->
              :ok
          end
        end

        {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:connection_state_change, new_state}}, state) do
    state =
      case find_user_by_pc(state, pc_pid) do
        nil ->
          state

        user_id ->
          if new_state == :connected do
            send_pli_for_all_sources(state, user_id)
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

  def handle_info({:ex_webrtc, pc_pid, {:ice_connection_state_change, ice_state}}, state) do
    if ice_state in [:failed, :closed] do
      {:noreply, maybe_remove_pc(state, pc_pid)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:signaling_state_change, :closed}}, state) do
    {:noreply, maybe_remove_pc(state, pc_pid)}
  end

  def handle_info({:ex_webrtc, _pc_pid, _event}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}

  # ---- Private ----

  defp safe_stop(pc) do
    PeerConnection.stop(pc)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
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
        safe_stop(pc_pid)
        cleanup_user(state, user_id)
    end
  end

  defp find_in_track(state, source_user_id, kind) do
    Enum.find_value(state.in_tracks, fn {track_id, {uid, k}} ->
      if uid == source_user_id and k == kind, do: track_id
    end)
  end

  defp send_pli_for_all_sources(state, _new_user_id) do
    Enum.each(state.peer_connections, fn {source_id, source_pc} ->
      case find_in_track(state, source_id, :video) do
        nil -> :ok
        track_id -> PeerConnection.send_pli(source_pc, track_id)
      end
    end)
  end

  defp send_pli_for_user(user_id, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        :ok

      source_pc ->
        case find_in_track(state, user_id, :video) do
          nil -> :ok
          track_id -> PeerConnection.send_pli(source_pc, track_id)
        end
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

    state
    |> update_in([:peer_connections], &Map.delete(&1, user_id))
    |> update_in([:connected_peers], &MapSet.delete(&1, user_id))
    |> Map.put(:out_tracks, out_tracks)
    |> Map.put(:in_tracks, in_tracks)
  end
end
