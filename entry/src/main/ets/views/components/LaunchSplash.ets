import { displaySync } from '@kit.ArkGraphics2D';
import { FujiSplashScene, SPLASH_DURATION, SPLASH_TITLE_HIDE_AT, SPLASH_WHISTLE_AT } from './FujiSplashScene';
import { SplashSoundService } from '../../services/SplashSoundService';

/**
 * The painted landscape and approaching train fade to the live app.
 */
@Component
export struct LaunchSplash {
  onFinished: () => void = () => {};

  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private scene: FujiSplashScene = new FujiSplashScene();
  private sound: SplashSoundService = new SplashSoundService();
  private backdrop: ImageBitmap | undefined = undefined;
  private landscape: ImageBitmap | undefined = undefined;
  private train: ImageBitmap | undefined = undefined;
  private trainFront: ImageBitmap | undefined = undefined;
  private treeFrame: ImageBitmap | undefined = undefined;
  private trees: ImageBitmap | undefined = undefined;
  private frames: displaySync.DisplaySync | undefined = undefined;
  private startedAt: number = -1;
  private elapsed: number = 0;
  private fallbackTimer: number = -1;
  private finished: boolean = false;
  private disposed: boolean = false;
  @State private titleVisible: boolean = false;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      void this.sound.prepare(context);
    }
    // Also release the splash if the first canvas frame never arrives.
    this.fallbackTimer = setTimeout(() => this.finish(), SPLASH_DURATION + 700);
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.release();
  }

  private release(): void {
    void this.sound.release();
    if (this.fallbackTimer >= 0) {
      clearTimeout(this.fallbackTimer);
      this.fallbackTimer = -1;
    }
    if (this.frames !== undefined) {
      this.frames.stop();
      this.frames.off('frame');
      this.frames = undefined;
    }
    this.backdrop?.close();
    this.backdrop = undefined;
    this.landscape?.close();
    this.landscape = undefined;
    this.train?.close();
    this.train = undefined;
    this.trainFront?.close();
    this.trainFront = undefined;
    this.treeFrame?.close();
    this.treeFrame = undefined;
    this.trees?.close();
    this.trees = undefined;
  }

  private finish(): void {
    if (this.finished || this.disposed) {
      return;
    }
    this.finished = true;
    this.release();
    this.onFinished();
  }

  private prepareBackdrop(): void {
    const width: number = this.context.width;
    const height: number = this.context.height;
    if (width <= 0 || height <= 0 || this.finished || this.disposed || this.landscape === undefined) {
      return;
    }
    this.backdrop?.close();
    const buffer: OffscreenCanvasRenderingContext2D =
      new OffscreenCanvasRenderingContext2D(width, height, new RenderingContextSettings(true));
    this.scene.paintBackdrop(buffer, this.landscape, width, height);
    this.backdrop = buffer.transferToImageBitmap();
    if (this.trees === undefined && this.treeFrame !== undefined) {
      const border: OffscreenCanvasRenderingContext2D = new OffscreenCanvasRenderingContext2D(
        this.treeFrame.width, this.treeFrame.height, new RenderingContextSettings(true));
      this.scene.paintCurtainLayer(border, this.treeFrame, this.treeFrame.width, this.treeFrame.height);
      this.trees = border.transferToImageBitmap();
      this.treeFrame.close();
      this.treeFrame = undefined;
    }
    this.paint();
  }

  private paint(): void {
    if (this.backdrop !== undefined && this.train !== undefined &&
      this.trainFront !== undefined && this.trees !== undefined) {
      this.scene.paintFrame(this.context, this.backdrop, this.train, this.trainFront, this.trees,
        this.context.width, this.context.height, this.elapsed);
    }
  }

  private start(): void {
    if (this.frames !== undefined || this.finished || this.disposed) {
      return;
    }
    try {
      this.landscape = new ImageBitmap($r('app.media.splash_fuji_painted'));
      this.train = new ImageBitmap($r('app.media.splash_train_painted'));
      this.trainFront = new ImageBitmap($r('app.media.music_morning_train'));
      this.treeFrame = new ImageBitmap($r('app.media.splash_sakura_frame'));
      if (this.landscape.width <= 0 || this.train.width <= 0 ||
        this.trainFront.width <= 0 || this.treeFrame.width <= 0) {
        this.finish();
        return;
      }
      this.prepareBackdrop();
    } catch {
      this.finish();
      return;
    }
    this.frames = displaySync.create();
    this.frames.setExpectedFrameRateRange({ min: 30, max: 60, expected: 60 });
    this.frames.on('frame', (info: displaySync.IntervalInfo) => {
      if (this.disposed || this.finished) {
        return;
      }
      if (this.startedAt < 0) {
        this.startedAt = info.timestamp;
      }
      // Vsync timestamps are monotonic nanoseconds. Never advance by frame count.
      this.elapsed = (info.timestamp - this.startedAt) / 1000000;
      this.sound.update(this.elapsed - SPLASH_WHISTLE_AT);
      const showTitle: boolean = this.elapsed >= 160 && this.elapsed < SPLASH_TITLE_HIDE_AT;
      if (showTitle !== this.titleVisible) {
        this.getUIContext().animateTo({ duration: showTitle ? 650 : 280, curve: Curve.EaseInOut }, () => {
          this.titleVisible = showTitle;
        });
      }
      this.paint();
      if (this.elapsed >= SPLASH_DURATION) {
        this.finish();
      }
    });
    this.frames.start();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onReady(() => this.start())
        .onSizeChange(() => this.prepareBackdrop())
        .accessibilityLevel('no')

      Column({ space: 10 }) {
        Text('Woven')
          .fontSize(38)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(0.3)
          .fontColor('#FFFFFF')
        Text('让日语，融入日常')
          .fontSize(13)
          .letterSpacing(2)
          .fontColor('#D9E9F5')
      }
      .width('100%')
      .position({ x: 0, y: '79%' })
      .opacity(this.titleVisible ? 1 : 0)
      .translate({ y: this.titleVisible ? 0 : 6 })
      .accessibilityLevel('no')
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.Block)
    .accessibilityGroup(true)
    .accessibilityText('Woven，日语学习，正在进入')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
