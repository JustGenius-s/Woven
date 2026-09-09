import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { FixedLayoutBook, FixedLayoutReaderParams, FIXED_BOOK_PAGE_COUNT } from '../services/FixedLayoutBook';
import { ReaderPreferences } from '../services/ReaderPreferences';
import { ImmersiveBackChrome } from '../views/components/ImmersiveBackChrome';

@Entry
@Component
struct FixedLayoutReaderPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  @State private pageIndex: number = 0;
  @State private positionDraft: number = 0;
  @State private loading: boolean = true;
  @State private errorMessage: string = '';
  @State private settingsOpen: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private directory: string = '';
  private attached: boolean = false;
  private disposed: boolean = false;
  private timeoutId: number = -1;

  aboutToAppear(): void {
    const params: FixedLayoutReaderParams | undefined = this.getUIContext().getRouter().getParams() as
      FixedLayoutReaderParams | undefined;
    this.pageIndex = this.clampPage(params?.pageIndex ??
      ReaderPreferences.progress(this.context(), 'yaramaika-fixed').resourceIndex);
    this.positionDraft = this.pageIndex;
    this.startTimeout();
    void this.prepare();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.clearTimeout();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private clampPage(page: number): number {
    return Number.isFinite(page) ? Math.max(0, Math.min(Math.round(page), FIXED_BOOK_PAGE_COUNT - 1)) : 0;
  }

  private clearTimeout(): void {
    if (this.timeoutId >= 0) { clearTimeout(this.timeoutId); this.timeoutId = -1; }
  }

  private startTimeout(): void {
    this.clearTimeout();
    this.timeoutId = setTimeout(() => this.fail('教材加载超时，请返回后重试。'), 30000);
  }

  private fail(message: string): void {
    if (this.disposed) { return; }
    this.clearTimeout();
    this.errorMessage = message;
    this.loading = false;
  }

  private async prepare(): Promise<void> {
    try {
      const directory: string = await FixedLayoutBook.prepare(this.context());
      if (this.disposed) { return; }
      this.directory = directory;
      this.loadPage();
    } catch (error) {
      this.fail(`无法准备教材：${(error as BusinessError).message ?? '未知错误'}`);
    }
  }

  private pageUrl(): string {
    return `file://${this.directory}/${FixedLayoutBook.pageName(this.pageIndex)}.html`;
  }

  private loadPage(): void {
    if (!this.attached || !this.directory || this.disposed || this.errorMessage) { return; }
    this.loading = true;
    this.startTimeout();
    try {
      this.controller.loadUrl(this.pageUrl());
    } catch (error) {
      this.fail(`无法打开教材：${(error as BusinessError).message ?? '未知错误'}`);
    }
  }

  private jump(page: number): void {
    this.settingsOpen = false;
    this.pageIndex = this.clampPage(page);
    this.positionDraft = this.pageIndex;
    this.loadPage();
  }

  private pageLoaded(url: string): void {
    if (this.disposed || url !== this.pageUrl() || this.errorMessage) { return; }
    this.clearTimeout();
    this.loading = false;
    ReaderPreferences.saveProgress(this.context(), 'yaramaika-fixed', {
      resourceIndex: this.pageIndex, domPos: '', pageOffset: 0
    });
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
          .onControllerAttached(() => { this.attached = true; this.loadPage(); })
          .onLoadIntercept((event: OnLoadInterceptEvent) => {
            const url: string = event.data.getRequestUrl();
            return url !== 'about:blank' && !url.startsWith(`file://${this.directory}/`);
          })
          .onPageEnd((event) => { if (event) { this.pageLoaded(event.url); } })
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
      Column({ space: 8 }) {
        Text(`第 ${this.pageIndex + 1} / ${FIXED_BOOK_PAGE_COUNT} 页 · 双指缩放查看细节`)
          .fontSize(12).fontColor('#6B7078')
        Row({ space: 10 }) {
          Button('上一页').layoutWeight(1).enabled(this.pageIndex > 0).onClick(() => this.jump(this.pageIndex - 1))
          Button('页码定位').layoutWeight(1).onClick(() => this.settingsOpen = true)
          Button('下一页').layoutWeight(1).enabled(this.pageIndex < FIXED_BOOK_PAGE_COUNT - 1)
            .onClick(() => this.jump(this.pageIndex + 1))
        }.width('100%')
      }.width('100%')
        .padding({ left: 16, right: 16, top: 12,
          bottom: Math.max(12, this.avoidAreas.navigationIndicator.bottomRect.height) })
        .enabled(!this.loading && !this.errorMessage)
    }.width('100%').height('100%').backgroundColor(Color.White)
  }

  @Builder
  private pageSettings() {
    Column({ space: 20 }) {
      Text('按教材原页显示日文和插图，可用双指放大查看。')
        .fontSize(14).lineHeight(22).fontColor($r('app.color.ink_muted'))
      Text(`第 ${this.positionDraft + 1} / ${FIXED_BOOK_PAGE_COUNT} 页`).fontSize(16)
      Slider({ value: this.positionDraft, min: 0, max: FIXED_BOOK_PAGE_COUNT - 1, step: 1 })
        .onChange((value: number) => { this.positionDraft = value; })
      Button('前往此页').width('100%').onClick(() => this.jump(this.positionDraft))
      Button('课堂用语 · 第 6 页').width('100%').onClick(() => this.jump(5))
    }.width('100%').padding(24)
  }

  build() {
    Stack() {
      ImmersiveBackChrome({
        title: 'やらまいか日本語', subtitle: '原版布局', paper: true,
        onBack: () => this.getUIContext().getRouter().back(),
        pageContent: (): void => { this.readerBody(); }
      })
    }.width('100%').height('100%')
      .bindSheet($$this.settingsOpen, this.pageSettings(), {
        height: SheetSize.MEDIUM, title: { title: '页码定位' }, showClose: true,
        backgroundColor: $r('app.color.surface_raised')
      })
  }
}
