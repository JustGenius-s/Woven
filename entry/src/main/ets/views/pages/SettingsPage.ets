import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';

@Component
export struct SettingsPage {
  initialGatewayUrl: string = '';
  initialAppToken: string = '';
  initialModel: string = '';
  onClose: () => void = () => {};
  onSave: (gatewayUrl: string, appToken: string, model: string) => void =
    (gatewayUrl: string, appToken: string, model: string) => {};

  @State private gatewayUrl: string = '';
  @State private appToken: string = '';
  @State private model: string = '';
  @State private validation: string = '';
  @State private showLegal: boolean = false;

  aboutToAppear(): void {
    this.gatewayUrl = this.initialGatewayUrl;
    this.appToken = this.initialAppToken;
    this.model = this.initialModel;
  }

  private save(): void {
    const url: string = this.gatewayUrl.trim().replace(/\/+$/, '');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      this.validation = '网关地址需要以 http:// 或 https:// 开头';
      showImmersiveNotice(this.getUIContext(), '无法保存', this.validation);
      return;
    }
    if (this.model.trim().length === 0) {
      this.validation = '请填写模型 ID';
      showImmersiveNotice(this.getUIContext(), '无法保存', this.validation);
      return;
    }
    this.validation = '';
    this.onSave(url, this.appToken.trim(), this.model.trim());
  }

  build() {
    Column() {
      ImmersiveBackChrome({ title: 'AI 连接', closeIcon: true, onBack: this.onClose })

      Scroll() {
        Column({ space: 24 }) {
          Column({ space: 22 }) {
            this.field('网关地址', 'https://ai.example.com', this.gatewayUrl,
              (value: string) => this.gatewayUrl = value, InputType.Normal)
            this.field('应用访问令牌', '可选，不是 OpenAI 密钥', this.appToken,
              (value: string) => this.appToken = value, InputType.Password)
            this.field('模型', 'gpt-5.6-luna', this.model,
              (value: string) => this.model = value, InputType.Normal)
          }

          ImmersiveAction({
            label: '保存连接',
            actionAccessibilityText: '保存 AI 连接设置',
            icon: $r('sys.symbol.bookmark'),
            emphasized: true,
            onAction: () => this.save()
          })

          Column({ space: 14 }) {
            Row() {
              Text('隐私与许可')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
              Blank()
              SymbolGlyph(this.showLegal ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
                .fontSize(14)
                .fontColor([$r('app.color.ink_muted')])
            }
            .width('100%')
            .height(40)
            .onClick(() => this.showLegal = !this.showLegal)

            if (this.showLegal) {
              Text('AI 仅在主动调用时发送当前内容到所配置的网关。OpenAI 密钥不进入 App。')
                .fontSize(13)
                .lineHeight(21)
                .fontColor($r('app.color.ink_muted'))
              Text('语法为 CC BY 4.0；词汇上游许可与完整归属文件已随 App 打包。')
                .fontSize(13)
                .lineHeight(21)
                .fontColor($r('app.color.ink_muted'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ bottom: 36 })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24 })
        .margin({ left: 16, right: 16, top: 12, bottom: 18 })
        .alignItems(HorizontalAlign.Start)
        .borderRadius(30)
        .clip(true)
        .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private field(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, type: InputType) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_muted'))
      TextInput({ text: value, placeholder: placeholder })
        .type(type)
        .height(52)
        .fontSize(16)
        .fontColor($r('app.color.ink'))
        .placeholderColor($r('app.color.ink_muted'))
        .backgroundColor(Color.Transparent)
        .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
        .padding({ left: 2, right: 2 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .visualEffect(contentLightEffect())
  }
}
