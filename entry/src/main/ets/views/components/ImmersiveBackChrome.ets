import { LengthMetrics } from '@kit.ArkUI';
import {
  BlurStrategy,
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
  TitleSize
} from '@kit.UIDesignKit';
import { preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';

@Component
export struct ImmersiveBackChrome {
  title: string = '';
  subtitle: string = '';
  closeIcon: boolean = false;
  scrollers: Scroller[] = [];
  onBack: () => void = () => {};
  @BuilderParam pageContent: () => void = this.emptyPageContent;

  @Builder
  private emptyPageContent() {
  }

  build() {
    HdsNavigation() {
      this.pageContent()
    }
    .titleBar({
      // Keep the back button and title below the status bar while the bar
      // background still extends into it. Defaults to false when omitted.
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          enableRefreshOffsetChange: true,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(24)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent,
            maskExtraHeight: 0,
            blurRadius: 0
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('app.color.ink'),
              subTitleColor: $r('app.color.ink_muted')
            },
            backIconStyle: {
              iconColor: $r('app.color.ink')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent,
            maskExtraHeight: 0,
            blurRadius: 40
          }
        },
        blurStrategy: BlurStrategy.ADAPTIVE,
        thermoCtrl: true,
        systemMaterialEffect: preferredImmersiveMaterial()
      },
      content: {
        title: {
          mainTitle: this.title,
          subTitle: this.subtitle.length > 0 ? this.subtitle : undefined,
          mainTitleAccessibilityText: this.title,
          mainTitleSize: TitleSize.TITLE_S
        },
        backIcon: {
          icon: this.closeIcon ? $r('sys.symbol.xmark') : $r('sys.symbol.chevron_left'),
          label: this.closeIcon ? '关闭' : '返回',
          action: this.onBack
        },
        divider: {
          showType: DividerShowType.OFF
        }
      }
    })
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .bindToScrollable(this.scrollers)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor(Color.Transparent)
  }
}
