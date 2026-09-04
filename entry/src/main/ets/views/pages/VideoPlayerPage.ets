import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { statusBarInset, systemGestureInset } from '../../common/AppTheme';
import { FLOATING_CHROME_MATERIAL } from '../../common/ImmersiveMaterial';
import {
  emptyVideoPlaybackSnapshot,
  isExternalAppUrl,
  isWebVideoPage,
  VIDEO_SOURCE_FILE,
  VideoItem,
  VideoPlaybackListener,
  VideoPlaybackPhase,
  VideoPlaybackSnapshot,
  videoSourceLabel,
  webPlaybackUrl
} from '../../model/VideoModels';
import { VideoPlaybackService } from '../../services/VideoPlaybackService';
import { ImmersiveAction } from '../components/ImmersiveAction';

const MOBILE_WEB_UA: string =
  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

interface VideoBox {
  width: number;
  height: number;
}

@Component
export struct VideoPlayerPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @Prop video: VideoItem = {
    id: '',
    title: '',
    sourceKind: '',
    source: '',
    createdAt: 0,
    durationMs: 0
  };
  onBack: () => void = () => {};

  @State private snapshot: VideoPlaybackSnapshot = emptyVideoPlaybackSnapshot();
  @State private controlsVisible: boolean = true;
  @State private landscape: boolean = false;
  @State private viewWidth: number = 360;
  @State private viewHeight: number = 640;
  @State private webFullScreen: boolean = false;
  @State private pageUrl: string = '';
  private surfaceController: XComponentController = new XComponentController();
  private webController: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private webReady: boolean = false;
  private fullScreenExit?: FullScreenExitHandler = undefined;
  private readonly onSnapshot: VideoPlaybackListener =
    (snapshot: VideoPlaybackSnapshot) => this.snapshot = snapshot;

  aboutToAppear(): void {
    try {
      webview.WebviewController.initializeWebEngine();
    } catch (_error) {
      // Already initialized.
    }
    this.pageUrl = webPlaybackUrl(this.video.source);
    if (!this.isWebPage()) {
      VideoPlaybackService.subscribe(this.onSnapshot);
    }
  }

  aboutToDisappear(): void {
    VideoPlaybackService.unsubscribe(this.onSnapshot);
    void VideoPlaybackService.release();
    void this.setLandscape(false);
  }

  private isWebPage(): boolean {
    return this.video.sourceKind !== VIDEO_SOURCE_FILE && isWebVideoPage(this.video.source);
  }

  private isPlaying(): boolean {
    return this.snapshot.phase === VideoPlaybackPhase.PLAYING;
  }

  private updateViewSize(area: Area): void {
    const width: number = typeof area.width === 'number' ? area.width :
      Number.parseFloat(`${area.width}`);
    const height: number = typeof area.height === 'number' ? area.height :
      Number.parseFloat(`${area.height}`);
    if (!Number.isNaN(width) && width > 0) {
      this.viewWidth = width;
    }
    if (!Number.isNaN(height) && height > 0) {
      this.viewHeight = height;
    }
  }

  private surfaceWidth(): number {
    return this.fittedBox().width;
  }

  private surfaceHeight(): number {
    return this.fittedBox().height;
  }

  private fittedBox(): VideoBox {
    const viewW: number = this.viewWidth > 0 ? this.viewWidth : 360;
    const viewH: number = this.viewHeight > 0 ? this.viewHeight : 640;
    const videoW: number = this.snapshot.videoWidth;
    const videoH: number = this.snapshot.videoHeight;
    if (videoW <= 0 || videoH <= 0) {
      return { width: viewW, height: viewH };
    }
    const ratio: number = videoW / videoH;
    const windowPortrait: boolean = viewW <= viewH;
    if (windowPortrait && ratio <= 1) {
      return { width: viewW, height: viewW / ratio };
    }
    const viewRatio: number = viewW / viewH;
    if (ratio >= viewRatio) {
      return { width: viewW, height: viewW / ratio };
    }
    return { width: viewH * ratio, height: viewH };
  }

  private async setLandscape(on: boolean): Promise<void> {
    this.landscape = on;
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      const hostWindow: window.Window = await window.getLastWindow(context);
      await hostWindow.setPreferredOrientation(on ?
        window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT);
    } catch (_error) {
      // Orientation stays as-is if the window manager rejects the request.
    }
  }

  private formatTime(valueMs: number): string {
    const totalSeconds: number = Math.max(0, Math.floor(valueMs / 1000));
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  build() {
    if (this.isWebPage()) {
      this.webPlayer()
    } else {
      this.avPlayer()
    }
  }

  private shouldBlockNavigation(url: string): boolean {
    return isExternalAppUrl(url);
  }

  private rewriteMainFrame(url: string): boolean {
    const next: string = webPlaybackUrl(url);
    if (next.length === 0 || next === this.pageUrl) {
      return false;
    }
    this.pageUrl = next;
    if (this.webReady) {
      try {
        this.webController.loadUrl(next);
      } catch (_error) {
        return false;
      }
    }
    return true;
  }

  private refuseNewWindow(event: OnWindowNewEvent): void {
    if (!this.shouldBlockNavigation(event.targetUrl)) {
      this.rewriteMainFrame(event.targetUrl);
    }
    event.handler.setWebController(this.popupController);
  }

  private recoverWeb(): void {
    if (!this.webReady || this.pageUrl.length === 0) {
      return;
    }
    try {
      this.webController.loadUrl(this.pageUrl);
    } catch (_error) {
      try {
        this.webController.refresh();
      } catch (_refreshError) {
        // Engine is gone; leaving the last frame is safer than crashing.
      }
    }
  }

  @Builder
  private webPlayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      Web({ src: this.pageUrl, controller: this.webController })
        .width('100%')
        .height('100%')
        .constraintSize({ minHeight: '100%' })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .mixedMode(MixedMode.All)
        .mediaPlayGestureAccess(false)
        .multiWindowAccess(false)
        .darkMode(WebDarkMode.Off)
        .backgroundColor(Color.Black)
        .onControllerAttached(() => {
          this.webReady = true;
          try {
            this.webController.setCustomUserAgent(MOBILE_WEB_UA);
          } catch (_error) {
            // Controller is attached; a missing UA just falls back to default.
          }
        })
        .onOverrideUrlLoading((request: WebResourceRequest) => {
          const url: string = request.getRequestUrl();
          if (this.shouldBlockNavigation(url)) {
            return true;
          }
          return request.isMainFrame() && this.rewriteMainFrame(url);
        })
        .onLoadIntercept((event: OnLoadInterceptEvent) => {
          return event.data.isMainFrame() &&
            this.shouldBlockNavigation(event.data.getRequestUrl());
        })
        .onWindowNew((event: OnWindowNewEvent) => {
          this.refuseNewWindow(event);
        })
        .onFullScreenEnter((event: FullScreenEnterEvent) => {
          this.fullScreenExit = event.handler;
          this.webFullScreen = true;
        })
        .onFullScreenExit(() => {
          this.webFullScreen = false;
          this.fullScreenExit = undefined;
        })
        .onRenderExited(() => {
          this.recoverWeb();
        })

      if (!this.webFullScreen) {
        Row() {
          ImmersiveAction({
            actionAccessibilityText: '关闭',
            icon: $r('sys.symbol.xmark'),
            actionSize: 40,
            onAction: () => this.onBack()
          })
        }
        .width('100%')
        .padding({
          left: 12,
          right: 12,
          top: 8 + statusBarInset(this.avoidAreas)
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  private avPlayer() {
    Stack() {
      XComponent({
        id: `video-${this.video.id}`,
        type: XComponentType.SURFACE,
        controller: this.surfaceController
      })
        .width(this.surfaceWidth())
        .height(this.surfaceHeight())
        .align(Alignment.Center)
        .onLoad(() => {
          VideoPlaybackService.attachSurface(this.surfaceController.getXComponentSurfaceId());
          VideoPlaybackService.play(this.video, true);
        })
        .onClick(() => this.controlsVisible = !this.controlsVisible)

      if (this.snapshot.phase === VideoPlaybackPhase.LOADING) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.immersive_light'))
          Text('正在解析视频')
            .fontSize(13)
            .fontColor($r('app.color.immersive_light'))
        }
        .align(Alignment.Center)
      }

      if (this.controlsVisible) {
        Row({ space: 10 }) {
          ImmersiveAction({
            actionAccessibilityText: '关闭',
            icon: $r('sys.symbol.xmark'),
            actionSize: 40,
            onAction: () => this.onBack()
          })
          if (!this.landscape) {
            Column({ space: 2 }) {
              Text(this.video.title)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(videoSourceLabel(this.video))
                .fontSize(11)
                .fontColor($r('sys.color.font_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .padding({
          left: 12,
          right: 16,
          top: 8 + statusBarInset(this.avoidAreas)
        })
        .align(Alignment.TopStart)
      }

      if (this.controlsVisible) {
        Column() {
          this.transport()
        }
        .width('100%')
        .position({ left: 0, bottom: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .clip(true)
    .onAreaChange((_oldArea: Area, newArea: Area) => this.updateViewSize(newArea))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  private transport() {
    Column({ space: 8 }) {
      if (this.snapshot.phase === VideoPlaybackPhase.ERROR) {
        Text(this.snapshot.error)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
      }

      Slider({
        value: this.snapshot.positionMs,
        min: 0,
        max: Math.max(1, this.snapshot.durationMs),
        step: 100,
        style: SliderStyle.InSet
      })
        .width('100%')
        .selectedColor($r('app.color.accent'))
        .blockColor($r('sys.color.icon_primary'))
        .trackColor($r('sys.color.font_secondary'))
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            VideoPlaybackService.seek(value);
          }
        })
        .systemMaterial(FLOATING_CHROME_MATERIAL)

      Row() {
        Text(this.formatTime(this.snapshot.positionMs))
          .fontSize(11)
          .fontColor($r('app.color.immersive_light'))
        Blank()
        Text(this.formatTime(this.snapshot.durationMs))
          .fontSize(11)
          .fontColor($r('app.color.immersive_light'))
      }
      .width('100%')

      Row() {
        Column()
          .width(48)
          .height(48)
        Blank()
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          if (this.snapshot.phase === VideoPlaybackPhase.LOADING) {
            LoadingProgress()
              .width(28)
              .height(28)
              .color($r('app.color.immersive_light'))
          } else {
            SymbolGlyph(this.isPlaying() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(30)
              .fontColor([$r('app.color.immersive_light')])
          }
        }
        .width(64)
        .height(64)
        .backgroundColor($r('app.color.accent'))
        .accessibilityText(this.isPlaying() ? '暂停' : '播放')
        .onClick(() => VideoPlaybackService.toggle())
        Blank()
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
            .fontSize(22)
            .fontColor([$r('app.color.immersive_light')])
        }
        .width(48)
        .height(48)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.landscape ? '竖屏播放' : '横屏播放')
        .onClick(() => void this.setLandscape(!this.landscape))
        .systemMaterial(FLOATING_CHROME_MATERIAL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: 22,
      right: 22,
      bottom: Math.max(10, systemGestureInset(this.avoidAreas))
    })
  }
}
