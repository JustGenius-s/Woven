import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  extractBilibiliAid,
  extractBilibiliBvid,
  isBilibiliUrl
} from '../model/VideoModels';

const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'KotobaBili';
const BROWSER_UA: string =
  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
const BILI_REFERER: string = 'https://www.bilibili.com';
const VIEW_API: string = 'https://api.bilibili.com/x/web-interface/view';
const PLAY_API: string = 'https://api.bilibili.com/x/player/playurl';
const CONNECT_TIMEOUT_MS: number = 8000;
const READ_TIMEOUT_MS: number = 15000;

export interface ResolvedVideoStream {
  playUrl: string;
  title: string;
  durationMs: number;
  headers: Record<string, string>;
}

interface BiliViewResponse {
  code?: number;
  message?: string;
  data?: BiliViewData;
}

interface BiliViewData {
  title?: string;
  cid?: number;
  aid?: number;
  bvid?: string;
  duration?: number;
}

interface BiliPlayResponse {
  code?: number;
  message?: string;
  data?: BiliPlayData;
}

interface BiliPlayData {
  durl?: BiliDurl[];
}

interface BiliDurl {
  url?: string;
}

export class BilibiliStreamResolver {
  static canResolve(url: string): boolean {
    return isBilibiliUrl(url);
  }

  static async resolve(rawUrl: string): Promise<ResolvedVideoStream> {
    const pageUrl: string = await BilibiliStreamResolver.expandShortUrl(rawUrl.trim());
    const bvid: string = extractBilibiliBvid(pageUrl);
    const aid: string = bvid.length > 0 ? '' : extractBilibiliAid(pageUrl);
    if (bvid.length === 0 && aid.length === 0) {
      throw new Error('请粘贴完整的哔哩哔哩视频链接');
    }
    const view: BiliViewData = await BilibiliStreamResolver.fetchView(bvid, aid);
    const cid: number = view.cid ?? 0;
    const viewBvid: string = view.bvid ?? bvid;
    if (cid <= 0) {
      throw new Error('没有找到可播放的分集');
    }
    const playUrl: string = await BilibiliStreamResolver.fetchPlayUrl(viewBvid, cid);
    return {
      playUrl: playUrl,
      title: view.title ?? '',
      durationMs: (view.duration ?? 0) * 1000,
      headers: BilibiliStreamResolver.mediaHeaders()
    };
  }

  static mediaHeaders(): Record<string, string> {
    return {
      'User-Agent': BROWSER_UA,
      'Referer': BILI_REFERER
    };
  }

  private static async expandShortUrl(url: string): Promise<string> {
    if (url.indexOf('b23.tv') < 0 && url.indexOf('bili2233.cn') < 0) {
      return url;
    }
    let current: string = url;
    for (let hop: number = 0; hop < 5; hop++) {
      const location: string = await BilibiliStreamResolver.readRedirect(current);
      if (location.length === 0) {
        return current;
      }
      current = location;
      if (extractBilibiliBvid(current).length > 0 || extractBilibiliAid(current).length > 0) {
        return current;
      }
    }
    return current;
  }

  private static async readRedirect(url: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: BilibiliStreamResolver.mediaHeaders(),
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        maxRedirects: 0
      });
      const status: number = response.responseCode as number;
      if (status >= 300 && status < 400) {
        return BilibiliStreamResolver.headerValue(response.header, 'location');
      }
      const fromBody: string = extractBilibiliBvid(`${response.result}`);
      return fromBody.length > 0 ? `https://www.bilibili.com/video/${fromBody}` : '';
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'short url hop failed: %{public}s',
        error instanceof Error ? error.message : JSON.stringify(error));
      return '';
    } finally {
      request.destroy();
    }
  }

  private static async fetchView(bvid: string, aid: string): Promise<BiliViewData> {
    const query: string = bvid.length > 0 ? `bvid=${encodeURIComponent(bvid)}` :
      `aid=${encodeURIComponent(aid)}`;
    const payload: BiliViewResponse =
      await BilibiliStreamResolver.getJson<BiliViewResponse>(`${VIEW_API}?${query}`);
    if ((payload.code ?? -1) !== 0 || payload.data === undefined) {
      throw new Error(payload.message && payload.message.length > 0 ?
        payload.message : '哔哩哔哩视频信息解析失败');
    }
    return payload.data;
  }

  private static async fetchPlayUrl(bvid: string, cid: number): Promise<string> {
    const qualities: number[] = [64, 32, 16];
    let lastError: string = '没有可用的播放地址';
    for (let index: number = 0; index < qualities.length; index++) {
      const qn: number = qualities[index];
      const url: string = `${PLAY_API}?bvid=${encodeURIComponent(bvid)}&cid=${cid}` +
        `&qn=${qn}&fnval=1&fnver=0&fourk=0&platform=html5`;
      try {
        const payload: BiliPlayResponse =
          await BilibiliStreamResolver.getJson<BiliPlayResponse>(url);
        if ((payload.code ?? -1) !== 0) {
          lastError = payload.message && payload.message.length > 0 ?
            payload.message : lastError;
          continue;
        }
        const playUrl: string = payload.data?.durl?.[0]?.url ?? '';
        if (playUrl.length > 0) {
          return playUrl;
        }
      } catch (error) {
        lastError = error instanceof Error ? error.message : lastError;
      }
    }
    throw new Error(lastError);
  }

  private static async getJson<T>(url: string): Promise<T> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: BilibiliStreamResolver.mediaHeaders(),
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false
      });
      const status: number = response.responseCode as number;
      const body: string = `${response.result}`;
      if (status < 200 || status >= 300) {
        throw new Error(`解析服务返回 ${status}`);
      }
      return JSON.parse(body) as T;
    } finally {
      request.destroy();
    }
  }

  private static headerValue(header: Object, name: string): string {
    const record: Record<string, Object> = header as Record<string, Object>;
    const keys: string[] = Object.keys(record);
    for (let index: number = 0; index < keys.length; index++) {
      if (keys[index].toLowerCase() !== name) {
        continue;
      }
      const value: Object = record[keys[index]];
      if (typeof value === 'string') {
        return value;
      }
      if (value instanceof Array && value.length > 0) {
        return `${value[0]}`;
      }
    }
    return '';
  }
}
