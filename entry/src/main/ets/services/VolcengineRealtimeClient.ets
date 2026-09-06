import { webSocket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { RealtimeCredentials, RealtimeEvent, RealtimeSessionCreate } from '../model/RealtimeVoiceModels';

/** Seeduplex 3.0 JSON protocol, official API revision 2026-09-04. One instance per call. */
export class VolcengineRealtimeClient {
  private socket?: webSocket.WebSocket;
  private opened: boolean = false;
  private ready: boolean = false;
  private closing: boolean = false;
  private closed: boolean = false;
  private pendingSends: number = 0;
  private handshakeTimer: number = 0;
  private rejectStart?: (error: Error) => void;
  private finishClose?: () => void;
  private closingTask?: Promise<void>;
  private onFailure: (message: string) => void = () => {};
  private base64 = new util.Base64Helper();

  connect(credentials: RealtimeCredentials, instructions: string,
    onEvent: (event: RealtimeEvent) => void, onFailure: (message: string) => void): Promise<void> {
    if (!credentials.apiKey.trim()) { return Promise.reject(new Error('请先在设置页填写火山语音 API Key')); }
    if (this.socket !== undefined || this.closed) { return Promise.reject(new Error('请重新开始语音通话')); }
    this.onFailure = onFailure;
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void) => {
      this.rejectStart = reject;
      const socket = webSocket.createWebSocket();
      this.socket = socket;
      this.handshakeTimer = setTimeout(() => this.fail('语音连接超时，请检查网络后重试'), 20000);
      socket.on('open', () => {
        if (this.closing || this.closed) { void socket.close().catch(() => {}); return; }
        this.opened = true;
        const request: RealtimeSessionCreate = {
          type: 'session.create', event_id: util.generateRandomUUID(),
          session: { model: '1.2.6.1', instructions: instructions,
            audio: {
              input: { format: { type: 'pcm', rate: 16000 } },
              // The official duplex demo plays output "pcm" as Float32.
              // Select PCM16 here to match our S16LE AudioRenderer.
              output: { format: { type: 'pcm_s16le', rate: 24000 }, voice: 'zh_female_vv_jupiter_bigtts' }
            }
          }
        };
        void this.send(JSON.stringify(request)).catch(() => {});
      });
      socket.on('message', (error: BusinessError, data: string | ArrayBuffer) => {
        if (this.closed) { return; }
        try {
          if (error || typeof data !== 'string' || data.length > 2 * 1024 * 1024) {
            throw new Error('invalid frame');
          }
          const event = JSON.parse(data) as RealtimeEvent;
          if (typeof event.type !== 'string') { throw new Error('missing event type'); }
          if (event.type === 'session.closed') {
            if (this.closing) { this.finishClose?.(); }
            else { this.fail('语音通话已结束，可以重新连接'); }
            return;
          }
          if (this.closing) { return; }
          if (event.type === 'error') { this.fail(VolcengineRealtimeClient.errorMessage(event)); return; }
          if (event.type === 'session.created' && !this.ready) {
            this.ready = true;
            clearTimeout(this.handshakeTimer);
            this.rejectStart = undefined;
            resolve();
          } else if (this.ready) { onEvent(event); }
        } catch (_error) { this.fail('实时语音数据无法解析，请重新连接'); }
      });
      socket.on('error', () => this.fail('无法连接实时语音，请检查网络、API Key 或账号权限'));
      socket.on('close', () => {
        if (this.closing) { this.finishClose?.(); }
        else { this.fail('语音连接已断开，请重新连接'); }
      });
      void socket.connect('wss://openspeech.bytedance.com/api/v3/duplex/realtime/dialogue', {
        header: { 'X-Api-Key': credentials.apiKey.trim() }
      }).then((connected: boolean) => {
        if (!connected) { this.fail('无法连接实时语音，请检查网络、API Key 或账号权限'); }
      }).catch(() => this.fail('无法连接实时语音，请检查网络、API Key 或账号权限'));
    });
  }

  private async send(json: string): Promise<void> {
    const socket = this.socket;
    if (!socket || this.closed || this.closing) { throw new Error('通话已结束'); }
    // Do not let a slow network accumulate delayed microphone speech.
    if (this.pendingSends >= 10) { this.fail('网络传输过慢，通话已停止，请重新连接'); throw new Error('网络传输过慢'); }
    this.pendingSends++;
    try {
      if (!await socket.send(json)) { throw new Error('send failed'); }
    } catch (_error) {
      this.fail('语音连接中断，请重新连接');
      throw new Error('语音连接中断');
    } finally { this.pendingSends--; }
  }

  async audio(pcm: Uint8Array): Promise<void> {
    if (!this.ready || this.closing || this.closed) { return; }
    if (pcm.length !== 640) { throw new Error('音频分片长度异常'); }
    await this.send(JSON.stringify({ type: 'input_audio_buffer.append',
      event_id: util.generateRandomUUID(), audio: this.base64.encodeToStringSync(pcm) }));
  }

  async mute(muted: boolean): Promise<void> {
    await this.send(JSON.stringify({ type: muted ? 'input_audio_mute.commit' : 'input_audio_unmute.commit',
      event_id: util.generateRandomUUID() }));
  }

  async interrupt(): Promise<void> {
    await this.send(JSON.stringify({ type: 'response.cancel', event_id: util.generateRandomUUID() }));
  }

  async greet(): Promise<void> {
    await this.send(JSON.stringify({ type: 'speech_text_buffer.commit', event_id: util.generateRandomUUID(),
      text: '我在看这一页。你可以让我讲解，也可以直接问我。' }));
  }

  private fail(message: string): void {
    if (this.closing || this.closed) { return; }
    const reject = this.rejectStart;
    this.rejectStart = undefined;
    reject?.(new Error(message));
    this.onFailure(message);
    void this.close();
  }

  close(): Promise<void> {
    if (this.closingTask !== undefined) { return this.closingTask; }
    this.closing = true;
    this.ready = false;
    clearTimeout(this.handshakeTimer);
    this.rejectStart?.(new Error('通话已取消'));
    this.rejectStart = undefined;
    const socket = this.socket;
    this.closingTask = new Promise<void>((resolve: () => void) => {
      let done: boolean = false;
      let timer: number = 0;
      const finish = (): void => {
        if (done) { return; }
        done = true;
        clearTimeout(timer);
        this.closed = true;
        this.finishClose = undefined;
        if (socket) { void socket.close().catch(() => {}); }
        resolve();
      };
      this.finishClose = finish;
      if (!socket || !this.opened) { finish(); return; }
      timer = setTimeout(finish, 1500);
      void socket.send(JSON.stringify({ type: 'session.close', event_id: util.generateRandomUUID() }))
        .then((sent: boolean) => { if (!sent) { finish(); } }).catch(finish);
    });
    return this.closingTask;
  }

  private static errorMessage(event: RealtimeEvent): string {
    const code: string = String(event.error?.code ?? event.status_code ?? '');
    if (code === '45000003') { return '长时间没有交互，通话已结束'; }
    // Provider messages may contain request data; show only an allowlisted numeric code.
    return '实时语音服务返回错误' + (/^\d{3,8}$/.test(code) ? `（${code}）` : '') +
      '，请检查 API Key、模型权限或额度后重试';
  }
}
