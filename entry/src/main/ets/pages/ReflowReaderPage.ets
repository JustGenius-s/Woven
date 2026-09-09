import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { showImmersiveNotice } from '../common/ImmersiveNotice';
import { FixedLayoutReaderParams } from '../services/FixedLayoutBook';
import { NativeReaderTrial } from '../services/NativeReaderTrial';
import { ReaderPreferences, ReaderProgressSnapshot } from '../services/ReaderPreferences';
import { ReflowWebBook } from '../services/ReflowWebBook';
import { WEB_REFLOW_CHAPTERS, WEB_REFLOW_PROGRESS, WEB_REFLOW_SOURCE_PAGES,
  WEB_REFLOW_TITLES } from '../services/WebReflowContent';
import { ImmersiveBackChrome } from '../views/components/ImmersiveBackChrome';

class ReflowReaderBridge {
  onReady: (chapter: string) => void = (_chapter: string) => {};
  onReport: (chapter: string, anchor: string, offset: number, start: boolean, end: boolean) => void =
    (_chapter: string, _anchor: string, _offset: number, _start: boolean, _end: boolean) => {};
  onTurn: (chapter: string, direction: number) => void = (_chapter: string, _direction: number) => {};
  onJump: (chapter: string, anchor: string) => void = (_chapter: string, _anchor: string) => {};

  ready(chapter: string): void { this.onReady(chapter); }
  report(chapter: string, anchor: string, offset: number, start: boolean, end: boolean): void {
    this.onReport(chapter, anchor, offset, start, end);
  }
  turn(chapter: string, direction: number): void { this.onTurn(chapter, direction); }
  jump(chapter: string, anchor: string): void { this.onJump(chapter, anchor); }
}

interface ReflowWebSettings {
  fontSize: number;
  lineHeight: number;
  anchor: string;
  offset: number;
}

