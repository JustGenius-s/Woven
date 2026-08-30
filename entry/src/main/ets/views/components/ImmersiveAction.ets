import { ActionBarButton, ActionBarStyle, BlurStrategy, HdsActionBar } from '@kit.UIDesignKit';
import { ColorMetrics, LengthMetrics } from '@ohos.arkui.node';
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';

/**
 * A restrained HDS action: the label stays in the reading flow while the
 * actionable core is rendered by the system HdsActionBar material.
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
    Row({ space: this.label.length > 0 ? 9 : 0 }) {
      if (this.label.length > 0) {
        Text(this.label)
          .fontSize(13)
          .fontWeight(this.emphasized ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.actionEnabled ? $r('app.color.ink') : $r('app.color.ink_muted'))
          .onClick(() => {
            if (this.actionEnabled) {
              this.onAction();
            }
          })
      }
      HdsActionBar({
        primaryButton: this.actionButton(),
        actionBarStyle: this.actionStyle(),
        blurStrategy: BlurStrategy.ADAPTIVE
      })
        .width(this.actionSize)
        .height(this.actionSize)
    }
    .height(this.actionSize)
    .opacity(this.actionEnabled ? 1 : 0.56)
  }

  private actionButton(): ActionBarButton {
    return new ActionBarButton({
      width: LengthMetrics.vp(this.actionSize),
      backgroundColor: ColorMetrics.rgba(216, 98, 85, this.emphasized ? 0.18 : 0.06),
      enabled: this.actionEnabled,
      iconSize: LengthMetrics.vp(Math.max(17, this.actionSize - 27)),
      baseIconSymbolGlyphModifier: this.symbolModifier(),
      accessibilityText: this.actionAccessibilityText.length > 0 ? this.actionAccessibilityText : this.label,
      onClick: this.onAction
    });
  }

  private actionStyle(): ActionBarStyle {
    return new ActionBarStyle({
      height: LengthMetrics.vp(this.actionSize),
      backgroundBlurStyle: BlurStyle.COMPONENT_REGULAR,
      innerSpace: LengthMetrics.vp(0),
      startSpace: LengthMetrics.vp(0),
      endSpace: LengthMetrics.vp(0),
      margin: LengthMetrics.vp(0),
      isHorizontal: true,
      enabled: this.actionEnabled
    });
  }

  private symbolModifier(): SymbolGlyphModifier {
    const modifier: SymbolGlyphModifier = new SymbolGlyphModifier(this.icon);
    modifier.fontSize(Math.max(17, this.actionSize - 27));
    modifier.fontColor([this.emphasized ? $r('app.color.accent') : $r('app.color.ink')]);
    return modifier;
  }
}
