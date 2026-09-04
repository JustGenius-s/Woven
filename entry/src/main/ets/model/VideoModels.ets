export const VIDEO_SOURCE_URL: string = 'url';
export const VIDEO_SOURCE_FILE: string = 'file';

export interface VideoItem {
  id: string;
  title: string;
  sourceKind: string;
  source: string;
  createdAt: number;
  durationMs: number;
}

export enum VideoPlaybackPhase {
  IDLE = 0,
  LOADING = 1,
  READY = 2,
  PLAYING = 3,
  PAUSED = 4,
  COMPLETED = 5,
  ERROR = 6
}

export interface VideoPlaybackSnapshot {
  phase: VideoPlaybackPhase;
  videoId: string;
  positionMs: number;
  durationMs: number;
  videoWidth: number;
  videoHeight: number;
  error: string;
}

export type VideoPlaybackListener = (snapshot: VideoPlaybackSnapshot) => void;

export function emptyVideoPlaybackSnapshot(): VideoPlaybackSnapshot {
  return {
    phase: VideoPlaybackPhase.IDLE,
    videoId: '',
    positionMs: 0,
    durationMs: 0,
    videoWidth: 0,
    videoHeight: 0,
    error: ''
  };
}

export function videoSourceLabel(item: VideoItem): string {
  if (item.sourceKind === VIDEO_SOURCE_FILE) {
    return '本地视频';
  }
  if (isBilibiliUrl(item.source)) {
    return '哔哩哔哩';
  }
  if (isYouTubeUrl(item.source)) {
    return 'YouTube';
  }
  return isDirectMediaUrl(item.source) ? '网络视频' : '网页视频';
}

export function isDirectMediaUrl(url: string): boolean {
  const path: string = stripUrlQuery(url).toLowerCase();
  return path.endsWith('.mp4') || path.endsWith('.m3u8') || path.endsWith('.mkv') ||
    path.endsWith('.mov') || path.endsWith('.webm') || path.endsWith('.m4v') ||
    path.endsWith('.ts');
}

export function isWebVideoPage(url: string): boolean {
  return (url.indexOf('https://') === 0 || url.indexOf('http://') === 0) &&
    !isDirectMediaUrl(url) && !isBilibiliUrl(url);
}

export function webPlaybackUrl(url: string): string {
  if (isYouTubeUrl(url) && url.indexOf('://m.youtube.com') < 0 &&
    url.indexOf('://youtu.be') < 0) {
    return url.replace('://www.youtube.com', '://m.youtube.com')
      .replace('://youtube.com', '://m.youtube.com');
  }
  return url;
}

export function isHttpWebUrl(url: string): boolean {
  return url.indexOf('https://') === 0 || url.indexOf('http://') === 0;
}

export function isExternalAppUrl(url: string): boolean {
  return !isHttpWebUrl(url) && url.indexOf('about:') !== 0 &&
    url.indexOf('blob:') !== 0 && url.indexOf('data:') !== 0;
}

export function extractBilibiliBvid(text: string): string {
  const index: number = text.indexOf('BV');
  if (index < 0) {
    return '';
  }
  let end: number = index + 2;
  while (end < text.length && isVideoIdChar(text.charAt(end))) {
    end++;
  }
  const bvid: string = text.substring(index, end);
  return bvid.length >= 10 ? bvid : '';
}

export function extractBilibiliAid(text: string): string {
  const lower: string = text.toLowerCase();
  const marker: string = '/video/av';
  let start: number = -1;
  const marked: number = lower.indexOf(marker);
  if (marked >= 0) {
    start = marked + marker.length;
  } else {
    const bare: number = lower.indexOf('av');
    if (bare >= 0 && (bare === 0 || !isVideoIdChar(text.charAt(bare - 1)))) {
      start = bare + 2;
    }
  }
  if (start < 0) {
    return '';
  }
  let end: number = start;
  while (end < text.length && text.charAt(end) >= '0' && text.charAt(end) <= '9') {
    end++;
  }
  return text.substring(start, end);
}

function isVideoIdChar(ch: string): boolean {
  return (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') ||
    (ch >= 'a' && ch <= 'z');
}

export function isBilibiliUrl(url: string): boolean {
  return url.indexOf('bilibili.com') >= 0 || url.indexOf('b23.tv') >= 0 ||
    url.indexOf('bili2233.cn') >= 0;
}

export function isYouTubeUrl(url: string): boolean {
  return url.indexOf('youtube.com') >= 0 || url.indexOf('youtu.be') >= 0;
}

function stripUrlQuery(url: string): string {
  const query: number = url.indexOf('?');
  return query >= 0 ? url.substring(0, query) : url;
}