@Entry
@Component
struct ReflowReaderPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @State private chapterIndex: number = 0;
  @State private positionDraft: number = 0;
  @State private fontSize: number = 22;
  @State private lineHeight: number = 1.7;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private settingsOpen: boolean = false;
  @State private atStart: boolean = true;
  @State private atEnd: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: ReflowReaderBridge = new ReflowReaderBridge();
  private directory: string = '';
  private attached: boolean = false;
  private disposed: boolean = false;
  private timeoutId: number = -1;
  private progress: ReaderProgressSnapshot = { resourceIndex: 0, domPos: '', pageOffset: 0 };

  aboutToAppear(): void {
    const style = ReaderPreferences.style(this.context());
    this.fontSize = Math.max(16, Math.min(style.fontSize, 40));
    this.lineHeight = ReaderPreferences.hasStyle(this.context()) ? Math.max(1.2, Math.min(style.lineHeight, 2.4)) : 1.7;
    if (ReaderPreferences.hasProgress(this.context(), WEB_REFLOW_PROGRESS)) {
      this.progress = ReaderPreferences.progress(this.context(), WEB_REFLOW_PROGRESS);
    } else if (ReaderPreferences.hasProgress(this.context(), 'yaramaika-reflow-web-v1')) {
      const previous = ReaderPreferences.progress(this.context(), 'yaramaika-reflow-web-v1');
      this.progress = { resourceIndex: previous.resourceIndex, domPos: '', pageOffset: 0 };
    } else {
      // Reader Kit DOM offsets do not describe this HTML. Carry over the
      // chapter, while the new renderer starts its own stable element anchors.
      const previous = ReaderPreferences.progress(this.context(),
        NativeReaderTrial.progressId(NativeReaderTrial.edition('yaramaika-reflow')));
      this.progress = { resourceIndex: previous.resourceIndex, domPos: '', pageOffset: 0 };
    }
    this.chapterIndex = this.clampChapter(this.progress.resourceIndex);
    this.positionDraft = this.chapterIndex;
    this.bridge.onReady = (chapter: string) => this.onReady(chapter);
    this.bridge.onReport = (chapter: string, anchor: string, offset: number, start: boolean, end: boolean) =>
      this.onProgress(chapter, anchor, offset, start, end);
    this.bridge.onTurn = (chapter: string, direction: number) => {
      if (chapter === WEB_REFLOW_CHAPTERS[this.chapterIndex] && !this.loading) {
        this.jump(this.chapterIndex + (direction > 0 ? 1 : -1), direction > 0 ? '' : 'end');
      }
    };
    this.bridge.onJump = (chapter: string, anchor: string) => {
      const index: number = WEB_REFLOW_CHAPTERS.indexOf(chapter);
      if (index >= 0) { this.jump(index, anchor); }
    };
    this.startTimeout();
    void this.prepare();
  }

  aboutToDisappear(): void {
    ReaderPreferences.saveProgress(this.context(), WEB_REFLOW_PROGRESS, this.progress);
    this.disposed = true;
    this.clearTimeout();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private clampChapter(value: number): number {
    return Number.isFinite(value) ? Math.max(0, Math.min(WEB_REFLOW_CHAPTERS.length - 1, Math.round(value))) : 0;
  }

  private clearTimeout(): void {
    if (this.timeoutId >= 0) { clearTimeout(this.timeoutId); this.timeoutId = -1; }
  }

  private startTimeout(): void {
    this.clearTimeout();
    this.timeoutId = setTimeout(() => this.fail('教材加载超时，请返回后重试。'), 45000);
  }

  private fail(message: string): void {
    if (this.disposed) { return; }
    this.clearTimeout();
    this.errorMessage = message;
    this.loading = false;
  }

  private async prepare(): Promise<void> {
    try {
      const directory: string = await ReflowWebBook.prepare(this.context());
      if (this.disposed) { return; }
      this.directory = directory;
      this.loadChapter();
    } catch (error) {
      this.fail(`无法准备教材：${(error as BusinessError).message ?? '未知错误'}`);
    }
  }

  private pageUrl(): string {
    return `file://${this.directory}/${WEB_REFLOW_CHAPTERS[this.chapterIndex]}.html`;
  }

  private loadChapter(): void {
    if (!this.attached || !this.directory || this.disposed || this.errorMessage) { return; }
    this.loading = true;
    this.startTimeout();
    try { this.controller.loadUrl(this.pageUrl()); }
    catch (error) { this.fail(`无法打开教材：${(error as BusinessError).message ?? '未知错误'}`); }
  }

  private pageEnded(url: string): void {
    if (this.disposed || url !== this.pageUrl() || this.errorMessage) { return; }
    const settings: ReflowWebSettings = {
      fontSize: this.fontSize, lineHeight: this.lineHeight,
      anchor: this.progress.domPos, offset: this.progress.pageOffset
    };
    this.controller.runJavaScript(`void window.WovenReader.initialize(${JSON.stringify(settings)})`)
      .catch((error: BusinessError) => this.fail(`阅读排版初始化失败：${error.message}`));
  }

  private onReady(chapter: string): void {
    if (this.disposed || chapter !== WEB_REFLOW_CHAPTERS[this.chapterIndex] || this.errorMessage) { return; }
    this.clearTimeout();
    this.loading = false;
  }

  private onProgress(chapter: string, anchor: string, offset: number, start: boolean, end: boolean): void {
    // The previous document may report pagehide while a same-chapter shortcut
    // is loading. It must not overwrite the new document's requested anchor.
    if (this.disposed || this.loading || chapter !== WEB_REFLOW_CHAPTERS[this.chapterIndex] || !Number.isFinite(offset) ||
      typeof anchor !== 'string' || anchor.length > 200) { return; }
    this.atStart = start;
    this.atEnd = end;
    this.progress = { resourceIndex: this.chapterIndex, domPos: anchor, pageOffset: offset };
    ReaderPreferences.saveProgress(this.context(), WEB_REFLOW_PROGRESS, this.progress);
  }

  private jump(index: number, anchor: string = ''): void {
    if (this.disposed || index < 0 || index >= WEB_REFLOW_CHAPTERS.length) { return; }
    this.settingsOpen = false;
    this.chapterIndex = this.clampChapter(index);
    this.positionDraft = this.chapterIndex;
    this.progress = { resourceIndex: this.chapterIndex, domPos: anchor, pageOffset: 0 };
    this.atStart = anchor !== 'end';
    this.atEnd = false;
    this.loadChapter();
  }

  private applySettings(): void {
    const current = ReaderPreferences.style(this.context());
    ReaderPreferences.saveStyle(this.context(), {
      fontSize: this.fontSize, lineHeight: this.lineHeight,
      flipMode: current.flipMode, themeIndex: current.themeIndex
    });
    const settings: ReflowWebSettings = {
      fontSize: this.fontSize, lineHeight: this.lineHeight, anchor: '', offset: 0
    };
    this.controller.runJavaScript(`void window.WovenReader.settings(${JSON.stringify(settings)})`)
      .catch(() => showImmersiveNotice(this.getUIContext(), '阅读设置未生效', '请稍后重试。'));
  }

  private flip(next: boolean): void {
    this.controller.runJavaScript(`window.WovenReader.flip(${next ? 1 : -1})`)
      .catch(() => showImmersiveNotice(this.getUIContext(), '无法翻页', '请稍后重试。'));
  }

  private openOriginal(): void {
    this.settingsOpen = false;
    const params: FixedLayoutReaderParams = { pageIndex: WEB_REFLOW_SOURCE_PAGES[this.chapterIndex] };
    this.getUIContext().getRouter().pushUrl({ url: 'pages/FixedLayoutReaderPage', params: params })
      .catch(() => showImmersiveNotice(this.getUIContext(), '暂时无法打开原版', '请返回后重试。'));
  }

  @Builder
  private readerBody() {
    Column() {
      Stack() {
        Web({ src: 'about:blank', controller: this.controller })
          .width('100%').height('100%')
          .fileAccess(true).imageAccess(true).javaScriptAccess(true)
          .domStorageAccess(false).multiWindowAccess(false).zoomAccess(true)
          .darkMode(WebDarkMode.Off).backgroundColor(Color.White)
          .javaScriptProxy({ object: this.bridge, name: 'ReaderHost', methodList: ['ready', 'report', 'turn', 'jump'],
            controller: this.controller })
          .onControllerAttached(() => { this.attached = true; this.loadChapter(); })
          .onLoadIntercept((event: OnLoadInterceptEvent) => {
            const url: string = event.data.getRequestUrl();
            return url !== 'about:blank' && !url.startsWith(`file://${this.directory}/`);
          })
          .onPageEnd((event) => { if (event) { this.pageEnded(event.url); } })
          .onErrorReceive((event) => {
            if (event && event.request.isMainFrame() && event.request.getRequestUrl() === this.pageUrl()) {
              this.fail('教材页面加载失败，请返回后重试。');
            }
          })
          .onRenderExited(() => this.fail('教材显示已中断，请返回后重试。'))
        if (this.loading || this.errorMessage) {
          Column({ space: 16 }) {
            if (this.loading) {
              LoadingProgress().width(32).height(32)
              Text('正在准备教材…').fontSize(16).fontColor('#6B7078')
            } else {
              Text(this.errorMessage).fontSize(15).fontColor('#202124').textAlign(TextAlign.Center)
              Button('返回').onClick(() => this.getUIContext().getRouter().back())
            }
          }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(28).backgroundColor(Color.White)
        }
      }.width('100%').layoutWeight(1).clip(true)
      Row({ space: 10 }) {
        Button('上一页').layoutWeight(1).enabled(!this.atStart || this.chapterIndex > 0).onClick(() => this.flip(false))
        Button('阅读设置').layoutWeight(1).onClick(() => this.settingsOpen = true)
        Button('下一页').layoutWeight(1).enabled(!this.atEnd || this.chapterIndex < WEB_REFLOW_CHAPTERS.length - 1)
          .onClick(() => this.flip(true))
      }.width('100%')
        .padding({ left: 16, right: 16, top: 12,
          bottom: Math.max(12, this.avoidAreas.navigationIndicator.bottomRect.height, this.avoidAreas.cutout.bottomRect.height) })
        .enabled(!this.loading && !this.errorMessage)
    }.width('100%').height('100%').backgroundColor(Color.White)
  }

  @Builder
  private readerSettings() {
    Scroll() {
      Column({ space: 20 }) {
        Text(`字号  ${this.fontSize}`).width('100%').fontSize(15)
        Slider({ value: this.fontSize, min: 16, max: 40, step: 1 })
          .onChange((value: number, mode: SliderChangeMode) => {
            this.fontSize = value;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.applySettings(); }
          })
        Text(`行距  ${this.lineHeight.toFixed(1)} 倍`).width('100%').fontSize(15)
        Slider({ value: this.lineHeight, min: 1.2, max: 2.4, step: 0.1 })
          .onChange((value: number, mode: SliderChangeMode) => {
            this.lineHeight = value;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.applySettings(); }
          })
        Text('上下滑动阅读，也可用下方按钮翻动。').width('100%').fontSize(13).fontColor($r('app.color.ink_muted'))
        Text(WEB_REFLOW_TITLES[this.positionDraft]).width('100%').fontSize(15)
        Slider({ value: this.positionDraft, min: 0, max: WEB_REFLOW_CHAPTERS.length - 1, step: 1 })
          .onChange((value: number, mode: SliderChangeMode) => {
            this.positionDraft = value;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.jump(value); }
          })
        Button('课堂用语').width('100%').onClick(() => this.jump(WEB_REFLOW_CHAPTERS.indexOf('classroom')))
        Button('自己紹介 · 会話 1').width('100%')
          .onClick(() => this.jump(WEB_REFLOW_CHAPTERS.indexOf('introduction'), 'source-page-11'))
        Button('街区地图').width('100%')
          .onClick(() => this.jump(WEB_REFLOW_CHAPTERS.indexOf('places'), 'map-4'))
        Button('本章原版').width('100%').onClick(() => this.openOriginal())
      }.width('100%').padding({ left: 24, right: 24, top: 16, bottom: 36 })
        .alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      ImmersiveBackChrome({
        title: 'やらまいか日本語', subtitle: '可重排版', paper: true,
        onBack: () => this.getUIContext().getRouter().back(),
        pageContent: (): void => { this.readerBody(); }
      })
    }.width('100%').height('100%')
      .bindSheet($$this.settingsOpen, this.readerSettings(), {
        height: SheetSize.LARGE, title: { title: '阅读设置' }, showClose: true,
        backgroundColor: $r('app.color.surface_raised')
      })
  }
}
