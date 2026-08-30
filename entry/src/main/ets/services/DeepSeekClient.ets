import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DeepSeekChatResponse,
  DeepSeekChatRequest,
  DeepSeekMessage
} from '../model/DeepSeekModels';

const DEEPSEEK_URL: string = 'https://api.deepseek.com/chat/completions';
const CONNECT_TIMEOUT_MS: number = 12000;
const REQUEST_TIMEOUT_MS: number = 45000;
const CANCELLED_MESSAGE: string = '请求已取消';
const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'WovenAI';

export class DeepSeekClient {
  private static requestSequence: number = 0;
  private apiKey: string;
  private cancelActive?: () => void;

  constructor(apiKey: string) {
    this.apiKey = apiKey.trim();
  }

  cancel(): void {
    if (this.cancelActive !== undefined) {
      const cancel: () => void = this.cancelActive;
      this.cancelActive = undefined;
      cancel();
    }
  }

  complete(messages: DeepSeekMessage[]): Promise<string> {
    if (this.apiKey.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Request rejected before dispatch: API key is missing');
      return Promise.reject(new Error('请先保存 DeepSeek API Key'));
    }
    this.cancel();
    const request: http.HttpRequest = http.createHttp();
    const requestId: string = this.nextRequestId();
    const startedAt: number = Date.now();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      '[%{public}s] Dispatch model=deepseek-v4-flash messages=%{public}d timeoutMs=%{public}d',
      requestId, messages.length, REQUEST_TIMEOUT_MS);
    return new Promise<string>((resolve: (content: string) => void, reject: (error: Error) => void) => {
      let finished: boolean = false;
      let deadline: number = 0;
      const close = (): void => {
        if (deadline > 0) {
          clearTimeout(deadline);
          deadline = 0;
        }
        this.cancelActive = undefined;
        request.destroy();
      };
      const fail = (message: string): void => {
        if (finished) {
          return;
        }
        finished = true;
        close();
        reject(new Error(message));
      };
      const succeed = (content: string): void => {
        if (finished) {
          return;
        }
        finished = true;
        close();
        resolve(content);
      };
      this.cancelActive = (): void => {
        hilog.info(LOG_DOMAIN, LOG_TAG, '[%{public}s] Cancelled elapsedMs=%{public}d',
          requestId, Date.now() - startedAt);
        fail(CANCELLED_MESSAGE);
      };
      deadline = setTimeout(() => {
        hilog.warn(LOG_DOMAIN, LOG_TAG, '[%{public}s] Application deadline elapsedMs=%{public}d',
          requestId, Date.now() - startedAt);
        fail('等待 DeepSeek 超时（45 秒），请稍后重试');
      }, REQUEST_TIMEOUT_MS);
      const body: DeepSeekChatRequest = {
        model: 'deepseek-v4-flash',
        messages: messages,
        thinking: { type: 'disabled' },
        stream: false,
        max_tokens: 320,
        temperature: 0.7
      };
      request.request(DEEPSEEK_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Accept': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      }).then((response: http.HttpResponse) => {
        const statusCode: number = response.responseCode as number;
        const responseBytes: number = (response.result as string).length;
        hilog.info(LOG_DOMAIN, LOG_TAG,
          '[%{public}s] HTTP response status=%{public}d bytes=%{public}d elapsedMs=%{public}d',
          requestId, statusCode, responseBytes, Date.now() - startedAt);
        try {
          const content: string = this.responseContent(response);
          hilog.info(LOG_DOMAIN, LOG_TAG,
            '[%{public}s] Completed contentChars=%{public}d elapsedMs=%{public}d',
            requestId, content.length, Date.now() - startedAt);
          succeed(content);
        } catch (error) {
          hilog.error(LOG_DOMAIN, LOG_TAG,
            '[%{public}s] Response rejected status=%{public}d reason=%{public}s elapsedMs=%{public}d',
            requestId, statusCode, this.safeLogMessage((error as Error).message), Date.now() - startedAt);
          fail((error as Error).message);
        }
      }).catch((error: BusinessError) => {
        hilog.error(LOG_DOMAIN, LOG_TAG,
          '[%{public}s] Network failure code=%{public}d reason=%{public}s elapsedMs=%{public}d',
          requestId, error.code, this.safeLogMessage(error.message), Date.now() - startedAt);
        fail(this.networkMessage(error));
      });
    });
  }

  private nextRequestId(): string {
    DeepSeekClient.requestSequence += 1;
    return `${Date.now()}-${DeepSeekClient.requestSequence}`;
  }

  private safeLogMessage(message: string): string {
    const redacted: string = message.replace(/(?:Bearer\s+|sk-)[A-Za-z0-9._-]+/g, '[redacted]');
    return redacted.length > 180 ? `${redacted.slice(0, 180)}…` : redacted;
  }

  private responseContent(response: http.HttpResponse): string {
    const statusCode: number = response.responseCode as number;
    const source: string = response.result as string;
    let payload: DeepSeekChatResponse;
    try {
      payload = JSON.parse(source) as DeepSeekChatResponse;
    } catch (error) {
      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(this.statusMessage(statusCode, ''));
      }
      throw new Error('DeepSeek 返回了无法解析的数据');
    }
    const providerMessage: string = payload.error?.message ?? '';
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(this.statusMessage(statusCode, providerMessage));
    }
    if (providerMessage.length > 0) {
      throw new Error(providerMessage);
    }
    const content: string = payload.choices?.[0]?.message?.content ?? '';
    if (content.trim().length === 0) {
      throw new Error('DeepSeek 没有返回内容，请重试');
    }
    return content;
  }

  private networkMessage(error: BusinessError): string {
    const message: string = error.message ?? '';
    if (error.code === 2300006 || message.indexOf('2300006') >= 0) {
      return '无法解析 DeepSeek 地址，请检查网络或 DNS';
    }
    if (error.code === 2300007 || message.indexOf('2300007') >= 0) {
      return '无法连接 DeepSeek，请检查网络';
    }
    if (error.code === 2300028 || message.indexOf('2300028') >= 0 ||
      message.toLowerCase().indexOf('timeout') >= 0) {
      return '等待 DeepSeek 超时（45 秒），请稍后重试';
    }
    if (error.code === 2300060 || message.indexOf('2300060') >= 0) {
      return 'DeepSeek 安全连接失败，请检查系统时间和网络证书';
    }
    return message.length > 0 ? `无法连接 DeepSeek：${message}` : '无法连接 DeepSeek，请检查网络';
  }

  private statusMessage(statusCode: number, providerMessage: string): string {
    if (statusCode === 401) {
      return 'DeepSeek API Key 无效';
    }
    if (statusCode === 402) {
      return 'DeepSeek 账户余额不足';
    }
    if (statusCode === 429) {
      return 'DeepSeek 请求过于频繁，请稍后再试';
    }
    if (statusCode === 503) {
      return 'DeepSeek 当前繁忙，请稍后再试';
    }
    return providerMessage.length > 0 ? providerMessage : `DeepSeek 返回 HTTP ${statusCode}`;
  }

  static isCancelled(error: Error): boolean {
    return error.message === CANCELLED_MESSAGE;
  }
}
