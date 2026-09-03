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
  onFailed: () => void = () => {};

  private controller: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  private loaded: boolean = false;
  @State private failed: boolean = false;

  aboutToAppear(): void {
    void this.openDocument();
  }

  aboutToDisappear(): void {
    this.closeDocument();
  }

  private async openDocument(): Promise<void> {
    if (this.pdfPath.length === 0 ||
      !canIUse('SystemCapability.OfficeService.PDFService.Core')) {
      this.markFailed();
      return;
    }
    try {
      this.controller.registerPageCountChangedListener((_pageCount: number) => {});
      this.controller.registerPageChangedListener((pageIndex: number) => {
        this.onPageChanged(pageIndex);
      });
      await this.controller.loadDocument(this.pdfPath, '', this.startPage);
      this.loaded = true;
      this.applyViewStyle();
      this.applyHighlight();
    } catch (error) {
      this.markFailed();
    }
  }

  private closeDocument(): void {
    if (!this.loaded) {
      return;
    }
    this.controller.releaseDocument();
    this.loaded = false;
  }

  private markFailed(): void {
    this.failed = true;
    this.onFailed();
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
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
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
    }
  }
}
