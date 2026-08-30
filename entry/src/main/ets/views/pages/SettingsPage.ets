import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';

@Component
export struct SettingsPage {
  initialApiKey: string = '';
  onBack: () => void = () => {};
  onSave: (apiKey: string) => void = (apiKey: string) => {};

  @State private apiKey: string = '';
  @State private deepSeekSheetOpen: boolean = false;

  aboutToAppear(): void {
    this.apiKey = this.initialApiKey;
  }

  private normalizedApiKey(): string {
    return this.apiKey.trim();
  }

  private hasSavedApiKey(): boolean {
    return this.initialApiKey.trim().length > 0;
  }

  private canSave(): boolean {
    const value: string = this.normalizedApiKey();
    return value.length > 0 && value !== this.initialApiKey.trim();
  }

  private openDeepSeekSheet(): void {
    this.apiKey = this.initialApiKey;
    this.deepSeekSheetOpen = true;
  }

  private save(): void {
    const value: string = this.normalizedApiKey();
    if (value.length === 0) {
      showImmersiveNotice(this.getUIContext(), '还不能保存', '请输入 DeepSeek API Key');
      return;
    }
    this.onSave(value);
    this.deepSeekSheetOpen = false;
  }

  private removeApiKey(): void {
    this.apiKey = '';
    this.onSave('');
    this.deepSeekSheetOpen = false;
  }

  build() {
    Column() {
      ImmersiveBackChrome({ title: '设置', onBack: this.onBack })

      List() {
        ListItem() {
          Row() {
            Column() {
              this.deepSeekSection()
            }
            .width('100%')
            .constraintSize({ maxWidth: 560 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 40 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .bindSheet($$this.deepSeekSheetOpen, this.deepSeekSheet(), {
      height: SheetSize.FIT_CONTENT,
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      title: { title: 'DeepSeek' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#52000000',
      onDisappear: () => this.deepSeekSheetOpen = false
    })
  }

  @Builder
  private deepSeekSection() {
    Column({ space: 8 }) {
      Text('AI 功能')
        .width('100%')
        .padding({ left: 8 })
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_muted'))

      Column() {
        Row({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.key_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.accent')])

          Column({ space: 3 }) {
            Text('DeepSeek')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
            Text('API Key')
              .fontSize(13)
              .fontColor($r('app.color.ink_muted'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.hasSavedApiKey() ? '已配置' : '未配置')
            .fontSize(14)
            .fontColor(this.hasSavedApiKey() ? $r('app.color.success') : $r('app.color.ink_muted'))

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([$r('app.color.ink_muted')])
        }
        .width('100%')
        .height(72)
        .padding({ left: 18, right: 18 })
        .visualEffect(contentLightEffect())
        .accessibilityText(this.hasSavedApiKey() ? 'DeepSeek API Key，已配置' : 'DeepSeek API Key，未配置')
        .onClick(() => this.openDeepSeekSheet())
      }
      .width('100%')
      .borderRadius(24)
      .clip(true)
      .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane_strong'), saturation: 1.06 })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .visualEffect(planeLightEffect())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private deepSeekSheet() {
    Column({ space: 18 }) {
      Row() {
        Text('API Key')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
        Blank()
        Text(this.hasSavedApiKey() ? '已配置' : '未配置')
          .fontSize(14)
          .fontColor(this.hasSavedApiKey() ? $r('app.color.success') : $r('app.color.ink_muted'))
      }
      .width('100%')

      TextInput({ text: this.apiKey, placeholder: '请输入 API Key' })
        .type(InputType.Password)
        .showPasswordIcon(true)
        .height(52)
        .fontSize(16)
        .fontColor($r('app.color.ink'))
        .placeholderColor($r('app.color.ink_muted'))
        .caretColor($r('app.color.accent'))
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .maxLength(256)
        .onChange((value: string) => this.apiKey = value)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .fontSize(14)
          .fontColor([$r('app.color.ink_muted')])
        Text('仅保存在此设备，并在 AI 对练或询问学习内容时用于请求 DeepSeek。')
          .layoutWeight(1)
          .fontSize(13)
          .lineHeight(19)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Button('保存', { type: ButtonType.Capsule, stateEffect: true })
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.accent'))
        .enabled(this.canSave())
        .opacity(this.canSave() ? 1 : 0.42)
        .accessibilityText('保存 DeepSeek API Key')
        .onClick(() => this.save())

      if (this.hasSavedApiKey()) {
        Button('移除 API Key', { type: ButtonType.Capsule, stateEffect: true })
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.danger'))
          .backgroundColor(Color.Transparent)
          .accessibilityText('移除本地 DeepSeek API Key')
          .onClick(() => this.removeApiKey())
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: 560 })
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 8, bottom: 28 })
  }
}
