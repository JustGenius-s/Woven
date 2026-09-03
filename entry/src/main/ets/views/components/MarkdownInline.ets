import { MarkdownSpan, MD_BOLD, MD_BOLD_ITALIC, MD_INLINE_CODE, MD_ITALIC, MD_LINK } from '../../model/MarkdownModels';

const MONO_FONT: string = 'HarmonyOS Sans Mono';
const NO_DECORATION: DecorationStyleInterface = { type: TextDecorationType.None };
const CLEAR_BACKGROUND: TextBackgroundStyle = { color: Color.Transparent, radius: 4 };

/**
 * Renders one parsed inline span as a `Span` inside a caller-owned `Text`.
 *
 * `Span` is used rather than nested `Text` widgets so a whole answer stays a
 * single selectable run: the bubbles set `copyOption` and attach the "ask AI"
 * selection menu to the enclosing `Text`, and per-span widgets would break both.
 */
@Builder
export function markdownSpan(span: MarkdownSpan, index: number, fontSize: number, textColor: ResourceColor) {
  if (span.kind === MD_INLINE_CODE) {
    Span(span.text)
      .fontSize(fontSize * 0.92)
      .fontColor($r('app.color.accent'))
      .fontFamily(MONO_FONT)
      .decoration(NO_DECORATION)
      .textBackgroundStyle({ color: $r('app.color.accent_soft'), radius: 4 })
  } else if (span.kind === MD_LINK) {
    Span(span.text)
      .fontSize(fontSize)
      .fontColor($r('app.color.accent'))
      .decoration({ type: TextDecorationType.Underline, color: $r('app.color.accent') })
      .textBackgroundStyle(CLEAR_BACKGROUND)
  } else {
    Span(span.text)
      .fontSize(fontSize)
      .fontColor(textColor)
      .fontWeight(span.kind === MD_BOLD || span.kind === MD_BOLD_ITALIC ? FontWeight.Bold : FontWeight.Regular)
      .fontStyle(span.kind === MD_ITALIC || span.kind === MD_BOLD_ITALIC ? FontStyle.Italic : FontStyle.Normal)
      .decoration(NO_DECORATION)
      .textBackgroundStyle(CLEAR_BACKGROUND)
  }
}
