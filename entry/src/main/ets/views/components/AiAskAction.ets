@Component
export struct AiAskAction {
  label: string = '问 AI';
  onAsk: () => void = () => {};

  build() {
    Row({ space: 6 }) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(15)
        .fontColor([$r('app.color.accent')])
      Text(this.label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
    }
    .height(34)
    .padding({ left: 11, right: 12 })
    .borderRadius(17)
    .backgroundColor($r('app.color.accent_soft'))
    .accessibilityText(this.label)
    .onClick(this.onAsk)
  }
}
