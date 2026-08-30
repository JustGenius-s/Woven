import { hdsEffect } from '@kit.UIDesignKit';
import { curves } from '@kit.ArkUI';

@Component
export struct ImmersiveBackdrop {
  @BuilderParam canvasContent: () => void = this.emptyContent;

  @State private settled: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => this.settled = true, 60);
  }

  @Builder
  private emptyContent() {
  }

  build() {
    Stack() {
      Column()
        .width(500)
        .height(500)
        .borderRadius(250)
        .border({ width: 1.5, color: $r('app.color.accent') })
        .opacity(this.settled ? 0.08 : 0)
        .scale({ x: this.settled ? 1 : 0.68, y: this.settled ? 1 : 0.68 })
        .position({ x: -258, y: -210 })
        .animation({ curve: curves.springMotion(0.62, 0.9, 0.12) })
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width(280)
        .height(280)
        .borderRadius(140)
        .radialGradient({
          center: ['42%', '38%'],
          radius: '50%',
          colors: [[$r('app.color.gravity_glow'), 0], [Color.Transparent, 1]]
        })
        .opacity(this.settled ? 1 : 0)
        .translate({ x: this.settled ? -18 : 28, y: this.settled ? 14 : 48 })
        .position({ x: '56%', y: 360 })
        .animation({ curve: curves.springMotion(0.72, 0.92, 0.1) })
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width(78)
        .height(78)
        .borderRadius(39)
        .linearGradient({
          angle: 145,
          colors: [[$r('app.color.immersive_edge'), 0], [$r('app.color.accent_soft'), 1]]
        })
        .border({ width: 0.8, color: $r('app.color.immersive_edge') })
        .shadow({ radius: 18, color: $r('app.color.gravity_glow'), offsetY: 6 })
        .translate({ x: this.settled ? 0 : 42, y: this.settled ? 0 : 26 })
        .position({ x: '72%', y: 126 })
        .animation({ curve: curves.springMotion(0.48, 0.8, 0.2) })
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width(18)
        .height(18)
        .borderRadius(9)
        .backgroundColor($r('app.color.accent'))
        .shadow({ radius: 14, color: $r('app.color.gravity_glow') })
        .position({ x: '88%', y: 188 })
        .translate({ x: this.settled ? 0 : -32, y: this.settled ? 0 : -34 })
        .animation({ curve: curves.springMotion(0.42, 0.78, 0.22) })
        .hitTestBehavior(HitTestMode.None)

      this.canvasContent()
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('app.color.surface'))
  }
}

@Component
export struct ImmersivePlane {
  @BuilderParam planeContent: () => void = this.emptyContent;
  planeWidth: Length = '100%';
  planeRadius: number = 28;
  planeStrong: boolean = false;
  interactive: boolean = false;

  @State private pressEffect: hdsEffect.PressShadowType = hdsEffect.PressShadowType.NONE;
  @State private pressed: boolean = false;

  @Builder
  private emptyContent() {
  }

  build() {
    Stack() {
      this.planeContent()
    }
    .width(this.planeWidth)
    .borderRadius(this.planeRadius)
    .clip(true)
    .backgroundEffect({
      radius: this.planeStrong ? 34 : 26,
      color: this.planeStrong ? $r('app.color.immersive_plane_strong') : $r('app.color.immersive_plane'),
      saturation: 1.08
    })
    .linearGradient({
      angle: 155,
      colors: [[$r('app.color.immersive_edge'), 0], [Color.Transparent, 0.46],
        [$r('app.color.accent_soft'), 1]]
    })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .shadow({ radius: 22, color: '#181646A8', offsetY: 8 })
    .scale({ x: this.interactive && this.pressed ? 0.985 : 1,
      y: this.interactive && this.pressed ? 0.985 : 1 })
    .animation({ curve: curves.responsiveSpringMotion(0.18, 0.86, 0.12) })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT
      })
      .pressShadow(this.pressEffect)
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (!this.interactive) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.pressed = true;
        this.pressEffect = hdsEffect.PressShadowType.BLEND_GRADIENT;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
        this.pressEffect = hdsEffect.PressShadowType.NONE;
      }
    })
  }
}

export function contentLightEffect(): VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({ illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT })
    .buildEffect();
}

export function planeLightEffect(): VisualEffect {
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({ illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT })
    .buildEffect();
}
