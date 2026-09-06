import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { RealtimePcmQueue } from './RealtimePcmQueue';
import { RealtimePcmPlaybackBuffer } from './RealtimePcmPlaybackBuffer';

/** Native voice communication input/output together enable the platform's AEC/3A. */
export class RealtimeDuplexAudio {
  private capturer?: audio.AudioCapturer;
  private renderer?: audio.AudioRenderer;
  private input = new RealtimePcmQueue(16000);
  private output = new RealtimePcmPlaybackBuffer();
  private outputPrefix = new Uint8Array(4);
  private outputPrefixLength: number = 0;
  private outputFormatChecked: boolean = false;
  private closed: boolean = false;
  private muted: boolean = true;
  private timer: number = 0;
  private nextFrame: number = 0;
  private lastCapture: number = 0;
  private lastRendered: number = 0;
  private speaking: boolean = false;
  private flushing: boolean = false;
  private setup?: Promise<void>;
  private captureTask: Promise<void> = Promise.resolve();
  private closeTask?: Promise<void>;
  private onFrame: (bytes: Uint8Array) => void = () => {};
  private onFailure: (message: string) => void = () => {};
  private onSpeaking: (speaking: boolean) => void = () => {};

  open(context: common.UIAbilityContext, onFrame: (bytes: Uint8Array) => void,
    onFailure: (message: string) => void, onSpeaking: (speaking: boolean) => void): Promise<void> {
    this.onFrame = onFrame;
    this.onFailure = onFailure;
    this.onSpeaking = onSpeaking;
    this.setup = this.prepare(context);
    return this.setup;
  }

  private async prepare(context: common.UIAbilityContext): Promise<void> {
    const permission = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
    if (this.closed) { throw new Error('通话已取消'); }
    if (permission.authResults[0] !== 0) { throw new Error('请在系统设置中允许麦克风后开始语音对话'); }
    this.renderer = await audio.createAudioRenderer({
      streamInfo: { samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_24000,
        channels: audio.AudioChannel.CHANNEL_1, sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW },
      rendererInfo: { usage: audio.StreamUsage.STREAM_USAGE_VOICE_COMMUNICATION, rendererFlags: 0 }
    });
    if (this.closed) { return; }
    this.renderer.on('writeData', (data: ArrayBuffer) => {
      const target = new Uint8Array(data);
      target.fill(0);
      if (this.closed || this.flushing) { return; }
      if (this.output.read(target) > 0) { this.lastRendered = Date.now() + data.byteLength / 48; }
    });
    this.renderer.on('audioInterrupt', (event: audio.InterruptEvent) => {
      if (!this.closed && (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP)) {
        this.onFailure('通话被其他音频中断，请重新连接');
      }
    });
    await this.renderer.start();
    if (this.closed) { return; }
    this.capturer = await audio.createAudioCapturer({
      streamInfo: { samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1, sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW },
      capturerInfo: { source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION, capturerFlags: 0 }
    });
    if (this.closed) { return; }
    this.capturer.on('readData', (data: ArrayBuffer) => {
      if (this.closed || this.muted) { return; }
      this.lastCapture = Date.now();
      try { this.input.append(new Uint8Array(data)); }
      catch (_error) { this.onFailure('麦克风音频积压，请重新连接'); }
    });
    this.capturer.on('audioInterrupt', (event: audio.InterruptEvent) => {
      if (!this.closed && event.hintType !== audio.InterruptHint.INTERRUPT_HINT_RESUME &&
        event.hintType !== audio.InterruptHint.INTERRUPT_HINT_NONE) {
        this.onFailure('麦克风已被系统中断，请重新连接');
      }
    });
    this.nextFrame = Date.now() + 20;
    this.timer = setTimeout(() => this.tick(), 20);
  }

