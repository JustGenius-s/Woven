import {
  BlurStrategy,
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  TitleSize
} from '@kit.UIDesignKit';
import { preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';
import { aiFlowEffect } from './ImmersiveCanvas';

@Component
export struct PageChrome {
  eyebrow: string = '';
  title: string = '';
  onSettings: () => void = () => {};

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
              iconColor: $r('app.color.ink_muted')
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
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.gearshape'),
              label: '连接设置',
              isEnabled: true,
              action: this.onSettings
            }
          }]
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

@Component
export struct InlineAiResult {
  title: string = '先生のノート';
  text: string = '';
  loading: boolean = false;
  error: string = '';

  build() {
    if (this.loading || this.text.length > 0 || this.error.length > 0) {
      Column({ space: 18 }) {
        Row({ space: 10 }) {
          Text('AI')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent'))
            .letterSpacing(1.4)
          Text(this.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_muted'))
        }
        if (this.text.length > 0) {
          ForEach(this.text.split('\n\n'), (paragraph: string, index: number) => {
            if (paragraph.trim().length > 0) {
              Text(paragraph.trim())
                .width(index === 0 ? '100%' : '94%')
                .fontSize(index === 0 ? 20 : 17)
                .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
                .fontColor($r('app.color.ink'))
                .lineHeight(index === 0 ? 33 : 29)
                .textAlign(TextAlign.Start)
                .alignSelf(index % 2 === 0 ? ItemAlign.Start : ItemAlign.End)
            }
          }, (paragraph: string, index: number) => `${index}-${paragraph.length}`)
        }
        if (this.loading) {
          Row({ space: 6 }) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('app.color.accent'))
            Text(this.text.length > 0 ? '继续生成' : '正在理解内容')
              .fontSize(13)
              .fontColor($r('app.color.ink_muted'))
          }
        }
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(14)
            .fontColor($r('app.color.danger'))
            .lineHeight(22)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 22, bottom: 22 })
      .margin({ top: 10, bottom: 10 })
      .borderRadius(26)
      .clip(true)
      .backgroundEffect({ radius: 30, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .visualEffect(aiFlowEffect(this.loading))
    }
  }
}
