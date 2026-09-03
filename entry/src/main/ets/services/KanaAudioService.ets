import { common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';

/**
 * Plays the recorded reading for a single kana.
 *
 * Separate from MusicPlaybackService: these are short one-shot clips with no
 * background task, no AVSession and no position tracking, so reusing that
 * engine would mean carrying state it does not need.
 *
 * Rapid successive taps are handled by cancelling the in-flight play and
 * starting the new one immediately — no "preparing" gate that would drop
 * taps.
 */
export class KanaAudioService {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static player: media.AVPlayer | undefined = undefined;
  private static activePath: string = '';
  private static playToken: number = 0;

  static initialize(context: common.Context): void {
    KanaAudioService.context = context as common.UIAbilityContext;
  }

  /**
   * Plays the clip for `romaji`, e.g. "a", "cha". Does nothing when the clip is
   * missing, so a partial audio set degrades to silence instead of an error.
   */
  static async play(romaji: string): Promise<void> {
    const key: string = romaji.trim().split(' / ').pop() ?? '';
    if (key.length === 0 || KanaAudioService.context === undefined) {
      return;
    }
    const path: string = `audio/kana/${key}.mp3`;
    // Cancel any in-flight play and take over immediately.
    const token: number = KanaAudioService.playToken + 1;
    KanaAudioService.playToken = token;
    try {
      const player: media.AVPlayer = await KanaAudioService.ensurePlayer();
      if (player.state !== 'idle') {
        await player.reset();
        await KanaAudioService.waitForState(player, 'idle', 2000);
      }
      // Another tap may have arrived while we were resetting.
      if (token !== KanaAudioService.playToken) {
        return;
      }
      await KanaAudioService.closeCurrent();
      const descriptor = await KanaAudioService.context.resourceManager.getRawFd(path);
      KanaAudioService.activePath = path;
      player.fdSrc = {
        fd: descriptor.fd,
        offset: descriptor.offset,
        length: descriptor.length
      };
      // fdSrc moves the player to initialized asynchronously. prepare() is
      // illegal until that transition lands.
      const initialized: boolean = await KanaAudioService.waitForState(player, 'initialized', 2000)
        .then(() => true)
        .catch(() => false);
      if (!initialized || token !== KanaAudioService.playToken) {
        return;
      }
      player.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      await player.prepare();
      if (token !== KanaAudioService.playToken) {
        return;
      }
      await player.play();
    } catch (error) {
      // A missing or unreadable clip should never surface as a failure.
    }
  }

  static async release(): Promise<void> {
    KanaAudioService.playToken += 1;
    await KanaAudioService.closeCurrent();
    if (KanaAudioService.player !== undefined) {
      try {
        await KanaAudioService.player.release();
      } catch (error) {
        // Already released by the media service.
      }
      KanaAudioService.player = undefined;
    }
  }

  private static async ensurePlayer(): Promise<media.AVPlayer> {
    if (KanaAudioService.player !== undefined) {
      return KanaAudioService.player;
    }
    const player: media.AVPlayer = await media.createAVPlayer();
    KanaAudioService.player = player;
    return player;
  }

  private static waitForState(player: media.AVPlayer, target: string,
    timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void) => {
      if (player.state === target) {
        resolve();
        return;
      }
      const callback: (state: string) => void = (state: string) => {
        if (state === target) {
          player.off('stateChange', callback);
          resolve();
        }
      };
      player.on('stateChange', callback);
      setTimeout(() => {
        player.off('stateChange', callback);
        reject(new Error(`timeout waiting for ${target}`));
      }, timeoutMs);
    });
  }

  private static async closeCurrent(): Promise<void> {
    if (KanaAudioService.context === undefined || KanaAudioService.activePath.length === 0) {
      return;
    }
    const path: string = KanaAudioService.activePath;
    KanaAudioService.activePath = '';
    try {
      await KanaAudioService.context.resourceManager.closeRawFd(path);
    } catch (error) {
      // Ignore an already closed descriptor.
    }
  }
}
