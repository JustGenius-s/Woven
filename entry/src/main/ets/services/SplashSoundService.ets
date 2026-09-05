import { ApplicationStateChangeCallback, common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';

const WHISTLE_PATH: string = 'audio/splash_train_whistle.wav';

/** A single local cue, bounded by the splash lifetime and system silent mode. */
export class SplashSoundService {
  private pool: media.SoundPool | undefined = undefined;
  private context: common.Context | undefined = undefined;
  private soundId: number = -1;
  private disposed: boolean = false;
  private cueHandled: boolean = false;
  private descriptorOpen: boolean = false;
  private listening: boolean = false;
  private appState: ApplicationStateChangeCallback = {
    onApplicationForeground: () => {},
    onApplicationBackground: () => { void this.release(); }
  };

  async prepare(context: common.Context): Promise<void> {
    if (this.disposed) {
      return;
    }
    this.context = context;
    try {
      context.getApplicationContext().on('applicationStateChange', this.appState);
      this.listening = true;
      // MUSIC uses SoundPool's mixing mode, without interrupting existing audio.
      const pool: media.SoundPool = await media.createSoundPool(1, {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      });
      if (this.disposed) {
        await pool.release();
        return;
      }
      this.pool = pool;
      pool.on('loadComplete', (id: number) => {
        if (!this.disposed) {
          this.soundId = id;
        }
      });
      pool.on('error', () => { this.soundId = -1; });
      const descriptor = await context.resourceManager.getRawFd(WHISTLE_PATH);
      if (this.disposed) {
        await context.resourceManager.closeRawFd(WHISTLE_PATH);
        return;
      }
      this.descriptorOpen = true;
      await pool.load(descriptor.fd, descriptor.offset, descriptor.length);
    } catch {
      // Loading a decorative sound must never delay or prevent entering the app.
      await this.release();
    }
  }

  update(cueElapsed: number): void {
    if (this.disposed || this.cueHandled || cueElapsed < 0) {
      return;
    }
    // Do not play a late whistle after a slow decode or a suspended frame loop.
    if (cueElapsed > 180) {
      this.cueHandled = true;
      return;
    }
    const pool: media.SoundPool | undefined = this.pool;
    if (pool === undefined || this.soundId < 0) {
      return;
    }
    this.cueHandled = true;
    try {
      const volumeGroup: audio.AudioVolumeGroupManager =
        audio.getAudioManager().getVolumeManager().getVolumeGroupManagerSync(0);
      if (volumeGroup.getRingerModeSync() !== audio.AudioRingMode.RINGER_MODE_NORMAL) {
        return;
      }
      void pool.play(this.soundId, { loop: 0, leftVolume: 0.45, rightVolume: 0.45 }).catch(() => {});
    } catch {
      // Unsupported audio environments retain the complete visual animation.
    }
  }

  async release(): Promise<void> {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    const context: common.Context | undefined = this.context;
    const pool: media.SoundPool | undefined = this.pool;
    this.pool = undefined;
    this.soundId = -1;
    if (this.listening && context !== undefined) {
      try {
        context.getApplicationContext().off('applicationStateChange', this.appState);
      } catch {}
      this.listening = false;
    }
    if (pool !== undefined) {
      try {
        await pool.release();
      } catch {}
    }
    if (this.descriptorOpen && context !== undefined) {
      this.descriptorOpen = false;
      try {
        await context.resourceManager.closeRawFd(WHISTLE_PATH);
      } catch {}
    }
    this.context = undefined;
  }
}
