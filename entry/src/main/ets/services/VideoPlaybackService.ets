import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  emptyVideoPlaybackSnapshot,
  isDirectMediaUrl,
  VIDEO_SOURCE_FILE,
  VideoItem,
  VideoPlaybackListener,
  VideoPlaybackPhase,
  VideoPlaybackSnapshot
} from '../model/VideoModels';
import { BilibiliStreamResolver, ResolvedVideoStream } from './BilibiliStreamResolver';
import { MusicPlaybackService } from './MusicPlaybackService';
import { movieRendererInfo, PlayerStateMachine } from './MusicPlaybackStateMachine';
import { VideoLibraryStore } from './VideoLibraryStore';

const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'KotobaVideo';

export class VideoPlaybackService {
  private static context: common.Context | undefined = undefined;
  private static player: media.AVPlayer | undefined = undefined;
  private static machine: PlayerStateMachine = new PlayerStateMachine();
  private static listeners: VideoPlaybackListener[] = [];
  private static playback: VideoPlaybackSnapshot = emptyVideoPlaybackSnapshot();
  private static current: VideoItem | undefined = undefined;
  private static sourceFile: fileIo.File | undefined = undefined;
  private static sourceToken: number = 0;
  private static surfaceId: string = '';
  private static autoplayOnPrepared: boolean = true;
  private static pendingLoad: boolean = false;

  static initialize(context: common.Context): void {
    VideoPlaybackService.context = context;
  }

  static snapshot(): VideoPlaybackSnapshot {
    return {
      phase: VideoPlaybackService.playback.phase,
      videoId: VideoPlaybackService.playback.videoId,
      positionMs: VideoPlaybackService.playback.positionMs,
      durationMs: VideoPlaybackService.playback.durationMs,
      videoWidth: VideoPlaybackService.playback.videoWidth,
      videoHeight: VideoPlaybackService.playback.videoHeight,
      error: VideoPlaybackService.playback.error
    };
  }

  static currentItem(): VideoItem | undefined {
    return VideoPlaybackService.current;
  }

  static subscribe(listener: VideoPlaybackListener): void {
    if (VideoPlaybackService.listeners.indexOf(listener) < 0) {
      VideoPlaybackService.listeners.push(listener);
    }
    listener(VideoPlaybackService.snapshot());
  }

  static unsubscribe(listener: VideoPlaybackListener): void {
    const next: VideoPlaybackListener[] = [];
    for (let index: number = 0; index < VideoPlaybackService.listeners.length; index++) {
      if (VideoPlaybackService.listeners[index] !== listener) {
        next.push(VideoPlaybackService.listeners[index]);
      }
    }
    VideoPlaybackService.listeners = next;
  }

  static attachSurface(surfaceId: string): void {
    VideoPlaybackService.surfaceId = surfaceId;
    const player: media.AVPlayer | undefined = VideoPlaybackService.player;
    if (player !== undefined && surfaceId.length > 0) {
      player.surfaceId = surfaceId;
    }
    if (VideoPlaybackService.pendingLoad && VideoPlaybackService.current !== undefined) {
      void VideoPlaybackService.load(VideoPlaybackService.current, VideoPlaybackService.autoplayOnPrepared);
    }
  }

  static play(item: VideoItem, autoplay: boolean = true): void {
    VideoPlaybackService.current = item;
    VideoPlaybackService.autoplayOnPrepared = autoplay;
    VideoPlaybackService.playback = {
      phase: VideoPlaybackPhase.LOADING,
      videoId: item.id,
      positionMs: 0,
      durationMs: item.durationMs,
      videoWidth: 0,
      videoHeight: 0,
      error: ''
    };
    VideoPlaybackService.notify();
    if (VideoPlaybackService.surfaceId.length === 0) {
      VideoPlaybackService.pendingLoad = true;
      return;
    }
    void VideoPlaybackService.load(item, autoplay);
  }

  static toggle(): void {
    const player: media.AVPlayer | undefined = VideoPlaybackService.player;
    if (player === undefined) {
      return;
    }
    if (VideoPlaybackService.playback.phase === VideoPlaybackPhase.PLAYING) {
      void VideoPlaybackService.pause();
      return;
    }
    void VideoPlaybackService.resume();
  }

