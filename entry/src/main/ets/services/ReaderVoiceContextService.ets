import { pdfService } from '@kit.PDFKit';
import { ReaderVoiceContext } from '../model/RealtimeVoiceModels';

export class ReaderVoiceContextService {
  private path: string = '';
  private pages: string[] = [];

  async read(path: string, title: string, pageIndex: number, cancelled: () => boolean,
    allowEmptyPage: boolean = false): Promise<ReaderVoiceContext> {
    if (path !== this.path) {
      const document = new pdfService.PdfDocument();
      const pages: string[] = [];
      try {
        if (document.loadDocument(path) !== pdfService.ParseResult.PARSE_SUCCESS) {
          throw new Error('暂时无法读取教材，请重新打开这一课');
        }
        const count: number = document.getPageCount();
        for (let index: number = 0; index < count; index++) {
          if (cancelled()) {
            throw new Error('请求已取消');
          }
          pages.push(document.getPage(index).getTextContent().replace(/\u0000/g, '').trim());
          // Yield between pages so reader gestures and cancellation remain responsive.
          await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
        }
      } finally {
        document.releaseDocument();
      }
      if (cancelled()) {
        throw new Error('请求已取消');
      }
      this.path = path;
      this.pages = pages;
    }
    return ReaderVoiceContextService.compose(title, this.pages, pageIndex, allowEmptyPage);
  }

  static compose(title: string, pages: string[], pageIndex: number,
    allowEmptyPage: boolean = false): ReaderVoiceContext {
    if (pageIndex < 0 || pageIndex >= pages.length || (!allowEmptyPage && !pages[pageIndex]?.trim())) {
      throw new Error('这一页没有可读取的文字，请翻到有正文的页面再试');
    }
    // Put the focus first, then nearby pages, then a bounded view of the rest
    // of the lesson. Page labels are PDF page numbers, never printed folios.
    let text: string = `日语教材：${title.slice(0, 160)}\n当前 PDF 第 ${pageIndex + 1} / ${pages.length} 页。` +
      '\n讲解围绕当前页解释语法、例句和使用场景。中文解释，保留日文例句；其他页只作背景。\n' +
      `【当前页 ${pageIndex + 1}】\n${pages[pageIndex].trim() ? pages[pageIndex].slice(0, 6000) :
        '本页没有可提取文字，可能是空白页或扫描图片。不能识别其中的图文，请用户描述；不要把其他页当作当前页。'}\n`;
    const order: number[] = [];
    for (let distance: number = 1; distance < pages.length; distance++) {
      if (pageIndex - distance >= 0) { order.push(pageIndex - distance); }
      if (pageIndex + distance < pages.length) { order.push(pageIndex + distance); }
    }
    const budget: number = Math.max(160, Math.floor((11500 - text.length) / Math.max(1, order.length)));
    for (const index of order) {
      if (pages[index].trim().length > 0 && text.length < 11500) {
        text += `\n【教材第 ${index + 1} 页，背景摘录】\n${pages[index].slice(0, budget)}\n`;
      }
    }
    return { pageIndex: pageIndex, pageCount: pages.length, text: text.slice(0, 12000) };
  }
}
