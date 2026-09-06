import { ReadingAudioCue } from '../model/ContentModels';

/** Navigation uses real pages/cues, never an estimated audio-to-page ratio. */
export class ReaderNavigation {
  static page(index: number, total: number): number {
    return Math.max(0, Math.min(Math.round(index), Math.max(0, total - 1)));
  }

  static audioTarget(cues: ReadingAudioCue[], positionMs: number, durationMs: number,
    direction: number): number {
    if (cues.length === 0) {
      return Math.max(0, Math.min(positionMs + direction * 15000, durationMs));
    }
    if (direction > 0) {
      for (let index: number = 0; index < cues.length; index++) {
        if (cues[index].startMs > positionMs + 100) {
          return cues[index].startMs;
        }
      }
    } else {
      for (let index: number = cues.length - 1; index >= 0; index--) {
        if (cues[index].startMs < positionMs - 100) {
          return cues[index].startMs;
        }
      }
    }
    return positionMs;
  }

  static time(positionMs: number): string {
    const seconds: number = Math.floor(Math.max(0, positionMs) / 1000);
    return `${Math.floor(seconds / 60)}:${(seconds % 60).toString().padStart(2, '0')}`;
  }

}
