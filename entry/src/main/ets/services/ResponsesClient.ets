import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import {
  ResponsesCreateRequest,
  ResponsesStreamCallbacks,
  ResponsesStreamEvent
} from '../model/AiModels';

const CONNECT_TIMEOUT_MS: number = 12000;
const READ_TIMEOUT_MS: number = 120000;

export class ResponsesClient {
  private gatewayUrl: string;
  private appToken: string;
  private activeRequest?: http.HttpRequest;

  constructor(gatewayUrl: string, appToken: string) {
    this.gatewayUrl = gatewayUrl.replace(/\/+$/, '');
    this.appToken = appToken;
  }

  cancel(): void {
    if (this.activeRequest !== undefined) {
      this.activeRequest.destroy();
      this.activeRequest = undefined;
    }
  }

  stream(requestBody: ResponsesCreateRequest, callbacks: ResponsesStreamCallbacks): Promise<void> {
    if (!this.gatewayUrl.startsWith('http://') && !this.gatewayUrl.startsWith('https://')) {
      callbacks.onError('请先填写有效的 AI 网关地址');
      return Promise.reject(new Error('invalid gateway url'));
    }
    this.cancel();
    const request: http.HttpRequest = http.createHttp();
    this.activeRequest = request;
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    let buffer: string = '';
    let finished: boolean = false;

    return new Promise<void>((resolve: () => void, reject: (error: Error) => void) => {
      const close = (): void => {
        if (this.activeRequest === request) {
          this.activeRequest = undefined;
        }
        request.destroy();
      };
      const fail = (message: string): void => {
        if (finished) {
          return;
        }
        finished = true;
        callbacks.onError(message);
        close();
        reject(new Error(message));
      };

      request.on('dataReceive', (chunk: ArrayBuffer) => {
        buffer += decoder.decodeToString(new Uint8Array(chunk), { stream: true });
        buffer = this.consumeFrames(buffer, callbacks);
      });
      request.on('dataEnd', () => {
        if (finished) {
          return;
        }
        buffer += decoder.decodeToString(new Uint8Array(0), { stream: false });
        this.consumeFrames(`${buffer}\n\n`, callbacks);
        finished = true;
        close();
        resolve();
      });

      const headers: Record<string, string> = {
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json'
      };
      if (this.appToken.length > 0) {
        headers['Authorization'] = `Bearer ${this.appToken}`;
      }
      request.requestInStream(`${this.gatewayUrl}/v1/responses`, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(requestBody),
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS
      }).then((statusCode: number) => {
        if (statusCode < 200 || statusCode >= 300) {
          fail(`AI 网关返回 HTTP ${statusCode}`);
        }
      }).catch((error: Error) => {
        fail(error.message.length > 0 ? error.message : '无法连接 AI 网关');
      });
    });
  }

  private consumeFrames(source: string, callbacks: ResponsesStreamCallbacks): string {
    const normalized: string = source.replace(/\r\n/g, '\n');
    let boundary: number = normalized.indexOf('\n\n');
    let cursor: number = 0;
    while (boundary >= 0) {
      const frame: string = normalized.slice(cursor, boundary);
      this.consumeFrame(frame, callbacks);
      cursor = boundary + 2;
      boundary = normalized.indexOf('\n\n', cursor);
    }
    return normalized.slice(cursor);
  }

  private consumeFrame(frame: string, callbacks: ResponsesStreamCallbacks): void {
    const lines: string[] = frame.split('\n');
    let data: string = '';
    for (let index: number = 0; index < lines.length; index++) {
      if (lines[index].startsWith('data:')) {
        data += lines[index].slice(5).trim();
      }
    }
    if (data.length === 0 || data === '[DONE]') {
      return;
    }
    try {
      const event: ResponsesStreamEvent = JSON.parse(data) as ResponsesStreamEvent;
      if (event.type === 'response.output_text.delta' && event.delta !== undefined) {
        callbacks.onDelta(event.delta);
      } else if (event.type === 'response.completed') {
        callbacks.onCompleted(event.response?.id ?? '');
      } else if (event.type === 'response.failed' || event.type === 'error') {
        callbacks.onError(event.error?.message ?? 'AI 生成失败');
      }
    } catch (error) {
      callbacks.onError('AI 返回了无法解析的 Responses 事件');
    }
  }
}

