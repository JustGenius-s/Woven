import {
  BlurStrategy,
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  TitleSize
} from '@kit.UIDesignKit';
import { preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';

@Component
export struct ImmersiveBackChrome {
  title: string = '';
  subtitle: string = '';
  closeIcon: boolean = false;
  onBack: () => void = () => {};

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
              subTitleColor: $r('app.color.ink_muted')
            },
            backIconStyle: {
              iconColor: $r('app.color.ink')
            }
          }
        },
        blurStrategy: BlurStrategy.ADAPTIVE,
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
    .titleMode(HdsNavigationTitleMode.MINI)
    .width('100%')
    .height(64)
    .backgroundColor(Color.Transparent)
  }
}
