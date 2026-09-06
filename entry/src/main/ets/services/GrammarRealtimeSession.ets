import { ApplicationStateChangeCallback, common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { RealtimeEvent, RealtimeLine, RealtimeSnapshot, emptyRealtimeSnapshot, readerVoiceInstructions } from '../model/RealtimeVoiceModels';
import { RealtimeVoicePreferences } from './RealtimeVoicePreferences';
import { ReaderVoiceContextService } from './ReaderVoiceContextService';
import { VolcengineRealtimeClient } from './VolcengineRealtimeClient';
import { RealtimeDuplexAudio } from './RealtimeDuplexAudio';
import { RealtimePlaybackCapacityError } from './RealtimePcmPlaybackBuffer';
import { ReadingNarrationService } from './ReadingNarrationService';
import { MusicPlaybackService } from './MusicPlaybackService';
import { VideoPlaybackService } from './VideoPlaybackService';

interface PageInstructions {
  version: number;
  instructions: string;
}

/** One foreground conversation per PDF, with live page context updates. */
export class GrammarRealtimeSession {
  private context: common.UIAbilityContext;
  private onChange: (snapshot: RealtimeSnapshot) => void;
  private state: RealtimeSnapshot = emptyRealtimeSnapshot();
  private pdf = new ReaderVoiceContextService();
  private client?: VolcengineRealtimeClient;
  private audio?: RealtimeDuplexAudio;
  private base64 = new util.Base64Helper();
  private revision: number = 0;
  private documentPath: string = '';
  private documentTitle: string = '';
  private pageIndex: number = 0;
  private contextVersion: number = 0;
  private sentContextVersion: number = 0;
  private contextUpdating: boolean = false;
  private contextTimer: number = 0;
  private disposed: boolean = false;
  private stopping: Promise<void> = Promise.resolve();
  private muting: boolean = false;
  private responseId: string = '';
  private userId: string = '';
  private cancelledIds: string[] = [];
  private cancelPending: boolean = false;
  private cancelTimer: number = 0;
  private appState: ApplicationStateChangeCallback = {
    onApplicationForeground: () => {},
    onApplicationBackground: () => { void this.stop(false); }
  };

  constructor(context: common.UIAbilityContext, onChange: (snapshot: RealtimeSnapshot) => void) {
    this.context = context;
    this.onChange = onChange;
    context.getApplicationContext().on('applicationStateChange', this.appState);
  }

  private emit(): void {
    if (this.disposed) { return; }
    this.onChange({ status: this.state.status, connecting: this.state.connecting, connected: this.state.connected,
      muted: this.state.muted, responding: this.state.responding, speaking: this.state.speaking,
      lines: this.state.lines.map((line: RealtimeLine): RealtimeLine =>
        ({ id: line.id, speaker: line.speaker, text: line.text })), error: this.state.error });
  }

  async start(path: string, title: string, pageIndex: number): Promise<void> {
    if (this.disposed || this.state.connecting || this.state.connected) { return; }
    const revision: number = ++this.revision;
    this.documentPath = path;
    this.documentTitle = title;
    this.pageIndex = pageIndex;
    this.contextVersion++;
    this.state = emptyRealtimeSnapshot();
    this.state.connecting = true;
    this.state.status = '正在读取这一页…';
    this.emit();
    try {
      await this.stopping;
      if (revision !== this.revision) { return; }
      const credentials = RealtimeVoicePreferences.read(this.context);
      if (!credentials.apiKey.trim()) { throw new Error('请先在设置页填写火山语音 API Key'); }
      const page = await this.readPageInstructions(revision, false);
      if (revision !== this.revision) { return; }
      await ReadingNarrationService.pause();
      if (revision !== this.revision) { return; }
      await MusicPlaybackService.pause();
      if (revision !== this.revision) { return; }
      await VideoPlaybackService.pause();
      if (revision !== this.revision) { return; }
      const audio = new RealtimeDuplexAudio();
      const client = new VolcengineRealtimeClient();
      this.audio = audio; this.client = client;
      this.state.status = '正在准备麦克风…';
      this.emit();
      await audio.open(this.context, (bytes: Uint8Array) => {
        if (revision === this.revision && this.state.connected && !this.state.muted) {
          void client.audio(bytes).catch(() => this.fail('音频发送中断，请重新连接', revision));
        }
      }, (message: string) => this.fail(message, revision), (speaking: boolean) => {
        if (revision !== this.revision) { return; }
        this.state.speaking = speaking;
        this.updateStatus();
      });
      if (revision !== this.revision) { return; }
      this.state.status = '正在连接实时语音…'; this.emit();
      await client.connect(credentials, page.instructions,
        (event: RealtimeEvent) => this.event(event, revision), (message: string) => this.fail(message, revision));
      if (revision !== this.revision) { return; }
      this.state.connected = true;
      this.sentContextVersion = page.version;
      this.state.muted = false;
      await audio.setMuted(false);
      if (revision !== this.revision) { return; }
      // Keep live audio flowing while applying any turns made during extraction,
      // microphone permission or handshake, then finish connecting on the latest page.
      await this.updateContext(revision);
      if (revision !== this.revision) { return; }
      this.state.connecting = false;
      this.updateStatus();
      this.scheduleContextUpdate();
      await client.greet();
    } catch (error) { this.fail((error as Error).message || '无法开始语音对话，请重试', revision); }
  }

  updatePage(path: string, title: string, pageIndex: number): void {
    if (this.disposed || (!this.state.connecting && !this.state.connected)) { return; }
    if (path !== this.documentPath) { void this.stop(); return; }
    if (pageIndex === this.pageIndex && title === this.documentTitle) { return; }
    this.documentTitle = title;
    this.pageIndex = pageIndex;
    this.contextVersion++;
    if (!this.state.connecting) { this.scheduleContextUpdate(); }
  }

  private scheduleContextUpdate(): void {
    clearTimeout(this.contextTimer);
    if (!this.state.connected || this.sentContextVersion === this.contextVersion) { return; }
    const revision: number = this.revision;
    // Coalesce slider scrubbing and quick page turns into the most recent page.
    this.contextTimer = setTimeout(() => { void this.updateContext(revision); }, 200);
  }

  private async readPageInstructions(revision: number, allowEmptyPage: boolean): Promise<PageInstructions> {
    while (revision === this.revision) {
      const version: number = this.contextVersion;
      try {
        const page = await this.pdf.read(this.documentPath, this.documentTitle, this.pageIndex,
          () => revision !== this.revision, allowEmptyPage);
        if (revision !== this.revision) { break; }
        if (version !== this.contextVersion) { continue; }
        return { version: version, instructions: readerVoiceInstructions(page.text) };
      } catch (error) {
        if (revision !== this.revision) { break; }
        if (version !== this.contextVersion) { continue; }
        if (!allowEmptyPage) { throw new Error((error as Error).message || '暂时无法读取教材，请重新打开这一课'); }
        // Reading a page must not terminate a healthy call or silently keep the
        // old page as the current one. Tell the model that this page is unavailable.
        this.state.error = '这一页的文字暂时无法读取，通话继续';
        this.emit();
        return { version: version, instructions: readerVoiceInstructions(
          `当前 PDF 第 ${this.pageIndex + 1} 页。此页内容暂时无法读取，请用户描述，不要把之前的页面当作当前页。`) };
      }
    }
    throw new Error('请求已取消');
  }

  private async updateContext(revision: number): Promise<void> {
    if (revision !== this.revision || !this.state.connected || this.contextUpdating) { return; }
    this.contextUpdating = true;
    try {
      while (revision === this.revision && this.sentContextVersion !== this.contextVersion) {
        const page = await this.readPageInstructions(revision, true);
        if (revision !== this.revision) { return; }
        if (page.version !== this.contextVersion) { continue; }
        await this.client?.updateInstructions(page.instructions);
        if (revision !== this.revision) { return; }
        this.sentContextVersion = page.version;
      }
    } catch (_error) { this.fail('教材页面更新失败，请重新连接', revision); }
    finally { if (revision === this.revision) { this.contextUpdating = false; } }
  }

  private updateStatus(): void {
    if (!this.state.connected) { return; }
    const microphone: string = this.state.muted ? '麦克风已静音' : '可以直接插话';
    this.state.status = this.state.speaking ? `正在讲解 · ${microphone}` :
      (this.state.responding ? `正在生成讲解 · ${microphone}` :
        (this.state.muted ? '麦克风已静音' : '正在聆听 · 直接说话即可'));
    this.emit();
  }

  private setResponding(responding: boolean): void {
    if (this.state.responding === responding) { return; }
    this.state.responding = responding;
    this.updateStatus();
  }

  private line(id: string, speaker: string, text: string, complete: boolean): void {
    if (!text) { return; }
    const existing = this.state.lines.find(line => line.id === id);
    if (existing) { existing.text = (complete ? text : existing.text + text).slice(0, 12000); }
    else { this.state.lines.push({ id: id, speaker: speaker, text: text.slice(0, 12000) }); }
    if (this.state.lines.length > 80) { this.state.lines.shift(); }
    this.emit();
  }

  private event(event: RealtimeEvent, revision: number): void {
    if (revision !== this.revision) { return; }
    try {
      const type: string = event.type;
      if (type === 'response.canceled') {
        this.cancelPending = false; clearTimeout(this.cancelTimer); return;
      }
      if (type === 'conversation.item.input_audio_transcription.started') {
        this.userId = event.item_id || util.generateRandomUUID();
        if (this.state.responding || this.state.speaking) { this.interrupt(); }
      } else if (type === 'conversation.item.input_audio_transcription.delta' ||
        type === 'conversation.item.input_audio_transcription.completed') {
        // started may have an empty item_id; adopt the first actual server ID.
        if (event.item_id && !this.state.lines.some(line => line.id === 'user-' + this.userId)) {
          this.userId = event.item_id;
        }
        if (!this.userId) { this.userId = util.generateRandomUUID(); }
        this.line('user-' + this.userId, '你', event.transcript || event.delta || '', type.endsWith('.completed'));
      } else if (type === 'conversation.item.input_audio_transcription.failed') {
        this.state.error = '这句话没有听清，请再说一次'; this.emit();
      } else if (type.startsWith('response.output_')) {
        if (this.cancelPending || (event.response_id && this.cancelledIds.includes(event.response_id))) { return; }
        if (event.response_id) { this.responseId = event.response_id; }
        if (!this.responseId) { this.responseId = util.generateRandomUUID(); }
        if (type === 'response.output_text.delta' || type === 'response.output_text.done') {
          // A final transcript can arrive after audio.done; it must not restart
          // the generation indicator after the voice response has completed.
          if (type === 'response.output_text.delta') { this.setResponding(true); }
          this.line('assistant-' + this.responseId, '文法老师 · AI', event.text || event.delta || '', type.endsWith('.done'));
        } else if (type === 'response.output_audio.started') {
          this.setResponding(true);
          this.state.error = ''; this.emit();
        } else if (type === 'response.output_audio.delta' && event.delta) {
          this.setResponding(true);
          let bytes: Uint8Array;
          try { bytes = this.base64.decodeSync(event.delta); }
          catch (_error) { this.fail('实时语音音频无法解码，请重新连接', revision); return; }
          this.audio?.enqueue(bytes);
        } else if (type === 'response.output_audio.done') {
          this.audio?.finishOutput();
          this.setResponding(false);
        }
      }
    } catch (error) {
      if (error instanceof RealtimePlaybackCapacityError) {
        // A long response must not tear down the conversation or microphone.
        this.interrupt();
        this.state.error = '本次讲解过长，已停止播放，可以继续提问';
        this.emit();
      } else { this.fail('实时语音内容异常，请重新连接', revision); }
    }
  }

  interrupt(): void {
    if (!this.state.connected || this.cancelPending) { return; }
    this.audio?.clearOutput();
    if (this.responseId) {
      this.cancelledIds.push(this.responseId);
      if (this.cancelledIds.length > 40) { this.cancelledIds.shift(); }
    }
    this.responseId = '';
    this.state.responding = false;
    this.cancelPending = true;
    const revision: number = this.revision;
    this.cancelTimer = setTimeout(() => this.fail('打断请求超时，请重新连接', revision), 5000);
    void this.client?.interrupt().catch(() => this.fail('通话已中断，请重新连接', revision));
    this.updateStatus();
  }

  async toggleMute(): Promise<void> {
    if (!this.state.connected || this.state.connecting || this.muting) { return; }
    this.muting = true;
    const revision: number = this.revision;
    const muted: boolean = !this.state.muted;
    this.state.muted = muted;
    this.updateStatus();
    try {
      if (muted) {
        const stopping = this.audio?.setMuted(true);
        await Promise.all([this.client?.mute(true), stopping]);
      } else {
        await this.client?.mute(false);
        if (revision === this.revision) { await this.audio?.setMuted(false); }
      }
    } catch (_error) { this.fail('麦克风状态切换失败，请重新连接', revision); }
    finally { if (revision === this.revision) { this.muting = false; } }
  }

  private fail(message: string, revision: number): void {
    if (revision !== this.revision || this.disposed) { return; }
    void this.stop(false);
    this.state.error = message;
    this.emit();
  }

  stop(clear: boolean = true): Promise<void> {
    this.revision++;
    clearTimeout(this.contextTimer);
    this.documentPath = '';
    this.contextVersion++;
    this.contextUpdating = false;
    clearTimeout(this.cancelTimer);
    const client = this.client; const audio = this.audio;
    this.client = undefined; this.audio = undefined;
    this.state.responding = false; this.responseId = ''; this.userId = '';
    this.cancelledIds = []; this.cancelPending = false; this.muting = false;
    const previous = this.stopping;
    // Begin microphone shutdown synchronously. Wait for both native cleanup and server close acknowledgement.
    const audioClose = audio?.close(); const clientClose = client?.close();
    this.stopping = Promise.all([previous, audioClose, clientClose]).then(() => {});
    const lines = this.state.lines;
    this.state = emptyRealtimeSnapshot();
    if (!clear) { this.state.lines = lines; this.state.status = '通话已结束'; }
    this.emit();
    return this.stopping;
  }

  async dispose(): Promise<void> {
    this.disposed = true;
    this.context.getApplicationContext().off('applicationStateChange', this.appState);
    await this.stop();
  }
}
