import { attachStream } from "./media.js";

export function setupPeerConnection(ctx) {
  ctx.pc = new RTCPeerConnection({
    iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
  });

  ctx.pc.onicecandidate = ({ candidate }) => {
    if (candidate) {
      ctx.pushEvent("webrtc_ice", { candidate: JSON.stringify(candidate) });
    }
  };

  ctx.pc.oniceconnectionstatechange = () => {
    const s = ctx.pc?.iceConnectionState;
    if (s === "disconnected" || s === "failed") {
      document.querySelectorAll("[id^='connecting-']").forEach((el) => {
        const span = el.querySelector("span");
        if (span) span.textContent = s === "failed" ? "Failed" : "Reconnecting...";
        el.style.opacity = "1";
        el.style.pointerEvents = "";
      });
    }
  };

  ctx.pc.ontrack = ({ track, streams }) => {
    const stream = streams[0];
    if (!stream) return;

    if (ctx._attachedStreams.has(stream.id)) return;

    const userId = ctx.streamUserMap.get(stream.id);
    if (!userId) {
      ctx._pendingStreams.set(stream.id, stream);
      return;
    }
    ctx._attachedStreams.add(stream.id);
    attachStream(userId, stream);
  };
}

export function bindServerEvents(ctx) {
  ctx.handleEvent("webrtc_answer", async ({ answer }) => {
    await ctx.pc.setRemoteDescription(JSON.parse(answer));
    ctx.remoteDescSet = true;
    for (const c of ctx.pendingCandidates) {
      await ctx.pc.addIceCandidate(c).catch(console.error);
    }
    ctx.pendingCandidates = [];
  });

  ctx.handleEvent("webrtc_renegotiate", async ({ offer }) => {
    await ctx.pc.setRemoteDescription(JSON.parse(offer));
    const answer = await ctx.pc.createAnswer();
    await ctx.pc.setLocalDescription(answer);
    ctx.pushEvent("webrtc_renegotiate_answer", { answer: JSON.stringify(answer) });
  });

  ctx.handleEvent("webrtc_signal", async (signal) => {
    if (signal.type === "ice_candidate") {
      const candidate = JSON.parse(signal.candidate);
      if (ctx.remoteDescSet) {
        await ctx.pc.addIceCandidate(candidate).catch(console.error);
      } else {
        ctx.pendingCandidates.push(candidate);
      }
    }
  });

  ctx.handleEvent("peer_stream_id", ({ user_id, stream_id }) => {
    ctx.streamUserMap.set(stream_id, user_id);
    const pending = ctx._pendingStreams.get(stream_id);
    if (pending) {
      ctx._pendingStreams.delete(stream_id);
      ctx._attachedStreams.add(stream_id);
      attachStream(user_id, pending);
    }
  });

  ctx.handleEvent("set_mute", ({ muted }) => {
    ctx.stream?.getAudioTracks().forEach((t) => (t.enabled = !muted));
  });

  ctx.handleEvent("set_camera", ({ camera_off }) => {
    ctx.stream?.getVideoTracks().forEach((t) => (t.enabled = !camera_off));
  });

  ctx.handleEvent("end_call", () => ctx.cleanup());
}
