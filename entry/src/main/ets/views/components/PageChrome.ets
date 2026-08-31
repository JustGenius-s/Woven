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
export struct PageChrome {
  eyebrow: string = '';
  title: string = '';
  largeTitle: boolean = true;
  customTitle: boolean = false;
  showSearchAction: boolean = false;
  bottomHeight: number = 0;
  scrollers: Scroller[] = [];
  onSearch: () => void = () => {};
  @BuilderParam pageContent: () => void = this.emptyPageContent;
  @BuilderParam bottomContent: () => void = this.emptyBottomContent;
  @BuilderParam customTitleContent: () => void = this.emptyCustomTitleContent;

  @Builder
  private emptyPageContent() {
  }

  @Builder
  private emptyBottomContent() {
  }

  @Builder
  private emptyCustomTitleContent() {
  }

  build() {
    HdsNavigation() {
      this.pageContent()
    }
    .titleBar({
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
              subTitleColor: $r('app.color.accent')
            },
            menuStyle: {
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
        title: this.customTitle ? undefined : {
          mainTitle: this.title,
          subTitle: this.eyebrow.length > 0 ? this.eyebrow : undefined,
          mainTitleAccessibilityText: this.title,
          mainTitleSize: this.largeTitle ? TitleSize.TITLE_ML : TitleSize.TITLE_S
        },
        menu: !this.customTitle && this.showSearchAction ? {
          value: [{
            content: {
              icon: $r('sys.symbol.magnifyingglass'),
              label: '搜索',
              action: () => this.onSearch()
            }
          }],
          maxCount: 1
        } : undefined,
        stackBuilder: this.customTitle ? this.customTitleContent : undefined,
        bottomBuilder: this.bottomHeight > 0 ? {
          builder: this.bottomContent,
          height: this.bottomHeight
        } : undefined,
        divider: {
          showType: DividerShowType.OFF
        }
      }
    })
    .mode(NavigationMode.Stack)
    .titleMode(this.largeTitle ? HdsNavigationTitleMode.FULL : HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .bindToScrollable(this.scrollers)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor(Color.Transparent)
  }
}
