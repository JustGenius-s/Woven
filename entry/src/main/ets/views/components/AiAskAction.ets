@Component
export struct AiAskAction {
  label: string = '问 AI';
  onAsk: () => void = () => {};

  build() {
    Button(this.label, {
      type: ButtonType.ROUNDED_RECTANGLE,
      stateEffect: true
    })
      .buttonStyle(ButtonStyleMode.TEXTUAL)
      .controlSize(ControlSize.SMALL)
      .accessibilityText(this.label)
      .onClick(this.onAsk)
  }
}
