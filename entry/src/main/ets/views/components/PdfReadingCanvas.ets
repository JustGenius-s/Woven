import { BusinessError } from '@kit.BasicServicesKit';
import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
import { ReadingAudioRect } from '../../model/ContentModels';

const HIGHLIGHT_COLOR: number = 0x66F4C430;

@Component
export struct PdfReadingCanvas {
  pdfPath: string = '';
  startPage: number = 0;
  @Prop @Watch('applyViewStyle') flipMode: number = 0;
  @Prop @Watch('applyViewStyle') dualPage: boolean = false;
  @Prop @Watch('onJumpPage') jumpPage: number = 0;
  @Prop @Watch('onHighlightChange') highlightKey: string = '';
  @Prop highlightPage: number = 0;
  @Prop highlightRects: ReadingAudioRect[] = [];
  onPageChanged: (index: number) => void = (_index: number) => {};
  onFailed: (reason: string) => void = (_reason: string) => {};

  private controller: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  private loaded: boolean = false;
  @State private failed: boolean = false;
  @State private failReason: string = '';

  aboutToAppear(): void {
    void this.openDocument();
  }

  aboutToDisappear(): void {
    this.closeDocument();
  }

  private parseResultLabel(result: pdfService.ParseResult): string {
    switch (result) {
      case pdfService.ParseResult.PARSE_SUCCESS:
        return 'PARSE_SUCCESS';
      case pdfService.ParseResult.PARSE_ERROR_FILE:
        return 'PARSE_ERROR_FILE';
      case pdfService.ParseResult.PARSE_ERROR_FORMAT:
        return 'PARSE_ERROR_FORMAT';
      case pdfService.ParseResult.PARSE_ERROR_PASSWORD:
        return 'PARSE_ERROR_PASSWORD';
      default:
        return `ParseResult(${result})`;
    }
  }

  private async openDocument(): Promise<void> {
    if (this.pdfPath.length === 0) {
      this.markFailed('PDF 路径为空');
      return;
    }
    if (!canIUse('SystemCapability.OfficeService.PDFService.Core')) {
      this.markFailed('设备不支持 PDFService');
      return;
    }
    try {
      this.controller.registerPageCountChangedListener((_pageCount: number) => {});
      this.controller.registerPageChangedListener((pageIndex: number) => {
        this.onPageChanged(pageIndex);
      });
      // Always open at page 0 first. A saved progress index past the real page
      // count throws BusinessError 1011302001 (invalid page number).
      const result: pdfService.ParseResult =
        await this.controller.loadDocument(this.pdfPath, '', 0);
      if (result !== pdfService.ParseResult.PARSE_SUCCESS) {
        this.markFailed(this.parseResultLabel(result));
        return;
      }
      this.loaded = true;
      this.applyViewStyle();
      const target: number = Math.max(0, this.startPage);
      if (target > 0) {
        this.controller.goToPage(target);
      }
      this.applyHighlight();
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      const detail: string = err !== undefined && err.message !== undefined ?
        `${err.code ?? ''} ${err.message}`.trim() : `${error}`;
      this.markFailed(`loadDocument: ${detail}`);
    }
  }

  private closeDocument(): void {
    if (!this.loaded) {
      return;
    }
    this.controller.releaseDocument();
    this.loaded = false;
  }

  private markFailed(reason: string = ''): void {
    this.failed = true;
    this.failReason = reason;
    this.onFailed(reason);
  }

  applyViewStyle(_propertyName?: string): void {
    if (!this.loaded) {
      return;
    }
    this.controller.setPageFit(pdfService.PageFit.FIT_PAGE);
    this.controller.setPageContinuous(this.flipMode === 1);
    this.controller.setPageLayout(this.dualPage ?
      pdfService.PageLayout.LAYOUT_DOUBLE : pdfService.PageLayout.LAYOUT_SINGLE);
    this.controller.setDisplayDirection(this.flipMode === 1 ?
      pdfViewManager.DisplayDirection.VERTICAL :
      pdfViewManager.DisplayDirection.HORIZONTAL);
    this.controller.setPageSpacing(0, 0);
  }

  onJumpPage(_propertyName?: string): void {
    if (this.loaded) {
      this.controller.goToPage(this.jumpPage);
    }
  }

  onHighlightChange(_propertyName?: string): void {
    this.applyHighlight();
  }

  private applyHighlight(): void {
    if (!this.loaded) {
      return;
    }
    const pdfRects: pdfService.PdfRect[] = [];
    for (let index: number = 0; index < this.highlightRects.length; index++) {
      const box: ReadingAudioRect = this.highlightRects[index];
      const rect: pdfService.PdfRect = new pdfService.PdfRect();
      rect.left = box.left;
      rect.top = box.top;
      rect.right = box.right;
      rect.bottom = box.bottom;
      pdfRects.push(rect);
    }
    const pageRects: pdfViewManager.PageRects[] = [];
    if (pdfRects.length > 0) {
      pageRects.push(new pdfViewManager.PageRects(this.highlightPage, pdfRects));
    }
    this.controller.setHighlightRects(pageRects, HIGHLIGHT_COLOR);
  }

  build() {
    if (this.failed) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.book_pages'))
          .fontSize(34)
          .fontColor([$r('app.color.ink_muted')])
        Text('这份官方电子书未能打开')
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
        if (this.failReason.length > 0) {
          Text(this.failReason)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
            .margin({ top: 4 })
            .opacity(0.6)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.White)
    } else {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.White)
        PdfView({
          controller: this.controller,
          pageLayout: this.dualPage ?
            pdfService.PageLayout.LAYOUT_DOUBLE : pdfService.PageLayout.LAYOUT_SINGLE,
          isContinuous: this.flipMode === 1,
          showScroll: false,
          pageFit: pdfService.PageFit.FIT_PAGE
        })
          .width('100%')
          .height('100%')
          .backgroundColor(Color.White)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
  }
}
