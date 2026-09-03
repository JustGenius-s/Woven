import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OfflineTts, OfflineTtsConfig, TtsInput, TtsOutput } from 'sherpa_onnx';
import { MusicPlaybackService } from './MusicPlaybackService';

const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'KotobaTts';
const MODEL_DIR: string = 'tts/vits-piper-ja';
const MODEL_NAME: string = 'model.onnx';
const TOKENS_NAME: string = 'tokens.txt';
const ESPEAK_DIR: string = 'espeak-ng-data';
const ESPEAK_FILES: string[] = [
  'phontab',
  'phonindex',
  'phondata',
  'phondata-manifest',
  'intonations',
  'ja_dict',
  'lang/jpx/ja'
];

/**
 * On-device Japanese TTS via sherpa-onnx + Piper.
 *
 * Synthesis stays on the host thread and uses the synchronous generate().
 * generateAsync is avoided: it queues a NAPI AsyncWorker / EAWorker and
 * aborts on HarmonyOS when the process is already at the EAWorker limit.
 * ThreadWorker is also avoided (merged modules.abc has no worker abc).
 * Missing models or a failed init degrade to silence.
 */
export class JapaneseTtsService {
  private static context: common.UIAbilityContext | undefined = undefined;
  private static tts: OfflineTts | undefined = undefined;
  private static player: media.AVPlayer | undefined = undefined;
  private static unavailable: boolean = false;
  private static starting: boolean = false;
  private static cacheDir: string = '';
  private static activeFile: fs.File | undefined = undefined;
  private static playToken: number = 0;

  static initialize(context: common.Context): void {
    JapaneseTtsService.context = context as common.UIAbilityContext;
  }

  /**
   * Speaks a vocabulary item. Prefer the kana reading so the frontend does
   * not have to guess 漢字 readings.
   */
  static playEntry(word: string, reading: string): void {
    const spoken: string = reading.trim().length > 0 ? reading.trim() : word.trim();
    void JapaneseTtsService.play(spoken);
  }

