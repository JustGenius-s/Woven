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
            }
          }
        },
        blurStrategy: BlurStrategy.ADAPTIVE,
        systemMaterialEffect: preferredImmersiveMaterial()
      },
      content: {
        title: {
          mainTitle: this.title,
          subTitle: this.eyebrow.length > 0 ? this.eyebrow : undefined,
          mainTitleAccessibilityText: this.title,
          mainTitleSize: TitleSize.TITLE_S
        },
        divider: {
          showType: DividerShowType.OFF
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .width('100%')
    .height(64)
    .backgroundColor(Color.Transparent)
  }
}
