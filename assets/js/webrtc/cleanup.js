export function cleanup(ctx) {
  ctx.pendingCandidates = [];
  ctx.remoteDescSet = false;
  ctx.streamUserMap = new Map();
  ctx._pendingStreams = new Map();
  ctx._attachedStreams = new Set();
  ctx._playingStreams = new Set();

  if (ctx.pc) {
    ctx.pc.ontrack = null;
    ctx.pc.onicecandidate = null;
    ctx.pc.oniceconnectionstatechange = null;
    ctx.pc.close();
    ctx.pc = null;
  }

  if (ctx.stream) {
    ctx.stream.getTracks().forEach((t) => t.stop());
    ctx.stream = null;
  }

  document.querySelectorAll("video[id^='video-']").forEach((el) => {
    if (el.id === "video-me") return;
    el.srcObject = null;
    delete el.dataset.streamId;
    el.classList.add("opacity-0");
  });

  document.querySelectorAll("[id^='connecting-']").forEach((el) => {
    const span = el.querySelector("span");
    if (span) span.textContent = "Disconnected";
    el.style.opacity = "1";
    el.style.pointerEvents = "";
  });
}
