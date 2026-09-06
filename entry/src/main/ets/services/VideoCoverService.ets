import { common } from '@kit.AbilityKit';
import { url } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { isBilibiliUrl, isDirectMediaUrl, isYouTubeUrl, VIDEO_SOURCE_FILE, VideoItem } from '../model/VideoModels';
import { BilibiliStreamResolver } from './BilibiliStreamResolver';
import { VideoCoverMetadata } from './VideoCoverMetadata';
import { VideoLibraryStore } from './VideoLibraryStore';

interface VideoOEmbed {
  thumbnail_url?: string;
}

export class VideoCoverService {
  private static pending: Map<string, Promise<string>> = new Map();

  static async ensure(context: common.Context, video: VideoItem): Promise<string> {
    const path: string = VideoLibraryStore.coverFilePath(context, video.id);
    const existing: Promise<string> | undefined = VideoCoverService.pending.get(path);
    if (existing !== undefined) {
      return existing;
    }
    const task: Promise<string> = VideoCoverService.load(context, video, path).catch((error: Error) => {
      hilog.warn(0x4b4f, 'KotobaVideoCover', 'Cover unavailable: %{public}s',
        error instanceof Error ? error.message : 'media source unavailable');
      return '';
    }).finally(() => {
      VideoCoverService.pending.delete(path);
    });
    VideoCoverService.pending.set(path, task);
    return task;
  }

  private static async load(context: common.Context, video: VideoItem, path: string): Promise<string> {
    if (fileIo.accessSync(path) && fileIo.statSync(path).size > 0) {
      return VideoLibraryStore.saveCover(context, video.id, path) ? path : '';
    }
    let bytes: ArrayBuffer;
    if (video.sourceKind === VIDEO_SOURCE_FILE) {
      bytes = await VideoCoverService.localFrame(video.source);
    } else if (isDirectMediaUrl(video.source)) {
      // AVMetadataExtractor reads the needed ranges; don't download a whole film.
      bytes = await VideoCoverService.remoteFrame(video.source);
    } else {
      let artwork: string = '';
      if (isBilibiliUrl(video.source)) {
        artwork = await BilibiliStreamResolver.coverUrl(video.source);
      } else if (isYouTubeUrl(video.source)) {
        const response: http.HttpResponse = await VideoCoverService.request(
          `https://www.youtube.com/oembed?url=${encodeURIComponent(video.source)}&format=json`, false);
        artwork = (JSON.parse(response.result as string) as VideoOEmbed).thumbnail_url ?? '';
      } else {
        const response: http.HttpResponse = await VideoCoverService.request(video.source, false);
        artwork = VideoCoverMetadata.imageFromHtml(response.result as string);
      }
      if (artwork.length === 0) {
        return '';
      }
      const resolved: string = new url.URL(artwork, video.source).toString();
      if (!resolved.startsWith('https://') && !resolved.startsWith('http://')) {
        return '';
      }
      const response: http.HttpResponse = await VideoCoverService.request(resolved, true,
        isBilibiliUrl(video.source) ? BilibiliStreamResolver.mediaHeaders() : {});
      bytes = response.result as ArrayBuffer;
      const source: image.ImageSource = image.createImageSource(bytes);
      try {
        await source.getImageInfo();
      } finally {
        await source.release();
      }
    }
    const directory: string = path.substring(0, path.lastIndexOf('/'));
    if (!fileIo.accessSync(directory)) {
      fileIo.mkdirSync(directory, true);
    }
    const file: fileIo.File = fileIo.openSync(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, bytes);
    } finally {
      fileIo.closeSync(file);
    }
    if (!VideoLibraryStore.saveCover(context, video.id, path)) {
      fileIo.unlinkSync(path);
      return '';
    }
    return path;
  }

  private static async localFrame(path: string): Promise<ArrayBuffer> {
    const generator: media.AVImageGenerator = await media.createAVImageGenerator();
    let source: fileIo.File | undefined = undefined;
    try {
      source = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      generator.fdSrc = { fd: source.fd };
      const frame: image.PixelMap = await generator.fetchFrameByTime(0,
        media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC, { width: 640, height: 360 });
      return await VideoCoverService.encodeFrame(frame);
    } finally {
      try {
        await generator.release();
      } finally {
        if (source !== undefined) {
          fileIo.closeSync(source);
        }
      }
    }
  }

  private static async remoteFrame(source: string): Promise<ArrayBuffer> {
    const extractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
    try {
      extractor.setUrlSource(source);
      const frame: image.PixelMap | undefined = await extractor.fetchFrameByTimeWithTimeout(0,
        media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC, { width: 640, height: 360 }, 10000);
      if (frame === undefined) {
        throw new Error('视频缩略图读取超时');
      }
      return await VideoCoverService.encodeFrame(frame);
    } finally {
      await extractor.release();
    }
  }

  private static async encodeFrame(frame: image.PixelMap): Promise<ArrayBuffer> {
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      return await packer.packing(frame, { format: 'image/jpeg', quality: 82 });
    } finally {
      try {
        await packer.release();
      } finally {
        await frame.release();
      }
    }
  }

  private static async request(source: string, binary: boolean,
    headers: Record<string, string> = {}): Promise<http.HttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(source, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: binary ? http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.STRING,
        connectTimeout: 6000,
        readTimeout: 10000,
        maxLimit: 4 * 1024 * 1024
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`封面服务返回 ${response.responseCode}`);
      }
      return response;
    } finally {
      request.destroy();
    }
  }
}
