import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import {
  VIDEO_SOURCE_FILE,
  VIDEO_SOURCE_URL,
  VideoItem
} from '../model/VideoModels';

const LIBRARY_DIRECTORY: string = 'videos';
const LIBRARY_FILE: string = 'library.json';

export class VideoLibraryStore {
  static load(context: common.Context): VideoItem[] {
    const path: string = VideoLibraryStore.libraryPath(context);
    try {
      if (!fileIo.accessSync(path)) {
        return [];
      }
      const stored: VideoItem[] = JSON.parse(fileIo.readTextSync(path)) as VideoItem[];
      const result: VideoItem[] = [];
      for (let index: number = 0; index < stored.length; index++) {
        const item: VideoItem = stored[index];
        if (item.id.length > 0 && item.source.length > 0 && item.title.length > 0) {
          result.push(item);
        }
      }
      return result;
    } catch (_error) {
      return [];
    }
  }

  static addUrl(context: common.Context, rawUrl: string, rawTitle: string): VideoItem {
    const url: string = VideoLibraryStore.normalizedUrl(rawUrl);
    if (url.length === 0) {
      throw new Error('请输入以 http 或 https 开头的视频链接');
    }
    const title: string = rawTitle.trim().length > 0 ? rawTitle.trim() : VideoLibraryStore.titleFromUrl(url);
    const item: VideoItem = {
      id: VideoLibraryStore.nextId(),
      title: title,
      sourceKind: VIDEO_SOURCE_URL,
      source: url,
      createdAt: Date.now(),
      durationMs: 0
    };
    const videos: VideoItem[] = VideoLibraryStore.load(context);
    videos.unshift(item);
    VideoLibraryStore.save(context, videos);
    return item;
  }

  static async importFromUri(context: common.Context, uri: string, nameHint: string): Promise<VideoItem> {
    if (uri.length === 0) {
      throw new Error('没有选中视频');
    }
    const id: string = VideoLibraryStore.nextId();
    const extension: string = VideoLibraryStore.extensionOf(uri, nameHint);
    const directory: string = VideoLibraryStore.ensureDirectory(context);
    const destPath: string = `${directory}/${id}${extension}`;
    const sourceFile: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    try {
      fileIo.copyFileSync(sourceFile.fd, destPath);
    } finally {
      fileIo.closeSync(sourceFile);
    }
    const title: string = VideoLibraryStore.titleFromName(nameHint, uri);
    const item: VideoItem = {
      id: id,
      title: title,
      sourceKind: VIDEO_SOURCE_FILE,
      source: destPath,
      createdAt: Date.now(),
      durationMs: 0
    };
    const videos: VideoItem[] = VideoLibraryStore.load(context);
    videos.unshift(item);
    VideoLibraryStore.save(context, videos);
    return item;
  }

  static remove(context: common.Context, videoId: string): VideoItem[] {
    const videos: VideoItem[] = VideoLibraryStore.load(context);
    const next: VideoItem[] = [];
    for (let index: number = 0; index < videos.length; index++) {
      const item: VideoItem = videos[index];
      if (item.id === videoId) {
        if (item.sourceKind === VIDEO_SOURCE_FILE) {
          VideoLibraryStore.removeFile(item.source);
        }
      } else {
        next.push(item);
      }
    }
    VideoLibraryStore.save(context, next);
    return next;
  }

  static saveTitle(context: common.Context, videoId: string, title: string): void {
    const nextTitle: string = title.trim();
    if (nextTitle.length === 0) {
      return;
    }
    const videos: VideoItem[] = VideoLibraryStore.load(context);
    let changed: boolean = false;
    for (let index: number = 0; index < videos.length; index++) {
      if (videos[index].id === videoId && videos[index].title !== nextTitle) {
        videos[index].title = nextTitle;
        changed = true;
      }
    }
    if (changed) {
      VideoLibraryStore.save(context, videos);
    }
  }

