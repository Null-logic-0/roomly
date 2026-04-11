defmodule Roomly.RoomForwarder.Signaling do
  @moduledoc """
  Handles WebRTC signaling for a room session.

  Responsibilities:
  - Processing SDP offers and generating answers
  - Handling SDP answers from peers
  - Managing ICE candidates exchange
  - Creating PeerConnections per user
  - Triggering renegotiation when peers join
  - Broadcasting signaling events via PubSub

  This module coordinates WebRTC setup but does NOT handle:
  - RTP/RTCP media routing (see Media layer)
  - Persistent state storage (see PeerState)
  """
  alias ExWebRTC.{PeerConnection, MediaStreamTrack, SessionDescription, ICECandidate}
  alias Roomly.RoomForwarder.PeerState

  @ice_servers [%{urls: "stun:stun.l.google.com:19302"}]

  @doc """
  Handles a WebRTC SDP offer from a user and creates an answer.

  Flow:
  1. Cleans up existing PeerConnection if it exists
  2. Creates a new PeerConnection
  3. Attaches media tracks for existing peers
  4. Processes incoming SDP offer
  5. Generates and returns SDP answer
  6. Notifies existing peers for renegotiation

  Returns:
  - {:ok, answer_json, updated_state}
  """
  def handle_offer(user_id, offer_json, state) do
    state =
      case Map.get(state.peer_connections, user_id) do
        nil ->
          state

        old_pc ->
          PeerState.safe_stop(old_pc)
          PeerState.cleanup_user(state, user_id)
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

          PeerState.send_pli_for_user(user_id, acc)

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

    {:ok, answer_json, state}
  end

  @doc """
  Applies a remote SDP answer to an existing PeerConnection.

  Used during renegotiation or initial connection handshake.
  """
  def handle_answer(user_id, answer_json, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        state

      pc ->
        answer =
          answer_json
          |> Jason.decode!()
          |> SessionDescription.from_json()

        :ok = PeerConnection.set_remote_description(pc, answer)
        state
    end
  end

  @doc """
  Adds an ICE candidate to an existing PeerConnection.

  Used for NAT traversal and connection establishment.
  """
  def handle_ice_candidate(user_id, candidate_json, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        state

      pc ->
        candidate =
          candidate_json
          |> Jason.decode!()
          |> ICECandidate.from_json()

        _ = PeerConnection.add_ice_candidate(pc, candidate)
        state
    end
  end

  @doc """
  Removes a peer from the signaling layer.

  Stops PeerConnection and triggers full state cleanup.
  Used when a user leaves or disconnects.
  """
  def remove_peer(user_id, state) do
    case Map.get(state.peer_connections, user_id) do
      nil ->
        state

      pc ->
        PeerState.safe_stop(pc)
        PeerState.cleanup_user(state, user_id)
    end
  end
end
