import { createState } from "./state.js";
import { setupLocalMedia } from "./media.js";
import { setupPeerConnection, bindServerEvents } from "./signaling.js";
import { cleanup } from "./cleanup.js";

const WebRTC = {
  mounted() {
    Object.assign(this, createState());

    setupPeerConnection(this);
    bindServerEvents(this);

    setupLocalMedia(this)
      .then(async () => {
        const offer = await this.pc.createOffer();
        await this.pc.setLocalDescription(offer);
        this.pushEvent("webrtc_offer", { offer: JSON.stringify(offer) });
      })
      .catch((err) => console.error("getUserMedia failed:", err));
  },

  destroyed() {
    cleanup(this);
  },

  cleanup() {
    cleanup(this);
  },
};

export default WebRTC;
