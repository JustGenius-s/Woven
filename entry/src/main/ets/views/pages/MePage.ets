import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { LearningJourney } from '../../model/ContentModels';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

@Component
export struct MePage {
  journey: LearningJourney | undefined = undefined;
  onSettings: () => void = () => {};
  private pageScroller: Scroller = new Scroller();

  build() {
    PageChrome({
      title: '我的',
      scrollers: [this.pageScroller],
      pageContent: () => {
        this.pageContent()
      }
    })
  }

  @Builder
  private pageContent() {
      Scroll(this.pageScroller) {
        Column() {
          Column({ space: 24 }) {
            this.profileCard()
            this.settingsSection()
          }
          .width('100%')
          .constraintSize({ maxWidth: 560 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 16, right: 16, top: 18, bottom: FLOATING_TAB_CONTENT_INSET })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .clip(false)
  }

  @Builder
  private profileCard() {
    Row({ space: 16 }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(34)
          .fontColor([$r('app.color.accent')])
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor($r('app.color.accent_soft'))

      Column({ space: 5 }) {
        Text('我的学习')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.journey === undefined ? '日语学习' : `当前旅程 · ${this.journey.title}`)
          .fontSize(14)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane_strong'), saturation: 1.06 })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
  }

  @Builder
  private settingsSection() {
    Column({ space: 8 }) {
      Text('通用')
        .width('100%')
        .padding({ left: 8 })
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_muted'))

      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.gearshape_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.accent')])

        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.ink_muted')])
      }
      .width('100%')
      .height(64)
      .padding({ left: 18, right: 18 })
      .borderRadius(24)
      .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane'), saturation: 1.06 })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .visualEffect(contentLightEffect())
      .accessibilityText('设置')
      .onClick(this.onSettings)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
