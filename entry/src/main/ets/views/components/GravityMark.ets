import { curves } from '@kit.ArkUI';

/**
 * A compact expression of the HarmonyOS gravity language: orbit, balance and
 * attraction are represented with a ring, a weighted core and two satellites.
 * Motion is state-driven and settles once instead of looping decoratively.
 */
@Component
export struct GravityMark {
  diameter: number = 92;
  @Prop progress: number = 0;
  showLabel: boolean = true;

  @State private settled: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => this.settled = true, 40);
  }

  private orbitX(reverse: boolean = false): number {
    const step: number = Math.max(0, Math.min(this.progress, 5));
    const angle: number = ((step * 60) - 90 + (reverse ? 180 : 0)) * Math.PI / 180;
    return Math.cos(angle) * this.diameter * 0.39;
  }

  private orbitY(reverse: boolean = false): number {
    const step: number = Math.max(0, Math.min(this.progress, 5));
    const angle: number = ((step * 60) - 90 + (reverse ? 180 : 0)) * Math.PI / 180;
    return Math.sin(angle) * this.diameter * 0.39;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.diameter)
        .height(this.diameter)
        .borderRadius(this.diameter / 2)
        .border({ width: 1.5, color: $r('app.color.accent') })
        .opacity(this.settled ? 0.18 : 0)
        .scale({ x: this.settled ? 1 : 0.72, y: this.settled ? 1 : 0.72 })
        .shadow({ radius: this.diameter * 0.12, color: $r('app.color.gravity_glow') })
        .animation({ curve: curves.springMotion(0.46, 0.82, 0.18) })

      Column()
        .width(this.diameter * 0.72)
        .height(this.diameter * 0.72)
        .borderRadius(this.diameter * 0.36)
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .opacity(this.settled ? 0.68 : 0)
        .rotate({ angle: this.settled ? -12 : -38 })
        .animation({ curve: curves.springMotion(0.5, 0.86, 0.16) })

      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 145,
            colors: [[$r('app.color.immersive_edge'), 0], [$r('app.color.accent_soft'), 1]]
          })
        if (this.showLabel) {
          Text((Math.max(0, Math.min(this.progress, 5)) + 1).toString().padStart(2, '0'))
            .fontSize(this.diameter * 0.13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
        }
      }
      .width(this.diameter * 0.54)
      .height(this.diameter * 0.54)
      .borderRadius(this.diameter * 0.27)
      .clip(true)
      .border({ width: 0.8, color: $r('app.color.immersive_edge') })
      .shadow({ radius: this.diameter * 0.1, color: '#1F1646A8', offsetY: this.diameter * 0.03 })
      .scale({ x: this.settled ? 1 : 0.82, y: this.settled ? 1 : 0.82 })
      .animation({ curve: curves.springMotion(0.4, 0.84, 0.18) })

      Column()
        .width(this.diameter * 0.18)
        .height(this.diameter * 0.18)
        .borderRadius(this.diameter * 0.09)
        .backgroundColor($r('app.color.accent'))
        .border({ width: 1.5, color: $r('app.color.surface_raised') })
        .shadow({ radius: this.diameter * 0.08, color: $r('app.color.gravity_glow') })
        .translate({
          x: this.settled ? this.orbitX() : 0,
          y: this.settled ? this.orbitY() : 0
        })
        .animation({ curve: curves.springMotion(0.38, 0.78, 0.2) })

      Column()
        .width(this.diameter * 0.1)
        .height(this.diameter * 0.1)
        .borderRadius(this.diameter * 0.05)
        .backgroundColor($r('app.color.surface_raised'))
        .border({ width: 0.8, color: $r('app.color.immersive_edge') })
        .translate({
          x: this.settled ? this.orbitX(true) : 0,
          y: this.settled ? this.orbitY(true) : 0
        })
        .animation({ curve: curves.springMotion(0.44, 0.86, 0.16) })
    }
    .width(this.diameter)
    .height(this.diameter)
    .hitTestBehavior(HitTestMode.None)
  }
}
