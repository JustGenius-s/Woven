import { hdsEffect } from '@kit.UIDesignKit';

@Component
export struct ImmersiveBackdrop {
  @BuilderParam canvasContent: () => void = this.emptyContent;

  @State private drift: boolean = false;
  @State private lightX: number = 80;
  @State private lightY: number = 130;
  @State private lightIntensity: number = 0;

  aboutToAppear(): void {
    setTimeout(() => this.drift = true, 80);
  }

  @Builder
  private emptyContent() {
  }

  build() {
    Stack() {
      Column()
        .width(390)
        .height(390)
        .borderRadius(195)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#24D86255', 0], ['#00D86255', 1]]
        })
        .translate({ x: this.drift ? 48 : -28, y: this.drift ? -32 : 28 })
        .position({ x: -126, y: 42 })
        .animation({
          duration: 9000,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })

      Column()
        .width(340)
        .height(340)
        .borderRadius(170)
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [['#2075A89A', 0], ['#0075A89A', 1]]
        })
        .translate({ x: this.drift ? -42 : 32, y: this.drift ? 54 : -24 })
        .position({ x: 190, y: 420 })
        .animation({
          duration: 11000,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })

      this.canvasContent()

      Column()
        .width(1)
        .height(1)
        .position({ x: this.lightX, y: this.lightY })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            options: {
              color: $r('app.color.immersive_light'),
              intensity: this.lightIntensity,
              height: 150,
              bloom: 0.34
            }
          })
          .buildEffect())
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('app.color.surface'))
    .onTouch((event: TouchEvent) => this.trackLight(event))
  }

  private trackLight(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      this.lightX = event.touches[0].x;
      this.lightY = event.touches[0].y;
      this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
        this.lightIntensity = 2.6;
      });
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.getUIContext().animateTo({ duration: 520, curve: Curve.EaseOut }, () => {
        this.lightIntensity = 0;
      });
    }
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
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .shadow({ radius: 24, color: '#12000000', offsetY: 9 })
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
        this.pressEffect = hdsEffect.PressShadowType.BLEND_GRADIENT;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
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

export function aiFlowEffect(active: boolean): VisualEffect {
  if (!active) {
    return new hdsEffect.HdsEffectBuilder()
      .pointLight({ illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT })
      .buildEffect();
  }
  return new hdsEffect.HdsEffectBuilder()
    .pointLight({ illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT })
    .shaderEffect({
      effectType: hdsEffect.EffectType.DUAL_EDGE_FLOW_LIGHT,
      animation: {
        duration: 1900,
        iterations: -1,
        curve: Curve.EaseInOut,
        expectedFrameRateRange: {
          min: hdsEffect.FrameRateType.FRAME_RATE_15,
          expected: hdsEffect.FrameRateType.FRAME_RATE_30,
          max: hdsEffect.FrameRateType.FRAME_RATE_60
        }
      },
      params: {
        firstEdgeFlowLight: { startPos: 0.02, endPos: 0.18, color: $r('app.color.accent') },
        secondEdgeFlowLight: { startPos: 0.52, endPos: 0.68, color: $r('app.color.immersive_cool') }
      }
    })
    .buildEffect();
}
