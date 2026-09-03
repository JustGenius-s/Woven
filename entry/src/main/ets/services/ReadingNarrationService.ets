import { common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
import { ReadingAudioCue } from '../model/ContentModels';
import { musicRendererInfo, PlayerStateMachine } from './MusicPlaybackStateMachine';
import { MusicPlaybackService } from './MusicPlaybackService';

export interface ReadingNarrationSnapshot {
  playing: boolean;
  ready: boolean;
  positionMs: number;
  durationMs: number;
  audioFile: string;
}

export type ReadingNarrationListener = (snapshot: ReadingNarrationSnapshot) => void;

/**
 * Foreground-only narration for a single PDF picture book.
 *
 * Kept separate from MusicPlaybackService: it has no AVSession, no background
 * task, and is released when the reading page disappears.
 */
export class ReadingNarrationService {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static player: media.AVPlayer | undefined = undefined;
  private static machine: PlayerStateMachine = new PlayerStateMachine();
  private static listeners: ReadingNarrationListener[] = [];
  private static audioFile: string = '';
  private static durationMs: number = 0;
  private static positionMs: number = 0;
  private static playing: boolean = false;
  private static ready: boolean = false;
  private static preparing: boolean = false;

  static subscribe(listener: ReadingNarrationListener): void {
    if (ReadingNarrationService.listeners.indexOf(listener) < 0) {
      ReadingNarrationService.listeners.push(listener);
    }
    listener(ReadingNarrationService.snapshot());
  }

  static unsubscribe(listener: ReadingNarrationListener): void {
    const index: number = ReadingNarrationService.listeners.indexOf(listener);
    if (index >= 0) {
      ReadingNarrationService.listeners.splice(index, 1);
    }
  }

  static snapshot(): ReadingNarrationSnapshot {
    return {
      playing: ReadingNarrationService.playing,
      ready: ReadingNarrationService.ready,
      positionMs: ReadingNarrationService.positionMs,
      durationMs: ReadingNarrationService.durationMs,
      audioFile: ReadingNarrationService.audioFile
    };
  }

  static cueAt(cues: ReadingAudioCue[], positionMs: number): ReadingAudioCue | undefined {
    if (cues.length === 0) {
      return undefined;
    }
    let current: ReadingAudioCue = cues[0];
    for (let index: number = 0; index < cues.length; index++) {
      const cue: ReadingAudioCue = cues[index];
      if (positionMs < cue.startMs) {
        return index === 0 ? cue : cues[index - 1];
      }
      current = cue;
      if (positionMs < cue.endMs) {
        return cue;
      }
    }
    return current;
  }

  static firstCueOnPage(cues: ReadingAudioCue[], page: number): ReadingAudioCue | undefined {
    for (let index: number = 0; index < cues.length; index++) {
      if (cues[index].page === page) {
        return cues[index];
      }
    }
    return undefined;
  }

  static nearestCuePage(cues: ReadingAudioCue[], page: number): number {
    const exact: ReadingAudioCue | undefined = ReadingNarrationService.firstCueOnPage(cues, page);
    if (exact !== undefined) {
      return exact.page;
    }
    let next: ReadingAudioCue | undefined = undefined;
    let previous: ReadingAudioCue | undefined = undefined;
    for (let index: number = 0; index < cues.length; index++) {
      const cue: ReadingAudioCue = cues[index];
      if (cue.page > page && (next === undefined || cue.page < next.page)) {
        next = cue;
      }
      if (cue.page < page && (previous === undefined || cue.page > previous.page)) {
        previous = cue;
      }
    }
    if (next !== undefined) {
      return next.page;
    }
    if (previous !== undefined) {
      return previous.page;
    }
    return page;
  }

  static async prepare(context: common.Context, audioFile: string, durationMs: number): Promise<void> {
    if (ReadingNarrationService.audioFile === audioFile && ReadingNarrationService.ready &&
      ReadingNarrationService.player !== undefined) {
      return;
    }
    ReadingNarrationService.context = context as common.UIAbilityContext;
    await ReadingNarrationService.load(audioFile, durationMs);
  }

  static async toggle(): Promise<void> {
    if (ReadingNarrationService.playing) {
      await ReadingNarrationService.pause();
      return;
    }
    await ReadingNarrationService.play();
  }

  static async play(): Promise<void> {
    if (ReadingNarrationService.player === undefined || !ReadingNarrationService.ready) {
      return;
    }
    try {
      await MusicPlaybackService.pause();
    } catch (error) {
      // Music may not have a prepared source.
    }
    const state: string = ReadingNarrationService.machine.state;
    if (state === 'completed') {
      await ReadingNarrationService.seek(0);
    }
    try {
      await ReadingNarrationService.player.play();
    } catch (error) {
      // Operate-not-permit is recovered on the next toggle.
    }
  }

  static async pause(): Promise<void> {
    if (ReadingNarrationService.player === undefined || !ReadingNarrationService.playing) {
      return;
    }
    try {
      await ReadingNarrationService.player.pause();
    } catch (error) {
      ReadingNarrationService.playing = false;
      ReadingNarrationService.notify();
    }
  }

  static async seek(positionMs: number): Promise<void> {
    if (ReadingNarrationService.player === undefined || !ReadingNarrationService.ready) {
      return;
    }
    const duration: number = Math.max(0, ReadingNarrationService.durationMs);
    const next: number = Math.max(0, Math.min(positionMs, duration > 0 ? duration : positionMs));
    try {
      ReadingNarrationService.player.seek(next, media.SeekMode.SEEK_CLOSEST);
      ReadingNarrationService.positionMs = next;
      ReadingNarrationService.notify();
    } catch (error) {
      // Seek is ignored when the player is still initializing.
    }
  }

  static async release(): Promise<void> {
    const path: string = ReadingNarrationService.audioFile;
    ReadingNarrationService.playing = false;
    ReadingNarrationService.ready = false;
    ReadingNarrationService.positionMs = 0;
    ReadingNarrationService.audioFile = '';
    if (ReadingNarrationService.player !== undefined) {
      try {
        await ReadingNarrationService.player.reset();
      } catch (error) {
        // Already idle.
      }
      try {
        await ReadingNarrationService.player.release();
      } catch (error) {
        // Already released.
      }
      ReadingNarrationService.player = undefined;
    }
    if (ReadingNarrationService.context !== undefined && path.length > 0) {
      try {
        await ReadingNarrationService.context.resourceManager.closeRawFd(path);
      } catch (error) {
        // Already closed.
      }
    }
    ReadingNarrationService.notify();
  }

  private static async load(audioFile: string, durationMs: number): Promise<void> {
    if (ReadingNarrationService.preparing) {
      return;
    }
    ReadingNarrationService.preparing = true;
    ReadingNarrationService.ready = false;
    ReadingNarrationService.playing = false;
    ReadingNarrationService.durationMs = durationMs;
    ReadingNarrationService.positionMs = 0;
    try {
      if (ReadingNarrationService.player !== undefined) {
        try {
          await ReadingNarrationService.player.reset();
        } catch (error) {
          try {
            await ReadingNarrationService.player.release();
          } catch (releaseError) {
            // Recreate below.
          }
          ReadingNarrationService.player = undefined;
        }
        if (ReadingNarrationService.audioFile.length > 0 &&
          ReadingNarrationService.context !== undefined) {
          try {
            await ReadingNarrationService.context.resourceManager.closeRawFd(
              ReadingNarrationService.audioFile);
          } catch (error) {
            // Already closed.
          }
        }
      }
      const player: media.AVPlayer = await ReadingNarrationService.ensurePlayer();
      if (ReadingNarrationService.context === undefined) {
        return;
      }
      const descriptor = await ReadingNarrationService.context.resourceManager.getRawFd(audioFile);
      ReadingNarrationService.audioFile = audioFile;
      player.fdSrc = {
        fd: descriptor.fd,
        offset: descriptor.offset,
        length: descriptor.length
      };
      const initialized: boolean = await ReadingNarrationService.machine.waitFor('initialized', () => false);
      if (!initialized) {
        return;
      }
      player.audioRendererInfo = musicRendererInfo();
      await player.prepare();
      const prepared: boolean = await ReadingNarrationService.machine.waitFor('prepared', () => false);
      ReadingNarrationService.ready = prepared;
      if (prepared && player.duration > 0) {
        ReadingNarrationService.durationMs = player.duration;
      }
    } finally {
      ReadingNarrationService.preparing = false;
      ReadingNarrationService.notify();
    }
  }

  private static async ensurePlayer(): Promise<media.AVPlayer> {
    if (ReadingNarrationService.player !== undefined &&
      ReadingNarrationService.machine.state !== 'released') {
      return ReadingNarrationService.player;
    }
    const player: media.AVPlayer = await media.createAVPlayer();
    ReadingNarrationService.player = player;
    ReadingNarrationService.machine = new PlayerStateMachine();
    player.on('stateChange', (state: media.AVPlayerState, _reason: media.StateChangeReason) => {
      ReadingNarrationService.machine.onStateChange(state);
      ReadingNarrationService.playing = state === 'playing';
      if (state === 'completed') {
        ReadingNarrationService.playing = false;
        ReadingNarrationService.positionMs = ReadingNarrationService.durationMs;
      }
      ReadingNarrationService.notify();
    });
    player.on('timeUpdate', (positionMs: number) => {
      ReadingNarrationService.positionMs = positionMs;
      ReadingNarrationService.notify();
    });
    player.on('durationUpdate', (nextDuration: number) => {
      if (nextDuration > 0) {
        ReadingNarrationService.durationMs = nextDuration;
        ReadingNarrationService.notify();
      }
    });
    player.on('seekDone', (positionMs: number) => {
      ReadingNarrationService.positionMs = positionMs;
      ReadingNarrationService.notify();
    });
    player.on('audioInterrupt', (event: audio.InterruptEvent) => {
      if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
        void ReadingNarrationService.pause();
      }
    });
    player.on('error', (_error: BusinessError) => {
      ReadingNarrationService.playing = false;
      ReadingNarrationService.ready = false;
      ReadingNarrationService.notify();
    });
    return player;
  }

  private static notify(): void {
    const snapshot: ReadingNarrationSnapshot = ReadingNarrationService.snapshot();
    const listeners: ReadingNarrationListener[] = ReadingNarrationService.listeners.slice();
    for (let index: number = 0; index < listeners.length; index++) {
      listeners[index](snapshot);
    }
  }
}
