defmodule Roomly.RoomForwarder.MediaForwarder do
  @moduledoc """
  Handles real-time media forwarding for a WebRTC room session.

  Responsibilities:
  - RTP forwarding between peers (audio/video streams)
  - RTCP handling (PLI / keyframe requests)
  - Track registration from incoming WebRTC streams
  - ICE signaling propagation to clients
  - Connection state lifecycle handling

  This module is the media pipeline layer of the Room system.

  It does NOT:
  - manage PeerConnection lifecycle (see Signaling)
  - own persistent session state logic (see PeerState)
  """

  alias ExWebRTC.{PeerConnection, ICECandidate}
  alias Roomly.RoomForwarder.PeerState

  @doc """
  Broadcasts ICE candidates to remote peer via PubSub.

  Used for NAT traversal and connection negotiation.
  """
  def handle_ice_candidate_event(pc_pid, candidate, state) do
    case PeerState.find_user_by_pc(state, pc_pid) do
      nil ->
        state

      user_id ->
        candidate_json = candidate |> ICECandidate.to_json() |> Jason.encode!()

        Phoenix.PubSub.broadcast(
          Roomly.PubSub,
          "participants:#{state.slug}",
          {:webrtc_signal, user_id, %{type: "ice_candidate", candidate: candidate_json}}
        )

        state
    end
  end

  @doc """
  Registers incoming media tracks from a PeerConnection.

  Stores mapping:
  track_id -> {user_id, track_kind}

  Used later for RTP routing.
  """
  def handle_track(pc_pid, track, state) do
    case PeerState.find_user_by_pc(state, pc_pid) do
      nil -> state
      user_id -> put_in(state, [:in_tracks, track.id], {user_id, track.kind})
    end
  end

  @doc """
  Forwards RTP packets from a source peer to all connected receivers.

  Flow:
  - Identify source user from track_id
  - Lookup outbound tracks per receiver
  - Forward packet only if receiver is connected

  This is the core media forwarding path.
  """
  def handle_rtp(track_id, packet, state) do
    case Map.get(state.in_tracks, track_id) do
      nil ->
        state

      {source_user_id, kind} ->
        Enum.each(state.peer_connections, fn {receiver_id, receiver_pc} ->
          if receiver_id != source_user_id do
            out_track_id = Map.get(state.out_tracks, {receiver_id, source_user_id, kind})

            if out_track_id && MapSet.member?(state.connected_peers, receiver_id) do
              PeerConnection.send_rtp(receiver_pc, out_track_id, packet)
            end
          end
        end)

        state
    end
  end

  @doc """
  Handles RTCP feedback packets (e.g. PLI - Picture Loss Indication).

  When a PLI is received:
  - Identify requesting peer
  - Find all video sources
  - Request keyframes from those sources

  Ensures video recovery when streams are degraded.
  """
  def handle_rtcp(pc_pid, packets, state) do
    case PeerState.find_user_by_pc(state, pc_pid) do
      nil ->
        state

      receiver_id ->
        for packet <- packets do
          case packet do
            {_track_id, %ExRTCP.Packet.PayloadFeedback.PLI{}} ->
              Enum.each(state.peer_connections, fn {source_id, source_pc} ->
                if source_id != receiver_id do
                  case Map.get(state.in_tracks, PeerState.find_in_track(state, source_id, :video)) do
                    {^source_id, :video} ->
                      PeerConnection.send_pli(
                        source_pc,
                        PeerState.find_in_track(state, source_id, :video)
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

        state
    end
  end

  @doc """
  Handles PeerConnection lifecycle state changes.

  When connected:
  - Requests initial keyframes (PLI) from all sources
  - Marks peer as active

  When failed/closed:
  - Triggers cleanup of PeerConnection state

  Returns:
  - {:keep, state} or {:remove, new_state}
  """
  def handle_connection_state_change(pc_pid, new_state, state) do
    state =
      case PeerState.find_user_by_pc(state, pc_pid) do
        nil ->
          state

        user_id ->
          if new_state == :connected do
            PeerState.send_pli_for_all_sources(state, user_id)
            update_in(state, [:connected_peers], &MapSet.put(&1, user_id))
          else
            update_in(state, [:connected_peers], &MapSet.delete(&1, user_id))
          end
      end

    if new_state in [:failed, :closed] do
      {:remove, PeerState.maybe_remove_pc(state, pc_pid)}
    else
      {:keep, state}
    end
  end
end