  private tick(): void {
    if (this.closed) { return; }
    const now: number = Date.now();
    if (!this.muted) {
      if (now - this.nextFrame > 250 || now - this.lastCapture > 2000) {
        this.onFailure('实时音频采集已中断，请重新连接');
        return;
      }
      const frame = new Uint8Array(640);
      if (this.input.length >= 640) { this.input.read(frame); }
      this.onFrame(frame);
    }
    const speaking: boolean = this.output.length > 0 || now < this.lastRendered;
    if (speaking !== this.speaking) { this.speaking = speaking; this.onSpeaking(speaking); }
    // One 20 ms packet per tick. Never burst-send accumulated frames after a stall.
    this.nextFrame = Math.max(this.nextFrame + 20, now + 15);
    this.timer = setTimeout(() => this.tick(), Math.max(15, this.nextFrame - Date.now()));
  }

  setMuted(muted: boolean): Promise<void> {
    // Gate audio immediately, before native asynchronous stop completes.
    this.muted = true;
    this.input.clear();
    this.captureTask = this.captureTask.catch(() => {}).then(async () => {
      const capturer = this.capturer;
      if (!capturer || this.closed) { return; }
      if (muted) {
        if (capturer.state === audio.AudioState.STATE_RUNNING) { await capturer.stop(); }
      } else {
        await capturer.start();
        if (this.closed) { return; }
        this.lastCapture = Date.now();
        this.nextFrame = this.lastCapture + 20;
        this.muted = false;
      }
    });
    return this.captureTask;
  }

  enqueue(bytes: Uint8Array): void {
    if (this.closed) { return; }
    if (bytes.length % 2 !== 0) { throw new Error('实时语音 PCM 数据不完整'); }
    if (this.outputFormatChecked) { this.output.append(bytes); return; }
    // Check the stream header before any bytes reach the speaker, even when
    // that header spans chunks. Ogg/Opus and WAV containers are not raw PCM.
    const count: number = Math.min(4 - this.outputPrefixLength, bytes.length);
    this.outputPrefix.set(bytes.subarray(0, count), this.outputPrefixLength);
    this.outputPrefixLength += count;
    if (this.outputPrefixLength < 4) { return; }
    const header: string = String.fromCharCode(this.outputPrefix[0], this.outputPrefix[1],
      this.outputPrefix[2], this.outputPrefix[3]);
    if (header === 'OggS' || header === 'RIFF') {
      this.onFailure('服务端音频格式与播放器不一致，已停止播放，请重新连接');
      return;
    }
    this.outputFormatChecked = true;
    this.output.append(this.outputPrefix);
    this.output.append(bytes.subarray(count));
    this.outputPrefixLength = 0;
  }

  finishOutput(): void {
    // A response shorter than the four-byte format probe can still contain
    // one valid PCM sample. Release it only at the explicit audio boundary.
    if (!this.closed && this.outputPrefixLength > 0 && this.outputPrefixLength < 4) {
      this.output.append(this.outputPrefix.slice(0, this.outputPrefixLength));
      this.outputPrefixLength = 0;
    }
    this.output.finish();
    this.outputFormatChecked = false;
  }

  clearOutput(): void {
    this.output.clear();
    this.outputPrefixLength = 0;
    this.outputFormatChecked = false;
    this.lastRendered = 0;
    if (this.speaking) { this.speaking = false; this.onSpeaking(false); }
    const renderer = this.renderer;
    if (renderer && !this.closed && !this.flushing) {
      this.flushing = true;
      void renderer.flush().catch(() => {}).then(() => { this.flushing = false; });
    }
  }

  close(): Promise<void> {
    if (this.closeTask !== undefined) { return this.closeTask; }
    this.closed = true;
    this.muted = true;
    clearTimeout(this.timer);
    this.input.clear(); this.output.clear();
    this.outputPrefixLength = 0;
    this.closeTask = this.release();
    return this.closeTask;
  }

  private async release(): Promise<void> {
    await this.setup?.catch(() => {});
    await this.captureTask.catch(() => {});
    const capturer = this.capturer;
    const renderer = this.renderer;
    this.capturer = undefined; this.renderer = undefined;
    if (capturer) {
      try { capturer.off('readData'); capturer.off('audioInterrupt'); } catch (_error) {}
      await capturer.stop().catch(() => {});
      await capturer.release().catch(() => {});
    }
    if (renderer) {
      try { renderer.off('writeData'); renderer.off('audioInterrupt'); } catch (_error) {}
      await renderer.stop().catch(() => {});
      await renderer.release().catch(() => {});
    }
  }
}
