import { common } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { bookParser, ReadPageComponent, readerCore } from '@kit.ReaderKit';
import { showImmersiveNotice } from '../common/ImmersiveNotice';
import { NativeReaderEdition, NativeReaderParams, NativeReaderTrial } from '../services/NativeReaderTrial';
import { READERKIT_TRIAL_ID, READERKIT_TRIAL_TITLES } from '../services/ReaderKitTrialContent';
import { READERKIT_ID, READERKIT_TITLES, READERKIT_CHAPTERS } from '../services/ReaderKitContent';
import { WEB_REFLOW_PROGRESS, WEB_REFLOW_CHAPTERS } from '../services/WebReflowContent';
import { ReaderPreferences, ReaderProgressSnapshot } from '../services/ReaderPreferences';
import { FixedLayoutReaderParams } from '../services/FixedLayoutBook';
import { ImmersiveBackChrome } from '../views/components/ImmersiveBackChrome';

// Do not import this page from Index/ExplorePage: its system HSP is unavailable
// on simulators. Navigation uses the lazy page route after a capability check.
@Entry
@Component
struct NativeReaderPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @State private edition: NativeReaderEdition = NativeReaderTrial.edition(READERKIT_ID);
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private resourceIndex: number = 0;
  @State private resourceCount: number = 0;
  @State private fontSize: number = 22;
  @State private lineHeight: number = 1.9;
  @State private flipMode: string = '1';
  @State private settingsOpen: boolean = false;
  @State private positionDraft: number = 0;

  private controller: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  private parser: bookParser.BookParserHandler | undefined = undefined;
  private initialized: boolean = false;
  private componentReady: boolean = false;
  private opening: boolean = false;
  private disposed: boolean = false;
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;
  private timeoutId: number = -1;
  private resizeTimer: number = -1;
  private progress: ReaderProgressSnapshot = { resourceIndex: 0, domPos: '', pageOffset: 0 };
  private pageCallback: (page: readerCore.PageDataInfo) => void =
    (page: readerCore.PageDataInfo) => this.handlePageShow(page);

  aboutToAppear(): void {
    const params: NativeReaderParams | undefined = this.getUIContext().getRouter().getParams() as
      NativeReaderParams | undefined;
    this.edition = NativeReaderTrial.edition(params?.editionId ?? READERKIT_ID);
    const style = ReaderPreferences.style(this.context());
    this.fontSize = Math.max(16, Math.min(style.fontSize, 32));
    this.lineHeight = Math.max(1.2, Math.min(style.lineHeight, 2.4));
    this.progress = ReaderPreferences.progress(this.context(), NativeReaderTrial.progressId(this.edition));
    if (this.edition.id === READERKIT_ID &&
      !ReaderPreferences.hasProgress(this.context(), NativeReaderTrial.progressId(this.edition)) &&
      ReaderPreferences.hasProgress(this.context(), WEB_REFLOW_PROGRESS)) {
      // Keep the last chapter when moving from ArkWeb. Its HTML anchor/scroll
      // offset is not a Reader Kit DOM position and must not be reused.
      const previous: ReaderProgressSnapshot = ReaderPreferences.progress(this.context(), WEB_REFLOW_PROGRESS);
      const chapterId: string = WEB_REFLOW_CHAPTERS[previous.resourceIndex] ?? '';
      const index: number = READERKIT_CHAPTERS.indexOf(chapterId);
      this.progress = { resourceIndex: Math.max(0, index), domPos: '', pageOffset: 0 };
    }
    this.timeoutId = setTimeout(() => {
      if (this.loading && !this.disposed) {
        this.fail('阅读器响应超时，请返回后重试，或换另一个排版版本。');
      }
    }, 45000);
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.clearTimeout();
    if (this.resizeTimer >= 0) {
      clearTimeout(this.resizeTimer);
    }
    this.release();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private clearTimeout(): void {
    if (this.timeoutId >= 0) {
      clearTimeout(this.timeoutId);
      this.timeoutId = -1;
    }
  }

  private release(): void {
    if (this.initialized) {
      this.controller.off('pageShow', this.pageCallback);
      this.controller.releaseBook();
      this.initialized = false;
    }
    this.parser = undefined;
  }

  private fail(message: string): void {
    if (!this.disposed) {
      this.errorMessage = message;
      this.loading = false;
      this.clearTimeout();
    }
  }

  private errorDetail(error: BusinessError): string {
    return `${error.code ?? ''} ${error.message ?? '未知错误'}`.trim();
  }

  private onComponentReady(error: BusinessError, controller: readerCore.ReaderComponentController): void {
    if (this.disposed) {
      return;
    }
    if (error !== undefined && error !== null && error.code !== 0) {
      this.fail(`阅读组件初始化失败：${this.errorDetail(error)}`);
      return;
    }
    this.controller = controller;
    this.componentReady = true;
    void this.openBook();
  }

  private updateViewport(area: Area): void {
    const width: number = Number.parseFloat(`${area.width}`);
    const height: number = Number.parseFloat(`${area.height}`);
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
      return;
    }
    this.viewportWidth = Math.round(this.getUIContext().vp2px(width));
    this.viewportHeight = Math.round(this.getUIContext().vp2px(height));
    // Pagination always uses the live reading surface, including resizing and
    // rotation. The conversion script's PDF canvas is unrelated to this size.
    if (!this.initialized) {
      void this.openBook();
    } else {
      if (this.resizeTimer >= 0) {
        clearTimeout(this.resizeTimer);
      }
      this.resizeTimer = setTimeout(() => this.applySettings(), 100);
    }
  }

  private pageConfig(): readerCore.ReaderSetting {
    const density: number = display.getDefaultDisplaySync().scaledDensity;
    return {
      fontName: '系统字体', fontPath: '', fontSize: this.fontSize, fontWeight: 400,
      fontColor: '#202124', lineHeight: this.lineHeight, nightMode: false,
      themeColor: '#FFFFFF', themeBgImg: '', flipMode: this.flipMode,
      scaledDensity: density > 0 ? density : 1,
      viewPortWidth: this.viewportWidth, viewPortHeight: this.viewportHeight
    };
  }

  private async openBook(): Promise<void> {
    if (!this.componentReady || this.opening || this.initialized || this.disposed ||
      this.errorMessage.length > 0 || this.viewportWidth <= 0 || this.viewportHeight <= 0) {
      return;
    }
    this.opening = true;
    try {
      const path: string = await NativeReaderTrial.materialize(this.context(), this.edition);
      if (this.disposed || this.errorMessage.length > 0) {
        return;
      }
      await this.controller.init(this.context());
      this.initialized = true;
      if (this.disposed || this.errorMessage.length > 0) {
        this.release();
        return;
      }
      const parser: bookParser.BookParserHandler = await bookParser.getDefaultHandler(path);
      if (this.disposed || this.errorMessage.length > 0) {
        this.release();
        return;
      }
      this.parser = parser;
      this.resourceCount = parser.getSpineList().length;
      if (this.resourceCount === 0) {
        throw new Error('教材没有可阅读的内容');
      }
      this.controller.registerBookParser(parser);
      this.controller.on('pageShow', this.pageCallback);
      // BookParser resolves the EPUB's own images, styles and fonts. The
      // resourceRequest hook is only needed for additional custom resources.
      this.controller.setPageConfig(this.pageConfig());
      const target: number = this.safeIndex(this.progress.resourceIndex);
      this.resourceIndex = target;
      await this.controller.startPlay(target, target === this.progress.resourceIndex ? this.progress.domPos : '');
      // Only PAGE_ON_SHOW dismisses the loading screen: startPlay resolving does
      // not guarantee the native surface has drawn its first page.
    } catch (error) {
      this.fail(`无法打开${this.edition.label}：${this.errorDetail(error as BusinessError)}`);
      this.release();
    } finally {
      this.opening = false;
    }
  }

  private safeIndex(index: number): number {
    return Number.isFinite(index) ? Math.max(0, Math.min(Math.round(index), this.resourceCount - 1)) : 0;
  }

  private handlePageShow(page: readerCore.PageDataInfo): void {
    if (this.disposed || this.errorMessage.length > 0) {
      return;
    }
    if (page.state === readerCore.PageState.OPEN_BOOK_FAIL) {
      this.fail('Reader Kit 无法排版当前内容，请返回后尝试另一个版本。');
    } else if (page.state === readerCore.PageState.PAGE_ON_SHOW) {
      this.loading = false;
      this.clearTimeout();
      this.resourceIndex = this.safeIndex(page.resourceIndex);
      this.positionDraft = this.resourceIndex;
      this.progress = {
        resourceIndex: this.resourceIndex, domPos: page.startDomPos, pageOffset: page.pageOffset
      };
      ReaderPreferences.saveProgress(this.context(), NativeReaderTrial.progressId(this.edition), this.progress);
    }
  }

  private applySettings(): void {
    if (!this.initialized || this.disposed || this.errorMessage.length > 0) {
      return;
    }
    try {
      this.controller.setPageConfig(this.pageConfig());
      const style = ReaderPreferences.style(this.context());
      style.fontSize = this.fontSize;
      style.lineHeight = this.lineHeight;
      ReaderPreferences.saveStyle(this.context(), style);
    } catch (error) {
      showImmersiveNotice(this.getUIContext(), '阅读设置未生效', this.errorDetail(error as BusinessError));
    }
  }

  private flip(next: boolean): void {
    try {
      this.controller.flipPage(next);
    } catch (error) {
      showImmersiveNotice(this.getUIContext(), '无法翻页', this.errorDetail(error as BusinessError));
    }
  }

  private async jump(index: number): Promise<void> {
    this.settingsOpen = false;
    try {
      const target: number = this.safeIndex(index);
      this.resourceIndex = target;
      await this.controller.startPlay(target, '');
    } catch (error) {
      showImmersiveNotice(this.getUIContext(), '无法跳转', this.errorDetail(error as BusinessError));
    }
  }

  private openOriginalPage(): void {
    this.settingsOpen = false;
    const params: FixedLayoutReaderParams = {
      pageIndex: NativeReaderTrial.sourcePageIndex(this.edition, this.resourceIndex)
    };
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FixedLayoutReaderPage', params: params })
      .catch(() => showImmersiveNotice(this.getUIContext(), '暂时无法打开原版', '请返回后重试。'));
  }

  private bottomInset(): number {
    return Math.max(12, this.avoidAreas.navigationIndicator.bottomRect.height,
      this.avoidAreas.cutout.bottomRect.height);
  }

  @Builder
  private readerBody() {
    Column() {
      Stack() {
        ReadPageComponent({
          controller: this.controller,
          readerCallback: (error: BusinessError, controller: readerCore.ReaderComponentController) =>
            this.onComponentReady(error, controller)
        })
          .width('100%')
          .height('100%')
        if (this.loading || this.errorMessage.length > 0) {
          Column({ space: 16 }) {
            if (this.loading) {
              LoadingProgress().width(32).height(32).color($r('app.color.accent'))
              Text('正在准备教材…').fontSize(16).fontColor('#6B7078')
            } else {
              Text('暂时无法阅读').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#202124')
              Text(this.errorMessage).fontSize(14).lineHeight(22).fontColor('#6B7078')
                .textAlign(TextAlign.Center)
              Button('返回选择版本').onClick(() => this.getUIContext().getRouter().back())
            }
          }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
          .padding(28).backgroundColor(Color.White)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)
      .onAreaChange((_old: Area, area: Area) => this.updateViewport(area))
      Column({ space: 8 }) {
        Row({ space: 10 }) {
          Button('上一页').onClick(() => this.flip(false)).layoutWeight(1)
          Button('阅读设置').onClick(() => this.settingsOpen = true).layoutWeight(1)
          Button('下一页').onClick(() => this.flip(true)).layoutWeight(1)
        }.width('100%')
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: this.bottomInset() })
      .enabled(!this.loading && this.errorMessage.length === 0)
    }
    .width('100%').height('100%').backgroundColor(Color.White)
  }

  @Builder
  private readerSettings() {
    Scroll() {
      Column({ space: 20 }) {
        if (this.edition.reflow) {
          if (this.edition.id === READERKIT_TRIAL_ID || this.edition.id === READERKIT_ID) {
            Text('正文和句型框可调字号；图中的标注随图片整体缩放。')
              .fontSize(13).lineHeight(20).fontColor($r('app.color.ink_muted')).width('100%')
          }
          Column({ space: 8 }) {
            Text(`字号  ${this.fontSize}`).width('100%').fontSize(15)
            Slider({ value: this.fontSize, min: 16, max: 32, step: 1 })
              .onChange((value: number, mode: SliderChangeMode) => {
                this.fontSize = value;
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  this.applySettings();
                }
              })
            Text(`行距  ${this.lineHeight.toFixed(1)} 倍`).width('100%').fontSize(15)
            Slider({ value: this.lineHeight, min: 1.2, max: 2.4, step: 0.1 })
              .onChange((value: number, mode: SliderChangeMode) => {
                this.lineHeight = value;
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  this.applySettings();
                }
              })
          }
          .width('100%')
        }
        Column({ space: 10 }) {
          Text('翻页方式').width('100%').fontSize(15)
          Row({ space: 12 }) {
            Button('横滑翻页').layoutWeight(1)
              .backgroundColor(this.flipMode === '1' ? $r('app.color.accent') : $r('app.color.immersive_plane'))
              .fontColor(this.flipMode === '1' ? Color.White : $r('app.color.ink'))
              .onClick(() => { this.flipMode = '1'; this.applySettings(); })
            Button('仿真翻页').layoutWeight(1)
              .backgroundColor(this.flipMode === '0' ? $r('app.color.accent') : $r('app.color.immersive_plane'))
              .fontColor(this.flipMode === '0' ? Color.White : $r('app.color.ink'))
              .onClick(() => { this.flipMode = '0'; this.applySettings(); })
          }.width('100%')
        }.width('100%')
        Column({ space: 10 }) {
          Text('章节').width('100%').fontSize(15)
          Text(NativeReaderTrial.chapterTitle(this.edition, this.positionDraft))
            .width('100%').fontSize(12).fontColor($r('app.color.ink_muted'))
          Slider({ value: this.positionDraft, min: 0, max: Math.max(1, this.resourceCount - 1), step: 1 })
            .onChange((value: number, mode: SliderChangeMode) => {
              this.positionDraft = value;
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                void this.jump(value);
              }
            })
          if (this.edition.id === READERKIT_TRIAL_ID) {
            ForEach(READERKIT_TRIAL_TITLES, (title: string, index: number) => {
              Button(title).width('100%')
                .onClick(() => { void this.jump(index); })
            }, (title: string) => title)
          } else if (this.edition.id === READERKIT_ID) {
            ForEach(READERKIT_TITLES, (title: string, index: number) => {
              Button(title).width('100%').fontSize(14)
                .onClick(() => { void this.jump(index); })
            }, (title: string) => title)
          } else {
            Button('课堂用语').width('100%')
              .onClick(() => { void this.jump(this.edition.classroomIndex); })
          }
          Button('本章原版').width('100%')
            .onClick(() => this.openOriginalPage())
        }.width('100%')
      }
      .width('100%').padding({ left: 24, right: 24, top: 16, bottom: 36 })
      .alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      ImmersiveBackChrome({
        title: 'やらまいか日本語',
        subtitle: this.edition.label,
        paper: true,
        onBack: () => this.getUIContext().getRouter().back(),
        pageContent: (): void => { this.readerBody(); }
      })
    }
      .width('100%')
      .height('100%')
      .bindSheet($$this.settingsOpen, this.readerSettings(), {
        height: SheetSize.LARGE,
        title: { title: '阅读设置' },
        showClose: true,
        backgroundColor: $r('app.color.surface_raised')
      })
  }
}
