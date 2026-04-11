defmodule Roomly.RoomForwarder.PeerState do
  @moduledoc """
  Handles peer-related state management for a Room WebRTC session.

  Responsibilities:
  - Managing PeerConnection ↔ user mappings
  - Cleaning up in/out media tracks on disconnect
  - Finding tracks for RTP/RTCP routing
  - Handling PLI (keyframe requests)
  - Recovering from failed or closed connections

  This module does NOT handle signaling or media transport directly.
  It only maintains and mutates session state.
  """

  @doc """
  Removes all state associated with a disconnected user.

  Cleans:
  - PeerConnection mapping
  - inbound tracks (in_tracks)
  - outbound tracks (out_tracks)
  - connected peer set

  Ensures no stale media routing remains after disconnect.
  """

  alias ExWebRTC.PeerConnection

  def cleanup_user(state, user_id) do
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

  def find_user_by_pc(state, pc_pid) do
    Enum.find_value(state.peer_connections, fn {user_id, pc} ->
      if pc == pc_pid, do: user_id
    end)
  end

  def find_in_track(state, source_user_id, kind) do
    Enum.find_value(state.in_tracks, fn {track_id, {uid, k}} ->
      if uid == source_user_id and k == kind, do: track_id
    end)
  end

  @doc """
  Requests keyframes from all active video sources.

  Used when a new peer joins the room to quickly populate streams.
  """
  def send_pli_for_all_sources(state, _new_user_id) do
    Enum.each(state.peer_connections, fn {source_id, source_pc} ->
      case find_in_track(state, source_id, :video) do
        nil -> :ok
        track_id -> PeerConnection.send_pli(source_pc, track_id)
      end
    end)
  end

  @doc """
  Requests a keyframe (PLI) from a specific user's video stream.

  Used when:
  - a new peer joins
  - renegotiation occurs
  - stream needs refresh

  Ensures video can decode immediately on join.
  """
  def send_pli_for_user(user_id, state) do
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

  def safe_stop(pc) do
    PeerConnection.stop(pc)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  @doc """
  Safely removes a PeerConnection if it exists in state.

  Used when:
  - connection_state changes to :failed or :closed
  - process crashes (:DOWN event)

  Ensures full cleanup via `cleanup_user/2`.
  """
  def maybe_remove_pc(state, pc_pid) do
    case find_user_by_pc(state, pc_pid) do
      nil ->
        state

      user_id ->
        safe_stop(pc_pid)
        cleanup_user(state, user_id)
    end
  end
end
