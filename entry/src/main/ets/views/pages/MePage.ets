import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { LearningJourney } from '../../model/ContentModels';
import {
  HuaweiAccountPhase,
  HuaweiAccountSnapshot
} from '../../model/SyncModels';
import { HuaweiAccountCard } from '../components/HuaweiAccountCard';
import { contentLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

const EMPTY_ACCOUNT: HuaweiAccountSnapshot = {
  phase: HuaweiAccountPhase.SIGNED_OUT,
  unionId: '',
  openId: '',
  detail: ''
};

@Component
export struct MePage {
  journey: LearningJourney | undefined = undefined;
  @Prop account: HuaweiAccountSnapshot = EMPTY_ACCOUNT;
  onSettings: () => void = () => {};
  onAccountChange: (snapshot: HuaweiAccountSnapshot) => void =
    (snapshot: HuaweiAccountSnapshot) => {};
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
    HuaweiAccountCard({
      account: this.account,
      journeyCaption: this.journey === undefined ? '日语学习' : `当前旅程 · ${this.journey.title}`,
      onAccountChange: this.onAccountChange
    })
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
