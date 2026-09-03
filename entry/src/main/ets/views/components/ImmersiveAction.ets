import { FLOATING_CHROME_MATERIAL } from '../../common/ImmersiveMaterial';

/**
 * A single app action rendered with the native ArkUI button states and metrics.
 * Labeled actions use the system rounded-rectangle button; icon-only actions
 * use the system circular button while preserving a 40 vp or larger hot area.
 * Non-emphasized actions sit on THIN immersive material with auto-invert.
 * Emphasized actions keep the filled system style so the accent plate stays.
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
      if (this.emphasized) {
        Button(this.label, {
          type: ButtonType.ROUNDED_RECTANGLE,
          stateEffect: true
        })
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(this.actionSize <= 40 ? ControlSize.SMALL : ControlSize.NORMAL)
          .enabled(this.actionEnabled)
          .accessibilityText(this.accessibilityLabel())
          .onClick(this.onAction)
      } else {
        Button(this.label, {
          type: ButtonType.ROUNDED_RECTANGLE,
          stateEffect: true
        })
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(this.actionSize <= 40 ? ControlSize.SMALL : ControlSize.NORMAL)
          .enabled(this.actionEnabled)
          .fontColor($r('sys.color.font_primary'))
          .backgroundColor(Color.Transparent)
          .accessibilityText(this.accessibilityLabel())
          .onClick(this.onAction)
          .systemMaterial(FLOATING_CHROME_MATERIAL)
      }
    } else if (this.emphasized) {
      Button({
        type: ButtonType.Circle,
        stateEffect: true
      }) {
        SymbolGlyph(this.icon)
          .fontSize(this.actionSize <= 40 ? 18 : 20)
          .fontColor([Color.White])
      }
      .width(Math.max(40, this.actionSize))
      .height(Math.max(40, this.actionSize))
      .buttonStyle(ButtonStyleMode.EMPHASIZED)
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
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(Math.max(40, this.actionSize))
      .height(Math.max(40, this.actionSize))
      .buttonStyle(ButtonStyleMode.NORMAL)
      .controlSize(this.actionSize <= 40 ? ControlSize.SMALL : ControlSize.NORMAL)
      .enabled(this.actionEnabled)
      .backgroundColor(Color.Transparent)
      .accessibilityText(this.accessibilityLabel())
      .onClick(this.onAction)
      .systemMaterial(FLOATING_CHROME_MATERIAL)
    }
  }

  private accessibilityLabel(): string {
    return this.actionAccessibilityText.length > 0 ? this.actionAccessibilityText : this.label;
  }
}
