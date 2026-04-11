export async function setupLocalMedia(ctx) {
  const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
  ctx.stream = stream;

  const me = document.getElementById("video-me");
  if (me) {
    me.srcObject = stream;
    me.play()
      .then(() => {
        me.classList.remove("opacity-0");
        const avatar = document.getElementById(`avatar-${ctx.el.dataset.userId}`);
        if (avatar) avatar.classList.add("opacity-0");
      })
      .catch((err) => {
        if (err.name !== "AbortError") {
          console.error("[WebRTC] local video play failed:", err);
        }
        me.classList.remove("opacity-0");
        const avatar = document.getElementById(`avatar-${ctx.el.dataset.userId}`);
        if (avatar) avatar.classList.add("opacity-0");
      });
  }

  stream.getTracks().forEach((t) => ctx.pc.addTrack(t, stream));
}

export function attachStream(userId, stream, attempt = 0) {
  const el = document.getElementById(`video-${userId}`);

  if (!el) {
    if (attempt >= 60) {
      console.warn(`[WebRTC] video-${userId} never appeared, giving up`);
      return;
    }
    setTimeout(() => attachStream(userId, stream, attempt + 1), 50);
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
}