  static saveDuration(context: common.Context, videoId: string, durationMs: number): void {
    if (durationMs <= 0) {
      return;
    }
    const videos: VideoItem[] = VideoLibraryStore.load(context);
    let changed: boolean = false;
    for (let index: number = 0; index < videos.length; index++) {
      if (videos[index].id === videoId && videos[index].durationMs !== durationMs) {
        videos[index].durationMs = durationMs;
        changed = true;
      }
    }
    if (changed) {
      VideoLibraryStore.save(context, videos);
    }
  }

  static normalizedUrl(rawUrl: string): string {
    const value: string = rawUrl.trim();
    if (value.indexOf('https://') === 0 || value.indexOf('http://') === 0) {
      return value;
    }
    return '';
  }

  private static save(context: common.Context, videos: VideoItem[]): void {
    const directory: string = VideoLibraryStore.ensureDirectory(context);
    const path: string = `${directory}/${LIBRARY_FILE}`;
    const file: fileIo.File = fileIo.openSync(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, JSON.stringify(videos));
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static libraryPath(context: common.Context): string {
    return `${context.filesDir}/${LIBRARY_DIRECTORY}/${LIBRARY_FILE}`;
  }

  private static ensureDirectory(context: common.Context): string {
    const path: string = `${context.filesDir}/${LIBRARY_DIRECTORY}`;
    try {
      if (fileIo.statSync(path).isDirectory()) {
        return path;
      }
    } catch (_error) {
      // Missing — create below.
    }
    fileIo.mkdirSync(path, true);
    return path;
  }

  private static nextId(): string {
    return `video-${Date.now()}`;
  }

  private static titleFromUrl(url: string): string {
    const videoId: string = VideoLibraryStore.pageVideoId(url);
    if (videoId.length > 0) {
      return videoId;
    }
    let path: string = url;
    const query: number = path.indexOf('?');
    if (query >= 0) {
      path = path.substring(0, query);
    }
    const slash: number = path.lastIndexOf('/');
    const name: string = slash >= 0 ? path.substring(slash + 1) : path;
    return VideoLibraryStore.decodeName(name).length > 0 ? VideoLibraryStore.decodeName(name) : '网络视频';
  }

  private static pageVideoId(url: string): string {
    const marker: string = '/video/';
    const start: number = url.indexOf(marker);
    if (start < 0) {
      return '';
    }
    let id: string = url.substring(start + marker.length);
    const slash: number = id.indexOf('/');
    if (slash >= 0) {
      id = id.substring(0, slash);
    }
    const query: number = id.indexOf('?');
    if (query >= 0) {
      id = id.substring(0, query);
    }
    return id;
  }

  private static titleFromName(nameHint: string, uri: string): string {
    const hint: string = VideoLibraryStore.stripExtension(VideoLibraryStore.decodeName(nameHint));
    if (hint.length > 0) {
      return hint;
    }
    return VideoLibraryStore.titleFromUrl(uri);
  }

  private static extensionOf(uri: string, nameHint: string): string {
    const fromHint: string = VideoLibraryStore.readExtension(nameHint);
    if (fromHint.length > 0) {
      return fromHint;
    }
    const fromUri: string = VideoLibraryStore.readExtension(uri);
    return fromUri.length > 0 ? fromUri : '.mp4';
  }

  private static readExtension(value: string): string {
    const query: number = value.indexOf('?');
    const path: string = query >= 0 ? value.substring(0, query) : value;
    const slash: number = path.lastIndexOf('/');
    const name: string = slash >= 0 ? path.substring(slash + 1) : path;
    const dot: number = name.lastIndexOf('.');
    if (dot <= 0 || dot === name.length - 1) {
      return '';
    }
    const extension: string = name.substring(dot).toLowerCase();
    if (extension === '.mp4' || extension === '.mkv' || extension === '.mov' ||
      extension === '.webm' || extension === '.m4v' || extension === '.ts') {
      return extension;
    }
    return '';
  }

  private static stripExtension(name: string): string {
    const dot: number = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  private static decodeName(value: string): string {
    try {
      return decodeURIComponent(value);
    } catch (_error) {
      return value;
    }
  }

  private static removeFile(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (_error) {
      // Best-effort cleanup; the library entry is already gone.
    }
  }
}