  static async play(text: string): Promise<void> {
    const spoken: string = text.trim();
    if (spoken.length === 0 || JapaneseTtsService.context === undefined ||
      JapaneseTtsService.unavailable) {
      return;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'play request: %{public}s', spoken);
    try {
      await MusicPlaybackService.pause();
    } catch (error) {
      // Music may not have a prepared source.
    }
    const cached: string = JapaneseTtsService.cachedPath(spoken);
    if (cached.length > 0 && fs.accessSync(cached)) {
      await JapaneseTtsService.playFile(cached);
      return;
    }
    await new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, 0);
    });
    if (!JapaneseTtsService.ensureTts()) {
      return;
    }
    const token: number = JapaneseTtsService.playToken + 1;
    JapaneseTtsService.playToken = token;
    try {
      const path: string = JapaneseTtsService.generate(spoken);
      if (path.length === 0 || token !== JapaneseTtsService.playToken) {
        return;
      }
      await JapaneseTtsService.playFile(path);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'generate failed: %{public}s', `${error}`);
    }
  }

  static async release(): Promise<void> {
    JapaneseTtsService.playToken += 1;
    JapaneseTtsService.tts = undefined;
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

  private static ensureTts(): boolean {
    if (JapaneseTtsService.tts !== undefined) {
      return true;
    }
    if (JapaneseTtsService.unavailable || JapaneseTtsService.context === undefined ||
      JapaneseTtsService.starting) {
      return JapaneseTtsService.tts !== undefined;
    }
    JapaneseTtsService.starting = true;
    try {
      const context: common.UIAbilityContext = JapaneseTtsService.context;
      const modelPath: string = `${MODEL_DIR}/${MODEL_NAME}`;
      const tokensPath: string = `${MODEL_DIR}/${TOKENS_NAME}`;
      if (!JapaneseTtsService.rawFileExists(context, modelPath) ||
        !JapaneseTtsService.rawFileExists(context, tokensPath)) {
        JapaneseTtsService.markUnavailable('model-missing');
        return false;
      }
      const sandbox: string = context.filesDir;
      const espeakDest: string = `${sandbox}/${MODEL_DIR}/${ESPEAK_DIR}`;
      JapaneseTtsService.copyEspeakFiles(context, espeakDest);
      JapaneseTtsService.cacheDir = `${sandbox}/tts-cache`;
      JapaneseTtsService.ensureDir(JapaneseTtsService.cacheDir);

      const config: OfflineTtsConfig = new OfflineTtsConfig();
      config.model.vits.model = modelPath;
      config.model.vits.tokens = tokensPath;
      config.model.vits.dataDir = espeakDest;
      config.model.vits.noiseScale = 0.667;
      config.model.vits.lengthScale = 1.15;
      config.model.numThreads = 1;
      config.model.debug = false;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'creating OfflineTts');
      JapaneseTtsService.tts = new OfflineTts(config, context.resourceManager);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'OfflineTts ready, rate=%{public}d',
        JapaneseTtsService.tts.sampleRate);
      return true;
    } catch (error) {
      JapaneseTtsService.markUnavailable(`${error}`);
      return false;
    } finally {
      JapaneseTtsService.starting = false;
    }
  }

  private static generate(text: string): string {
    if (JapaneseTtsService.tts === undefined) {
      return '';
    }
    const input: TtsInput = new TtsInput();
    input.text = text;
    input.sid = 0;
    input.speed = 0.9;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'generate start');
    const output: TtsOutput = JapaneseTtsService.tts.generate(input);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'generate done, samples=%{public}d',
      output.samples.length);
    if (output.samples.length === 0) {
      return '';
    }
    const path: string = JapaneseTtsService.cachedPath(text);
    JapaneseTtsService.writeWav(path, output.samples, output.sampleRate);
    return path;
  }

  private static copyEspeakFiles(context: common.UIAbilityContext, destDir: string): void {
    const srcDir: string = `${MODEL_DIR}/${ESPEAK_DIR}`;
    for (let index: number = 0; index < ESPEAK_FILES.length; index++) {
      const relative: string = ESPEAK_FILES[index];
      const src: string = `${srcDir}/${relative}`;
      const dest: string = `${destDir}/${relative}`;
      const parent: number = dest.lastIndexOf('/');
      if (parent > 0) {
        JapaneseTtsService.ensureDir(dest.substring(0, parent));
      }
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(src);
      if (fs.accessSync(dest)) {
        const stat = fs.statSync(dest);
        if (stat.size === bytes.length) {
          continue;
        }
      }
      const file = fs.openSync(dest,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes.buffer);
      fs.closeSync(file);
    }
  }

  private static rawFileExists(context: common.UIAbilityContext, path: string): boolean {
    try {
      context.resourceManager.getRawFileContentSync(path);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static ensureDir(path: string): void {
    if (!fs.accessSync(path)) {
      fs.mkdirSync(path, true);
    }
  }

  private static writeWav(path: string, samples: Float32Array, sampleRate: number): void {
    const count: number = samples.length;
    const dataSize: number = count * 2;
    const bytes: ArrayBuffer = new ArrayBuffer(44 + dataSize);
    const view: DataView = new DataView(bytes);
    const ascii: (offset: number, value: string) => void = (offset: number, value: string) => {
      for (let index: number = 0; index < value.length; index++) {
        view.setUint8(offset + index, value.charCodeAt(index));
      }
    };
    ascii(0, 'RIFF');
    view.setUint32(4, 36 + dataSize, true);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, 1, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    ascii(36, 'data');
    view.setUint32(40, dataSize, true);
    let offset: number = 44;
    for (let index: number = 0; index < count; index++) {
      const clipped: number = Math.max(-1, Math.min(1, samples[index]));
      view.setInt16(offset, clipped < 0 ? clipped * 0x8000 : clipped * 0x7fff, true);
      offset += 2;
    }
    const file = fs.openSync(path,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, bytes);
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
    const dir: string = JapaneseTtsService.cacheDir.length > 0 ?
      JapaneseTtsService.cacheDir :
      `${JapaneseTtsService.context.filesDir}/tts-cache`;
    return `${dir}/${key}.wav`;
  }

  private static async playFile(path: string): Promise<void> {
    if (JapaneseTtsService.context === undefined) {
      return;
    }
    try {
      const player: media.AVPlayer = await JapaneseTtsService.ensurePlayer();
      if (player.state !== 'idle') {
        await player.reset();
      }
      await JapaneseTtsService.closeActiveFile();
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      JapaneseTtsService.activeFile = file;
      player.fdSrc = {
        fd: file.fd,
        offset: 0,
        length: fs.statSync(path).size
      };
      player.audioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      await player.prepare();
      await player.play();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'play failed: %{public}s', JSON.stringify(error));
    }
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

  private static markUnavailable(reason: string): void {
    JapaneseTtsService.unavailable = true;
    JapaneseTtsService.tts = undefined;
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'TTS unavailable: %{public}s', reason);
  }
}
