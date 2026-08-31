import {
  BlurStrategy,
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
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
  onSearch: () => void = () => {};
  @BuilderParam bottomContent: () => void = this.emptyBottomContent;
  @BuilderParam customTitleContent: () => void = this.emptyCustomTitleContent;

  @Builder
  private emptyBottomContent() {
  }

  @Builder
  private emptyCustomTitleContent() {
  }

  private titleHeight(): number {
    return this.largeTitle ? 112 : 56;
  }

  build() {
    HdsNavigation() {
      Column()
        .width('100%')
        .height('100%')
    }
    .titleBar({
      style: {
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent
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
        blurStrategy: BlurStrategy.ADAPTIVE,
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
    .titleMode(this.largeTitle ? HdsNavigationTitleMode.FULL : HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .width('100%')
    .height(this.titleHeight() + this.bottomHeight)
    .backgroundColor(Color.Transparent)
  }
}