  static async pause(): Promise<void> {
    const player: media.AVPlayer | undefined = VideoPlaybackService.player;
    if (player === undefined) {
      return;
    }
    try {
      if (player.state === 'playing') {
        await player.pause();
      }
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'pause failed: %{public}s', JSON.stringify(error));
    }
  }

  static seek(positionMs: number): void {
    const player: media.AVPlayer | undefined = VideoPlaybackService.player;
    if (player === undefined) {
      return;
    }
    const upper: number = VideoPlaybackService.playback.durationMs > 0 ?
      VideoPlaybackService.playback.durationMs : positionMs;
    const target: number = Math.max(0, Math.min(Math.floor(positionMs), upper));
    try {
      player.seek(target, media.SeekMode.SEEK_CLOSEST);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'seek failed: %{public}s', JSON.stringify(error));
    }
  }

  static async release(): Promise<void> {
    VideoPlaybackService.sourceToken += 1;
    VideoPlaybackService.pendingLoad = false;
    const player: media.AVPlayer | undefined = VideoPlaybackService.player;
    VideoPlaybackService.player = undefined;
    VideoPlaybackService.current = undefined;
    VideoPlaybackService.surfaceId = '';
    VideoPlaybackService.closeSourceFile();
    VideoPlaybackService.playback = emptyVideoPlaybackSnapshot();
    VideoPlaybackService.notify();
    if (player !== undefined) {
      try {
        await player.release();
      } catch (_error) {
        // Already released.
      }
    }
  }

  private static async resume(): Promise<void> {
    const player: media.AVPlayer | undefined = VideoPlaybackService.player;
    if (player === undefined) {
      return;
    }
    try {
      if (player.state === 'completed') {
        player.seek(0, media.SeekMode.SEEK_CLOSEST);
      }
      await player.play();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'play failed: %{public}s', JSON.stringify(error));
    }
  }

  private static async load(item: VideoItem, autoplay: boolean): Promise<void> {
    const token: number = VideoPlaybackService.sourceToken + 1;
    VideoPlaybackService.sourceToken = token;
    VideoPlaybackService.pendingLoad = false;
    try {
      await MusicPlaybackService.pause();
    } catch (_error) {
      // Music may not have a prepared source.
    }
    try {
      const player: media.AVPlayer = await VideoPlaybackService.ensurePlayer();
      if (token !== VideoPlaybackService.sourceToken) {
        return;
      }
      if (player.state !== 'idle') {
        await player.reset();
        const idle: boolean = await VideoPlaybackService.machine.waitFor('idle',
          () => token !== VideoPlaybackService.sourceToken);
        if (token !== VideoPlaybackService.sourceToken || !idle) {
          return;
        }
      }
      VideoPlaybackService.closeSourceFile();
      if (item.sourceKind === VIDEO_SOURCE_FILE) {
        const sourceFile: fileIo.File = fileIo.openSync(item.source, fileIo.OpenMode.READ_ONLY);
        VideoPlaybackService.sourceFile = sourceFile;
        player.fdSrc = { fd: sourceFile.fd };
      } else if (BilibiliStreamResolver.canResolve(item.source) && !isDirectMediaUrl(item.source)) {
        const stream: ResolvedVideoStream = await BilibiliStreamResolver.resolve(item.source);
        if (token !== VideoPlaybackService.sourceToken) {
          return;
        }
        VideoPlaybackService.applyResolvedMeta(item, stream);
        const source: media.MediaSource =
          media.createMediaSourceWithUrl(stream.playUrl, stream.headers);
        await player.setMediaSource(source);
      } else {
        player.url = item.source;
      }
      if (VideoPlaybackService.machine.state !== 'prepared') {
        if (VideoPlaybackService.machine.state !== 'initialized') {
          const initialized: boolean = await VideoPlaybackService.machine.waitFor('initialized',
            () => token !== VideoPlaybackService.sourceToken);
          if (token !== VideoPlaybackService.sourceToken || !initialized) {
            return;
          }
        }
        if (VideoPlaybackService.surfaceId.length > 0) {
          player.surfaceId = VideoPlaybackService.surfaceId;
        }
        player.audioRendererInfo = movieRendererInfo();
        await player.prepare();
        const prepared: boolean = await VideoPlaybackService.machine.waitFor('prepared',
          () => token !== VideoPlaybackService.sourceToken);
        if (token !== VideoPlaybackService.sourceToken || !prepared) {
          return;
        }
      } else if (VideoPlaybackService.surfaceId.length > 0) {
        player.surfaceId = VideoPlaybackService.surfaceId;
      }
      const durationMs: number = player.duration > 0 ? player.duration : item.durationMs;
      VideoPlaybackService.playback = {
        phase: VideoPlaybackPhase.READY,
        videoId: item.id,
        positionMs: 0,
        durationMs: durationMs,
        videoWidth: VideoPlaybackService.playback.videoWidth,
        videoHeight: VideoPlaybackService.playback.videoHeight,
        error: ''
      };
      VideoPlaybackService.notify();
      if (VideoPlaybackService.context !== undefined && durationMs > 0) {
        VideoLibraryStore.saveDuration(VideoPlaybackService.context, item.id, durationMs);
      }
      if (autoplay) {
        await player.play();
      }
    } catch (error) {
      if (token === VideoPlaybackService.sourceToken) {
        VideoPlaybackService.fail(error);
      }
    }
  }

  private static async ensurePlayer(): Promise<media.AVPlayer> {
    if (VideoPlaybackService.player !== undefined && VideoPlaybackService.player.state !== 'released') {
      return VideoPlaybackService.player;
    }
    const player: media.AVPlayer = await media.createAVPlayer();
    VideoPlaybackService.player = player;
    VideoPlaybackService.machine = new PlayerStateMachine();
    player.on('stateChange', (state: media.AVPlayerState) => {
      VideoPlaybackService.machine.onStateChange(state);
      VideoPlaybackService.handlePlayerState(state);
    });
    player.on('timeUpdate', (positionMs: number) => {
      VideoPlaybackService.playback.positionMs = positionMs;
      VideoPlaybackService.notify();
    });
    player.on('durationUpdate', (durationMs: number) => {
      if (durationMs > 0) {
        VideoPlaybackService.playback.durationMs = durationMs;
        VideoPlaybackService.notify();
        if (VideoPlaybackService.context !== undefined && VideoPlaybackService.current !== undefined) {
          VideoLibraryStore.saveDuration(VideoPlaybackService.context, VideoPlaybackService.current.id,
            durationMs);
        }
      }
    });
    player.on('seekDone', (positionMs: number) => {
      VideoPlaybackService.playback.positionMs = positionMs;
      VideoPlaybackService.notify();
    });
    player.on('videoSizeChange', (width: number, height: number) => {
      if (width <= 0 || height <= 0) {
        return;
      }
      VideoPlaybackService.playback.videoWidth = width;
      VideoPlaybackService.playback.videoHeight = height;
      VideoPlaybackService.notify();
    });
    player.on('error', (error: BusinessError) => {
      VideoPlaybackService.fail(error);
    });
    return player;
  }

  private static handlePlayerState(state: media.AVPlayerState): void {
    switch (state) {
      case 'playing':
        VideoPlaybackService.playback.phase = VideoPlaybackPhase.PLAYING;
        VideoPlaybackService.notify();
        break;
      case 'paused':
        VideoPlaybackService.playback.phase = VideoPlaybackPhase.PAUSED;
        VideoPlaybackService.notify();
        break;
      case 'completed':
        VideoPlaybackService.playback.phase = VideoPlaybackPhase.COMPLETED;
        VideoPlaybackService.notify();
        break;
      default:
        break;
    }
  }

  private static applyResolvedMeta(item: VideoItem, stream: ResolvedVideoStream): void {
    if (stream.title.length > 0) {
      item.title = stream.title;
      if (VideoPlaybackService.current !== undefined &&
        VideoPlaybackService.current.id === item.id) {
        VideoPlaybackService.current.title = stream.title;
      }
      if (VideoPlaybackService.context !== undefined) {
        VideoLibraryStore.saveTitle(VideoPlaybackService.context, item.id, stream.title);
      }
    }
    if (stream.durationMs > 0) {
      VideoPlaybackService.playback.durationMs = stream.durationMs;
      VideoPlaybackService.notify();
    }
  }

  private static fail(error: Object): void {
    const detail: string = error instanceof Error ? error.message : JSON.stringify(error);
    hilog.error(LOG_DOMAIN, LOG_TAG, 'playback failed: %{public}s', detail);
    VideoPlaybackService.playback.phase = VideoPlaybackPhase.ERROR;
    VideoPlaybackService.playback.error = error instanceof Error && error.message.length > 0 ?
      error.message : '视频暂时无法播放';
    VideoPlaybackService.notify();
  }

  private static closeSourceFile(): void {
    if (VideoPlaybackService.sourceFile !== undefined) {
      try {
        fileIo.closeSync(VideoPlaybackService.sourceFile);
      } catch (_error) {
        // Already closed.
      }
      VideoPlaybackService.sourceFile = undefined;
    }
  }

  private static notify(): void {
    const snapshot: VideoPlaybackSnapshot = VideoPlaybackService.snapshot();
    for (let index: number = 0; index < VideoPlaybackService.listeners.length; index++) {
      VideoPlaybackService.listeners[index](snapshot);
    }
  }
}
