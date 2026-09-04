import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { MusicPlaybackService } from './MusicPlaybackService';
import { VideoPlaybackService } from './VideoPlaybackService';
import { LearningPreferences } from './LearningPreferences';

interface VoiceSetting {
  voice_id: string;
  speed: number;
  vol: number;
  pitch: number;
}

interface AudioSetting {
  sample_rate: number;
  bitrate: number;
  format: string;
  channel: number;
}

interface MiniMaxTtsRequest {
  model: string;
  text: string;
  stream: boolean;
  voice_setting: VoiceSetting;
  audio_setting: AudioSetting;
  language_boost: string;
  output_format: string;
}

class MiniMaxTtsData {
  audio?: string;
}

class MiniMaxTtsBaseResp {
  status_code?: number;
  status_msg?: string;
}

class MiniMaxTtsResponse {
  data?: MiniMaxTtsData;
  base_resp?: MiniMaxTtsBaseResp;
}

const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'KotobaTts';

// MiniMax T2A v2 API
const MINIMAX_API_URL: string = 'https://api-bj.minimaxi.com/v1/t2a_v2';

// Japanese voice from MiniMax system voice list
// 'Japanese_Whisper_Belle' is a whisper voice (too quiet).
// Use a normal Japanese voice instead.
const JAPANESE_VOICE_ID: string = 'moss_audio_24875c4a-7be4-11f0-9359-4e72c55db738';

/**
 * Japanese TTS backed by MiniMax T2A (cloud API).
 *
 * MiniMax supports Japanese natively via language_boost: 'Japanese' and
 * dedicated Japanese voice IDs. Audio is returned as hex-encoded MP3.
 *
 * This replaces the previous on-device approaches (Piper, Kokoro) which
 * either lacked Japanese phoneme support in HarmonyOS's espeak-ng build
 * or required native library updates not yet published to ohpm.
 */
export class JapaneseTtsService {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static player: media.AVPlayer | undefined = undefined;
  private static cacheDir: string = '';
  private static activeFile: fs.File | undefined = undefined;
  private static playToken: number = 0;

  static initialize(context: common.Context): void {
    JapaneseTtsService.context = context as common.UIAbilityContext;
    if (JapaneseTtsService.context !== undefined) {
      JapaneseTtsService.cacheDir = `${JapaneseTtsService.context.filesDir}/tts-cache`;
      JapaneseTtsService.ensureDir(JapaneseTtsService.cacheDir);
    }
  }

  static playEntry(word: string, reading: string): void {
    const spoken: string = word.trim().length > 0 ? word.trim() : reading.trim();
    void JapaneseTtsService.play(spoken);
  }

