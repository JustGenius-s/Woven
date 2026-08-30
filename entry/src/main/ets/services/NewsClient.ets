import { http } from '@kit.NetworkKit';
import { NewsArticle, NewsSnapshot } from '../model/ContentModels';

interface NewsEnvelope {
  ok: boolean;
  value?: NewsSnapshot;
  message?: string;
}

interface ArticleEnvelope {
  ok: boolean;
  value?: NewsArticle;
  message?: string;
}

export class NewsClient {
  private baseUrl: string;
  private appToken: string;

  constructor(baseUrl: string, appToken: string) {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.appToken = appToken;
  }

  async loadNews(): Promise<NewsSnapshot> {
    const payload: NewsEnvelope = await this.get('/api/news') as NewsEnvelope;
    if (!payload.ok || payload.value === undefined) {
      throw new Error(payload.message ?? '新闻暂时不可用');
    }
    return payload.value;
  }

  async loadArticle(url: string): Promise<NewsArticle> {
    const payload: ArticleEnvelope = await this.get(`/api/news/article?url=${encodeURIComponent(url)}`) as ArticleEnvelope;
    if (!payload.ok || payload.value === undefined) {
      throw new Error(payload.message ?? '新闻正文暂时不可用');
    }
    return payload.value;
  }

  private async get(path: string): Promise<Object> {
    if (!this.baseUrl.startsWith('http://') && !this.baseUrl.startsWith('https://')) {
      throw new Error('请先配置 AI 网关地址');
    }
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = { 'Accept': 'application/json' };
    if (this.appToken.length > 0) {
      headers['Authorization'] = `Bearer ${this.appToken}`;
    }
    try {
      const response: http.HttpResponse = await request.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 20000,
        expectDataType: http.HttpDataType.STRING
      });
      const text: string = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`新闻服务返回 HTTP ${response.responseCode}`);
      }
      try {
        return JSON.parse(text) as Object;
      } catch (error) {
        throw new Error('新闻服务返回了无法读取的内容');
      }
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '新闻服务请求失败';
      throw new Error(message);
    } finally {
      request.destroy();
    }
  }
}
