/**
 * A single app action rendered with the native ArkUI button states and metrics.
 * Labeled actions use the system rounded-rectangle button; icon-only actions
 * use the system circular button while preserving a 40 vp or larger hot area.
 */
@Component
export struct ImmersiveAction {
  label: string = '';
  actionAccessibilityText: string = '';
  icon: Resource = $r('sys.symbol.arrow_right');
  actionSize: number = 46;
  actionEnabled: boolean = true;
  emphasized: boolean = false;
  onAction: () => void = () => {};

  build() {
    if (this.label.length > 0) {
      Button(this.label, {
        type: ButtonType.ROUNDED_RECTANGLE,
        stateEffect: true
      })
        .buttonStyle(this.emphasized ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL)
        .controlSize(this.actionSize <= 40 ? ControlSize.SMALL : ControlSize.NORMAL)
        .enabled(this.actionEnabled)
        .accessibilityText(this.accessibilityLabel())
        .onClick(this.onAction)
    } else {
      Button({
        type: ButtonType.Circle,
        stateEffect: true
      }) {
        SymbolGlyph(this.icon)
          .fontSize(this.actionSize <= 40 ? 18 : 20)
          .fontColor([this.emphasized ? Color.White : $r('app.color.ink')])
      }
      .width(Math.max(40, this.actionSize))
      .height(Math.max(40, this.actionSize))
      .buttonStyle(this.emphasized ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL)
      .controlSize(this.actionSize <= 40 ? ControlSize.SMALL : ControlSize.NORMAL)
      .enabled(this.actionEnabled)
      .accessibilityText(this.accessibilityLabel())
      .onClick(this.onAction)
    }
  }

  private accessibilityLabel(): string {
    return this.actionAccessibilityText.length > 0 ? this.actionAccessibilityText : this.label;
  }
}