  static async play(text: string): Promise<void> {
    const spoken: string = text.trim();
    if (spoken.length === 0 || JapaneseTtsService.context === undefined) {
      return;
    }
    const apiKey: string = LearningPreferences.minimaxApiKey(JapaneseTtsService.context);
    if (apiKey.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'play skipped: no minimax api key');
      return;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'play request: %{public}s', spoken);
    try {
      await MusicPlaybackService.pause();
      await VideoPlaybackService.pause();
    } catch (error) {
      // Music may not have a prepared source.
    }
    const cached: string = JapaneseTtsService.cachedPath(spoken);
    if (cached.length > 0 && fs.accessSync(cached)) {
      await JapaneseTtsService.playFile(cached);
      return;
    }
    const token: number = JapaneseTtsService.playToken + 1;
    JapaneseTtsService.playToken = token;
    try {
      const path: string = await JapaneseTtsService.synthesize(spoken);
      if (path.length === 0 || token !== JapaneseTtsService.playToken) {
        return;
      }
      await JapaneseTtsService.playFile(path);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'synthesize failed: %{public}s', `${error}`);
    }
  }

  static async release(): Promise<void> {
    JapaneseTtsService.playToken += 1;
    await JapaneseTtsService.closeActiveFile();
    if (JapaneseTtsService.player !== undefined) {
      try {
        await JapaneseTtsService.player.release();
      } catch (error) {
        // Already released by the media service.
      }
      JapaneseTtsService.player = undefined;
    }
  }

  /**
   * Calls MiniMax T2A v2 and writes the hex-encoded MP3 to cache.
   */
  private static async synthesize(text: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const body: MiniMaxTtsRequest = {
        model: 'speech-2.8-turbo',
        text: text,
        stream: false,
        voice_setting: {
          voice_id: JAPANESE_VOICE_ID,
          speed: 1.0,
          vol: 1.0,
          pitch: 0
        },
        audio_setting: {
          sample_rate: 32000,
          bitrate: 128000,
          format: 'mp3',
          channel: 1
        },
        language_boost: 'Japanese',
        output_format: 'hex'
      };
      hilog.info(LOG_DOMAIN, LOG_TAG, 'minimax request: %{public}s', text);
      const apiKey: string = LearningPreferences.minimaxApiKey(JapaneseTtsService.context!);
      const response = await httpRequest.request(MINIMAX_API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
        },
        extraData: JSON.stringify(body),
        connectTimeout: 30000,
        readTimeout: 60000
      });
      if (response.responseCode !== 200) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'minimax http %{public}d: %{public}s',
          response.responseCode, `${response.result}`);
        JapaneseTtsService.showToast('语音服务网络错误');
        return '';
      }
      const result: MiniMaxTtsResponse = JSON.parse(`${response.result}`) as MiniMaxTtsResponse;
      const statusCode: number = result?.base_resp?.status_code ?? -1;
      if (statusCode !== 0) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'minimax api error %{public}d: %{public}s',
          statusCode, result?.base_resp?.status_msg);
        const message: string = JapaneseTtsService.mapMinimaxError(statusCode,
          result?.base_resp?.status_msg ?? '');
        JapaneseTtsService.showToast(message);
        return '';
      }
      const hexAudio: string = result?.data?.audio ?? '';
      if (hexAudio.length === 0) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'minimax empty audio');
        JapaneseTtsService.showToast('语音合成返回空数据');
        return '';
      }
      // Decode hex to bytes
      const bytes: Uint8Array = JapaneseTtsService.hexToBytes(hexAudio);
      const path: string = JapaneseTtsService.cachedPath(text);
      JapaneseTtsService.writeBytes(path, bytes);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'minimax cached: %{public}s (%{public}d bytes)',
        path, bytes.length);
      return path;
    } finally {
      httpRequest.destroy();
    }
  }

  private static hexToBytes(hex: string): Uint8Array {
    const length: number = hex.length / 2;
    const bytes: Uint8Array = new Uint8Array(length);
    for (let index: number = 0; index < length; index++) {
      bytes[index] = parseInt(hex.substring(index * 2, index * 2 + 2), 16);
    }
    return bytes;
  }

  /**
   * Maps MiniMax error codes to user-friendly messages.
   * See https://platform.minimaxi.com/docs/api-reference/errorcode
   */
  private static mapMinimaxError(code: number, fallback: string): string {
    switch (code) {
      case 1004:
        return 'API Key 无效，请检查设置';
      case 1008:
        return 'MiniMax 余额不足，请充值';
      case 1002:
      case 1039:
        return '请求太频繁，请稍后再试';
      case 2013:
        return '输入文本格式不正确';
      case 1042:
        return '文本包含过多非法字符';
      default:
        return fallback.length > 0 ? `语音合成失败：${fallback}` : '语音合成失败，请稍后再试';
    }
  }

  private static showToast(message: string): void {
    try {
      const context: common.UIAbilityContext | undefined = JapaneseTtsService.context;
      if (context === undefined) {
        return;
      }
      // Use the global promptAction for service-level toasts. This works
      // because the service is always triggered from a UI context.
      promptAction.showToast({
        message: message,
        duration: 3000
      });
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'toast failed: %{public}s', `${error}`);
    }
  }

  private static writeBytes(path: string, bytes: Uint8Array): void {
    const parent: number = path.lastIndexOf('/');
    if (parent > 0) {
      JapaneseTtsService.ensureDir(path.substring(0, parent));
    }
    const file = fs.openSync(path,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, bytes.buffer);
    fs.closeSync(file);
  }

  private static cachedPath(text: string): string {
    if (JapaneseTtsService.context === undefined) {
      return '';
    }
    let hash: number = 2166136261;
    for (let index: number = 0; index < text.length; index++) {
      hash = hash ^ text.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    const key: string = (hash >>> 0).toString(16);
    return `${JapaneseTtsService.cacheDir}/${key}.mp3`;
  }

  private static async playFile(path: string): Promise<void> {
    if (JapaneseTtsService.context === undefined) {
      return;
    }
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'playFile: %{public}s', path);
      const player: media.AVPlayer = await JapaneseTtsService.ensurePlayer();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'player state: %{public}s', player.state);
      if (player.state !== 'idle') {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'resetting player...');
        await player.reset();
        await JapaneseTtsService.waitForState(player, 'idle', 2000);
        hilog.info(LOG_DOMAIN, LOG_TAG, 'player reset to idle');
      }
      await JapaneseTtsService.closeActiveFile();
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      JapaneseTtsService.activeFile = file;
      const stat = fs.statSync(path);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'setting fdSrc, fd=%{public}d, size=%{public}d', file.fd, stat.size);
      player.fdSrc = {
        fd: file.fd,
        offset: 0,
        length: stat.size
      };
      const initialized: boolean = await JapaneseTtsService.waitForState(player, 'initialized', 2000)
        .then(() => true)
        .catch(() => false);
      if (!initialized) {
        throw new Error('source not initialized');
      }
      player.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      hilog.info(LOG_DOMAIN, LOG_TAG, 'preparing...');
      await player.prepare();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'playing...');
      await player.play();
      hilog.info(LOG_DOMAIN, LOG_TAG, 'play started');
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'play failed: %{public}s', JSON.stringify(error));
    }
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

  private static async ensurePlayer(): Promise<media.AVPlayer> {
    if (JapaneseTtsService.player !== undefined) {
      return JapaneseTtsService.player;
    }
    const player: media.AVPlayer = await media.createAVPlayer();
    JapaneseTtsService.player = player;
    return player;
  }

  private static async closeActiveFile(): Promise<void> {
    if (JapaneseTtsService.activeFile === undefined) {
      return;
    }
    const file: fs.File = JapaneseTtsService.activeFile;
    JapaneseTtsService.activeFile = undefined;
    try {
      fs.closeSync(file);
    } catch (error) {
      // Already closed.
    }
  }

  private static ensureDir(path: string): void {
    if (!fs.accessSync(path)) {
      fs.mkdirSync(path, true);
    }
  }
}
