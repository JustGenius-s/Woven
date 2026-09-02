import { common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';

/**
 * Plays the recorded reading for a single kana.
 *
 * Separate from MusicPlaybackService: these are short one-shot clips with no
 * background task, no AVSession and no position tracking, so reusing that
 * engine would mean carrying state it does not need.
 */
export class KanaAudioService {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static player: media.AVPlayer | undefined = undefined;
  private static activePath: string = '';
  private static preparing: boolean = false;

  static initialize(context: common.Context): void {
    KanaAudioService.context = context as common.UIAbilityContext;
  }

  /**
   * Plays the clip for `romaji`, e.g. "a", "cha". Does nothing when the clip is
   * missing, so a partial audio set degrades to silence instead of an error.
   */
  static async play(romaji: string): Promise<void> {
    const key: string = romaji.trim().split(' / ').pop() ?? '';
    if (key.length === 0 || KanaAudioService.context === undefined || KanaAudioService.preparing) {
      return;
    }
    const path: string = `audio/kana/${key}.mp3`;
    KanaAudioService.preparing = true;
    try {
      const player: media.AVPlayer = await KanaAudioService.ensurePlayer();
      // Re-preparing the same clip keeps the tap responsive when a kana is
      // pressed repeatedly.
      if (player.state !== 'idle') {
        await player.reset();
      }
      await KanaAudioService.closeCurrent();
      const descriptor = await KanaAudioService.context.resourceManager.getRawFd(path);
      KanaAudioService.activePath = path;
      player.fdSrc = {
        fd: descriptor.fd,
        offset: descriptor.offset,
        length: descriptor.length
      };
      player.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      await player.prepare();
      await player.play();
    } catch (error) {
      // A missing or unreadable clip should never surface as a failure.
    } finally {
      // Always cleared, or the next tap would be blocked forever.
      KanaAudioService.preparing = false;
    }
  }

  static async release(): Promise<void> {
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
