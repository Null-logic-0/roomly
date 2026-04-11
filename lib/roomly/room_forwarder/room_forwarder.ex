defmodule Roomly.RoomForwarder do
  use GenServer

  @moduledoc """
  GenServer that orchestrates a real-time WebRTC room session.

  This is the central coordinator that connects:

  - Signaling layer (SDP offer/answer, ICE, peer lifecycle)
  - Media layer (RTP/RTCP forwarding)
  - Peer state layer (connections, track mappings)

  Responsibilities:
  - Managing room-scoped peer lifecycle
  - Routing WebRTC events to correct subsystems
  - Maintaining in-memory session state
  - Coordinating media + signaling flows

  This module does NOT implement:
  - WebRTC protocol logic (Signaling module handles that)
  - RTP/RTCP processing (MediaForwarder handles that)
  - Pure state mutations (PeerState handles that)
  """

  alias Roomly.RoomForwarder.{Signaling, MediaForwarder, PeerState}

  def start_link(slug) do
    GenServer.start_link(__MODULE__, slug, name: via(slug))
  end

  def via(slug), do: {:via, Registry, {Roomly.Registry, "forwarder:#{slug}"}}

  @doc """
  Handles an incoming SDP offer from a peer.

  Delegates to Signaling module which:
  - Creates PeerConnection
  - Attaches media tracks
  - Generates SDP answer
  - Performs renegotiation if needed

  Returns:
  - {:ok, answer_json}
  """
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

  @doc """
  Entry point for WebRTC SDP offer negotiation.

  This is the synchronous handshake that establishes a peer connection.
  """
  def handle_call({:offer, user_id, offer_json}, _from, state) do
    {:ok, answer_json, state} = Signaling.handle_offer(user_id, offer_json, state)
    {:reply, {:ok, answer_json}, state}
  end

  @doc """
  Handles asynchronous WebRTC signaling events:
  - SDP answers
  - ICE candidates
  - Peer removal

  Delegates logic to Signaling module.
  """
  def handle_cast({:answer, user_id, answer_json}, state) do
    {:noreply, Signaling.handle_answer(user_id, answer_json, state)}
  end

  def handle_cast({:ice_candidate, user_id, candidate_json}, state) do
    {:noreply, Signaling.handle_ice_candidate(user_id, candidate_json, state)}
  end

  def handle_cast({:remove_peer, user_id}, state) do
    {:noreply, Signaling.remove_peer(user_id, state)}
  end

  @doc """
  Routes runtime WebRTC events from ExWebRTC into subsystem handlers.

  Event categories:
  - ICE candidates → MediaForwarder
  - RTP packets → MediaForwarder
  - RTCP feedback → MediaForwarder
  - Track events → MediaForwarder
  - Connection state changes → MediaForwarder/PeerState
  - Process crashes → PeerState cleanup

  This is the real-time media/event dispatch loop of the system.
  """
  def handle_info({:DOWN, _ref, :process, pc_pid, _reason}, state) do
    {:noreply, PeerState.maybe_remove_pc(state, pc_pid)}
  end

  def handle_info({:ex_webrtc, pc_pid, {:ice_candidate, candidate}}, state) do
    {:noreply, MediaForwarder.handle_ice_candidate_event(pc_pid, candidate, state)}
  end

  def handle_info({:ex_webrtc, pc_pid, {:track, track}}, state) do
    {:noreply, MediaForwarder.handle_track(pc_pid, track, state)}
  end

  def handle_info({:ex_webrtc, _pc_pid, {:rtp, track_id, _rid, packet}}, state) do
    {:noreply, MediaForwarder.handle_rtp(track_id, packet, state)}
  end

  def handle_info({:ex_webrtc, pc_pid, {:rtcp, packets}}, state) do
    {:noreply, MediaForwarder.handle_rtcp(pc_pid, packets, state)}
  end

  def handle_info({:ex_webrtc, pc_pid, {:connection_state_change, new_state}}, state) do
    case MediaForwarder.handle_connection_state_change(pc_pid, new_state, state) do
      {:remove, state} -> {:noreply, state}
      {:keep, state} -> {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:ice_connection_state_change, ice_state}}, state) do
    if ice_state in [:failed, :closed] do
      {:noreply, PeerState.maybe_remove_pc(state, pc_pid)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_webrtc, pc_pid, {:signaling_state_change, :closed}}, state) do
    {:noreply, PeerState.maybe_remove_pc(state, pc_pid)}
  end

  def handle_info({:ex_webrtc, _pc_pid, _event}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}
end
