import {
  MarkdownBlock,
  MarkdownListItem,
  MarkdownSpan,
  MD_CODE,
  MD_HEADING,
  MD_LIST,
  MD_QUOTE,
  MD_RULE,
  MD_TABLE
} from '../../model/MarkdownModels';
import { MarkdownParser } from '../../services/MarkdownParser';
import { aiTextSelectionMenu } from './AiTextSelection';
import { markdownSpan } from './MarkdownInline';

const BULLETS: string[] = ['•', '◦'];

/**
 * Renders a Markdown answer as native ArkUI widgets.
 *
 * Both AI surfaces mount this with their own typography: the inquiry panel uses
 * reading-sized text, the role-play session uses the large display size. The
 * parser runs on every render, so parsing stays cheap and allocation-free when
 * the text has not changed.
 */
@Component
export struct MarkdownText {
  text: string = '';
  fontSize: number = 16;
  lineHeight: number = 26;
  textColor: ResourceColor = $r('app.color.ink');
  textAlign: TextAlign = TextAlign.Start;
  headingSize: number = 18;
  mutedColor: ResourceColor = $r('app.color.ink_muted');
  accentColor: ResourceColor = $r('app.color.accent');
  onAskSelection: (selection: string) => void = (selection: string) => {};

  build() {
    Column({ space: 0 }) {
      ForEach(MarkdownParser.parse(this.text).blocks, (block: MarkdownBlock, index: number) => {
        this.block(block)
      }, (block: MarkdownBlock, index: number) => `${index}-${block.kind}-${block.text}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private block(block: MarkdownBlock) {
    if (block.kind === MD_HEADING) {
      Text() {
        ForEach(block.spans, (span: MarkdownSpan, index: number) => {
          markdownSpan(span, index, this.headingSize, this.textColor)
        }, (span: MarkdownSpan, index: number) => `${index}-${span.text}`)
      }
      .width('100%')
      .fontWeight(FontWeight.Bold)
      .lineHeight(this.headingSize + 8)
      .textAlign(this.textAlign)
      .copyOption(CopyOptions.LocalDevice)
      .editMenuOptions(aiTextSelectionMenu(MarkdownParser.stripInline(block.text),
        (selection: string) => this.onAskSelection(selection)))
      .margin({ top: 8, bottom: 4 })
    } else if (block.kind === MD_LIST) {
      Column({ space: 6 }) {
        ForEach(block.items, (item: MarkdownListItem, index: number) => {
          this.listItem(block, item, index)
        }, (item: MarkdownListItem, index: number) => `${index}-${item.text}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 2, right: 2, top: 4, bottom: 4 })
    } else if (block.kind === MD_QUOTE) {
      Text() {
        ForEach(block.spans, (span: MarkdownSpan, index: number) => {
          markdownSpan(span, index, this.fontSize * 0.94, this.mutedColor)
        }, (span: MarkdownSpan, index: number) => `${index}-${span.text}`)
      }
      .width('100%')
      .lineHeight(this.lineHeight - 2)
      .textAlign(this.textAlign)
      .copyOption(CopyOptions.LocalDevice)
      .editMenuOptions(aiTextSelectionMenu(MarkdownParser.stripInline(block.text),
        (selection: string) => this.onAskSelection(selection)))
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .margin({ top: 4, bottom: 4 })
      .borderRadius(12)
      .border({ width: { left: 3 }, color: this.accentColor })
      .backgroundColor($r('app.color.surface'))
    } else if (block.kind === MD_CODE) {
      Column({ space: 0 }) {
        if (block.language.length > 0) {
          Text(block.language)
            .width('100%')
            .fontSize(10)
            .fontColor(this.mutedColor)
            .letterSpacing(0.6)
            .padding({ left: 12, right: 12, top: 8, bottom: 2 })
        }
        Text(block.text)
          .width('100%')
          .fontSize(this.fontSize * 0.88)
          .fontFamily('HarmonyOS Sans Mono')
          .fontColor(this.textColor)
          .lineHeight(this.fontSize * 1.42)
          .textAlign(TextAlign.Start)
          .copyOption(CopyOptions.LocalDevice)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 4, bottom: 4 })
      .borderRadius(12)
      .backgroundColor($r('app.color.surface'))
    } else if (block.kind === MD_TABLE) {
      Column() {
        ForEach(block.cells, (row: string[], rowIndex: number) => {
          Row() {
            ForEach(row, (cell: string, cellIndex: number) => {
              Text(cell)
                .layoutWeight(1)
                .fontSize(this.fontSize * (rowIndex === 0 ? 0.81 : 0.88))
                .fontWeight(rowIndex === 0 ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(rowIndex === 0 ? this.mutedColor : this.textColor)
                .lineHeight(this.fontSize * 1.42)
                .textAlign(TextAlign.Start)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(cell,
                  (selection: string) => this.onAskSelection(selection)))
                .padding({ left: 7, right: 7, top: 8, bottom: 8 })
            }, (cell: string, cellIndex: number) => `${cellIndex}-${cell}`)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .backgroundColor(rowIndex === 0 ? $r('app.color.accent_soft') : Color.Transparent)
          .border({
            width: { bottom: rowIndex === block.cells.length - 1 ? 0 : 0.5 },
            color: $r('app.color.line')
          })
        }, (row: string[], rowIndex: number) => `${rowIndex}-${row.join('|')}`)
      }
      .width('100%')
      .margin({ top: 6, bottom: 6 })
      .borderRadius(14)
      .clip(true)
      .backgroundColor($r('app.color.surface_raised'))
    } else if (block.kind === MD_RULE) {
      Divider()
        .width('100%')
        .strokeWidth(0.5)
        .color($r('app.color.line'))
        .margin({ top: 10, bottom: 10 })
    } else {
      Text() {
        ForEach(block.spans, (span: MarkdownSpan, index: number) => {
          markdownSpan(span, index, this.fontSize, this.textColor)
        }, (span: MarkdownSpan, index: number) => `${index}-${span.text}`)
      }
      .width('100%')
      .lineHeight(this.lineHeight)
      .textAlign(this.textAlign)
      .copyOption(CopyOptions.LocalDevice)
      .editMenuOptions(aiTextSelectionMenu(MarkdownParser.stripInline(block.text),
        (selection: string) => this.onAskSelection(selection)))
      .margin({ top: 2, bottom: 2 })
    }
  }

  @Builder
  private listItem(block: MarkdownBlock, item: MarkdownListItem, index: number) {
    Row({ space: 8 }) {
      Text(block.ordered ? `${index + 1}.` : BULLETS[item.depth])
        .width(item.depth > 0 ? 16 : 20)
        .fontSize(block.ordered ? this.fontSize * 0.78 : this.fontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.accentColor)
        .textAlign(this.textAlign === TextAlign.End ? TextAlign.Start : this.textAlign)
      Text() {
        ForEach(MarkdownParser.parseInline(item.text), (span: MarkdownSpan, spanIndex: number) => {
          markdownSpan(span, spanIndex, this.fontSize, this.textColor)
        }, (span: MarkdownSpan, spanIndex: number) => `${spanIndex}-${span.text}`)
      }
      .layoutWeight(1)
      .lineHeight(this.lineHeight)
      .textAlign(this.textAlign)
      .copyOption(CopyOptions.LocalDevice)
      .editMenuOptions(aiTextSelectionMenu(MarkdownParser.stripInline(item.text),
        (selection: string) => this.onAskSelection(selection)))
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: item.depth * 14, right: 0, top: 2, bottom: 2 })
  }
}
