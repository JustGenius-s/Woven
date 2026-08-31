export enum MusicPlaybackPhase {
  IDLE = 0,
  LOADING = 1,
  READY = 2,
  PLAYING = 3,
  PAUSED = 4,
  COMPLETED = 5,
  ERROR = 6
}

export interface MusicPlaybackSnapshot {
  phase: MusicPlaybackPhase;
  trackIndex: number;
  trackId: string;
  positionMs: number;
  durationMs: number;
  error: string;
}

export type MusicPlaybackListener = (snapshot: MusicPlaybackSnapshot) => void;

export function emptyMusicPlaybackSnapshot(): MusicPlaybackSnapshot {
  return {
    phase: MusicPlaybackPhase.IDLE,
    trackIndex: -1,
    trackId: '',
    positionMs: 0,
    durationMs: 0,
    error: ''
  };
}
