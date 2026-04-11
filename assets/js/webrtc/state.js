export function createState() {
  return {
    pendingCandidates: [],
    remoteDescSet: false,
    streamUserMap: new Map(),
    _pendingStreams: new Map(),
    _attachedStreams: new Set(),
    _playingStreams: new Set(),
    pc: null,
    stream: null,
  };
}

export function resetState(ctx) {
  ctx.pendingCandidates = [];
  ctx.remoteDescSet = false;
  ctx.streamUserMap = new Map();
  ctx._pendingStreams = new Map();
  ctx._attachedStreams = new Set();
  ctx._playingStreams = new Set();
}
