const WebRTC = {
  mounted() {
    this.pendingCandidates = [];
    this.remoteDescSet = false;
    this.streamUserMap = new Map();
    this._pendingStreams = new Map();
    this._attachedStreams = new Set();
    this._playingStreams = new Set();

    this.pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
    });

    navigator.mediaDevices
      .getUserMedia({ video: true, audio: true })
      .then(async (stream) => {
        this.stream = stream;
        const me = document.getElementById("video-me");
        if (me) {

          me.srcObject = stream;

          me.play()
            .then(() => {
              me.classList.remove("opacity-0");
              const avatar = document.getElementById(`avatar-${this.el.dataset.userId}`);
              if (avatar) avatar.classList.add("opacity-0");
            })
            .catch((err) => {

              if (err.name !== "AbortError") {
                console.error("[WebRTC] local video play failed:", err);
              }
              me.classList.remove("opacity-0");
              const avatar = document.getElementById(`avatar-${this.el.dataset.userId}`);
              if (avatar) avatar.classList.add("opacity-0");
            });
        }

        stream.getTracks().forEach((t) => this.pc.addTrack(t, stream));
        const offer = await this.pc.createOffer();
        await this.pc.setLocalDescription(offer);
        this.pushEvent("webrtc_offer", { offer: JSON.stringify(offer) });
      })
      .catch((err) => console.error("getUserMedia failed:", err));

    this.pc.onicecandidate = ({ candidate }) => {
      if (candidate) {
        this.pushEvent("webrtc_ice", { candidate: JSON.stringify(candidate) });
      }
    };

    this.pc.oniceconnectionstatechange = () => {
      const s = this.pc?.iceConnectionState;
      if (s === "disconnected" || s === "failed") {
        document.querySelectorAll("[id^='connecting-']").forEach(el => {
          const span = el.querySelector("span");
          if (span) span.textContent = s === "failed" ? "Failed" : "Reconnecting...";
          el.style.opacity = "1";
          el.style.pointerEvents = "";
        });
      }
    };

    this.handleEvent("webrtc_answer", async ({ answer }) => {
      await this.pc.setRemoteDescription(JSON.parse(answer));
      this.remoteDescSet = true;
      for (const c of this.pendingCandidates) {
        await this.pc.addIceCandidate(c).catch(console.error);
      }
      this.pendingCandidates = [];
    });

    this.handleEvent("webrtc_renegotiate", async ({ offer }) => {
      await this.pc.setRemoteDescription(JSON.parse(offer));
      const answer = await this.pc.createAnswer();
      await this.pc.setLocalDescription(answer);
      this.pushEvent("webrtc_renegotiate_answer", { answer: JSON.stringify(answer) });
    });

    this.handleEvent("webrtc_signal", async (signal) => {
      if (signal.type === "ice_candidate") {
        const candidate = JSON.parse(signal.candidate);
        if (this.remoteDescSet) {
          await this.pc.addIceCandidate(candidate).catch(console.error);
        } else {
          this.pendingCandidates.push(candidate);
        }
      }
    });

    this.handleEvent("peer_stream_id", ({ user_id, stream_id }) => {
      this.streamUserMap.set(stream_id, user_id);
      const pending = this._pendingStreams.get(stream_id);
      if (pending) {
        this._pendingStreams.delete(stream_id);
        this._attachedStreams.add(stream_id);
        this._attachStream(user_id, pending);
      }
    });

    this.handleEvent("set_mute", ({ muted }) => {
      this.stream?.getAudioTracks().forEach((t) => (t.enabled = !muted));
    });

    this.handleEvent("set_camera", ({ camera_off }) => {
      this.stream?.getVideoTracks().forEach((t) => (t.enabled = !camera_off));
    });

    this.handleEvent("end_call", () => this.cleanup());

    this.pc.ontrack = ({ track, streams }) => {
      const stream = streams[0];
      if (!stream) return;

      if (this._attachedStreams.has(stream.id)) return;

      const userId = this.streamUserMap.get(stream.id);
      if (!userId) {
        this._pendingStreams.set(stream.id, stream);
        return;
      }
      this._attachedStreams.add(stream.id);
      this._attachStream(userId, stream);
    };
  },

  _attachStream(userId, stream, attempt = 0) {
    const el = document.getElementById(`video-${userId}`);

    if (!el) {
      if (attempt >= 60) {
        console.warn(`[WebRTC] video-${userId} never appeared, giving up`);
        return;
      }
      setTimeout(() => this._attachStream(userId, stream, attempt + 1), 50);
      return;
    }

    if (el.dataset.streamId === stream.id && el.srcObject) return;

    const overlay = document.getElementById(`connecting-${userId}`);
    const avatar = document.getElementById(`avatar-${userId}`);

    const reveal = () => {
      el.classList.remove("opacity-0");
      if (overlay) {
        overlay.style.opacity = "0";
        overlay.style.pointerEvents = "none";
      }
      if (avatar) avatar.classList.add("opacity-0");
    };

    el.dataset.streamId = stream.id;

    el.srcObject = stream;

    el.play()
      .then(reveal)
      .catch((err) => {
        if (err.name !== "AbortError") {
          console.error(`[WebRTC] play failed for ${userId}:`, err);
        }
        reveal();
      });
  },

  destroyed() {
    this.cleanup();
  },

  cleanup() {
    this.pendingCandidates = [];
    this.remoteDescSet = false;
    this.streamUserMap = new Map();
    this._pendingStreams = new Map();
    this._attachedStreams = new Set();
    this._playingStreams = new Set();

    if (this.pc) {
      this.pc.ontrack = null;
      this.pc.onicecandidate = null;
      this.pc.oniceconnectionstatechange = null;
      this.pc.close();
      this.pc = null;
    }

    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop());
      this.stream = null;
    }

    document.querySelectorAll("video[id^='video-']").forEach(el => {
      if (el.id === "video-me") return;
      el.srcObject = null;
      delete el.dataset.streamId;
      el.classList.add("opacity-0");
    });

    document.querySelectorAll("[id^='connecting-']").forEach(el => {
      const span = el.querySelector("span");
      if (span) span.textContent = "Disconnected";
      el.style.opacity = "1";
      el.style.pointerEvents = "";
    });
  }
};

export default WebRTC;
