import { window } from '@kit.ArkUI';
import { systemGestureInset } from '../../common/AppTheme';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import {
  CloudSyncPhase,
  CloudSyncSnapshot,
  HuaweiAccountPhase,
  HuaweiAccountSnapshot
} from '../../model/SyncModels';
import { DISTRIBUTED_SYNC_PERMISSION_REQUIRED } from '../../services/DistributedSyncPermission';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect } from '../components/ImmersiveCanvas';

const EMPTY_ACCOUNT: HuaweiAccountSnapshot = {
  phase: HuaweiAccountPhase.SIGNED_OUT,
  unionId: '',
  openId: '',
  detail: ''
};
const EMPTY_SYNC: CloudSyncSnapshot = {
  phase: CloudSyncPhase.LOCAL_ONLY,
  lastSyncedAt: 0,
  detail: ''
};

@Component
export struct SettingsPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  initialApiKey: string = '';
  initialMinimaxApiKey: string = '';
  @Prop account: HuaweiAccountSnapshot = EMPTY_ACCOUNT;
  @Prop syncState: CloudSyncSnapshot = EMPTY_SYNC;
  onBack: () => void = () => {};
  onSave: (apiKey: string) => void = (apiKey: string) => {};
  onSaveMinimax: (apiKey: string) => void = (apiKey: string) => {};
  onSync: () => void = () => {};

  @State private apiKey: string = '';
  @State private minimaxApiKey: string = '';
  @State private sheetOpen: boolean = false;
  @State private activeSheet: 'deepseek' | 'minimax' = 'deepseek';
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.apiKey = this.initialApiKey;
    this.minimaxApiKey = this.initialMinimaxApiKey;
  }

  private normalizedApiKey(): string {
    return this.apiKey.trim();
  }

  private normalizedMinimaxApiKey(): string {
    return this.minimaxApiKey.trim();
  }

  private hasSavedApiKey(): boolean {
    return this.initialApiKey.trim().length > 0;
  }

  private hasSavedMinimaxApiKey(): boolean {
    return this.initialMinimaxApiKey.trim().length > 0;
  }

  private canSave(): boolean {
    const value: string = this.normalizedApiKey();
    return value.length > 0 && value !== this.initialApiKey.trim();
  }

  private canSaveMinimax(): boolean {
    const value: string = this.normalizedMinimaxApiKey();
    return value.length > 0 && value !== this.initialMinimaxApiKey.trim();
  }

  private openDeepSeekSheet(): void {
    this.apiKey = this.initialApiKey;
    this.activeSheet = 'deepseek';
    this.sheetOpen = true;
  }

  private openMinimaxSheet(): void {
    this.minimaxApiKey = this.initialMinimaxApiKey;
    this.activeSheet = 'minimax';
    this.sheetOpen = true;
  }

  private save(): void {
    const value: string = this.normalizedApiKey();
    if (value.length === 0) {
      showImmersiveNotice(this.getUIContext(), '还不能保存', '请输入 DeepSeek API Key');
      return;
    }
    this.onSave(value);
    this.sheetOpen = false;
  }

  private saveMinimax(): void {
    const value: string = this.normalizedMinimaxApiKey();
    if (value.length === 0) {
      showImmersiveNotice(this.getUIContext(), '还不能保存', '请输入 MiniMax API Key');
      return;
    }
    this.onSaveMinimax(value);
    this.sheetOpen = false;
  }

  private removeApiKey(): void {
    this.apiKey = '';
    this.onSave('');
    this.sheetOpen = false;
  }

  private removeMinimaxApiKey(): void {
    this.minimaxApiKey = '';
    this.onSaveMinimax('');
    this.sheetOpen = false;
  }

  private canSync(): boolean {
    return this.account.phase === HuaweiAccountPhase.SIGNED_IN &&
      this.syncState.phase !== CloudSyncPhase.SYNCING;
  }

  private lastSyncTime(): string {
    return this.syncState.lastSyncedAt > 0 ?
      new Date(this.syncState.lastSyncedAt).toLocaleString() : '';
  }

  build() {
    Column() {
      ImmersiveBackChrome({
        title: '设置',
        onBack: this.onBack,
        scrollers: [this.pageScroller],
        pageContent: () => {
          this.pageContent()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .bindSheet($$this.sheetOpen, this.activeSheet === 'deepseek' ? this.deepSeekSheet() : this.minimaxSheet(), {
      height: SheetSize.FIT_CONTENT,
      detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
      preferType: SheetType.BOTTOM,
      title: { title: this.activeSheet === 'deepseek' ? 'DeepSeek' : 'MiniMax 语音' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#52000000',
      onDisappear: () => this.sheetOpen = false
    })
  }

  @Builder
  private pageContent() {
      List({ scroller: this.pageScroller }) {
        ListItem() {
          Row() {
            Column({ space: 24 }) {
              this.cloudSyncSection()
              this.deepSeekSection()
              this.ttsSection()
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
      .padding({ left: 16, right: 16, top: 20, bottom: 40 + systemGestureInset(this.avoidAreas) })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .clip(false)
  }

  @Builder
  private cloudSyncSection() {
    Column({ space: 8 }) {
      Text($r('app.string.cloud_space_section'))
        .width('100%')
        .padding({ left: 8 })
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_muted'))

      Column() {
        Row({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.icloud'))
            .fontSize(22)
            .fontColor([$r('app.color.accent')])

          Column({ space: 3 }) {
            Text($r('app.string.cloud_sync_title'))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
            this.syncStatus()
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.syncState.phase === CloudSyncPhase.SYNCING) {
            LoadingProgress()
              .width(22)
              .height(22)
              .color($r('app.color.accent'))
          } else if (this.canSync()) {
            Text($r('app.string.cloud_sync_now'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
          } else {
            SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
              .fontSize(19)
              .fontColor([$r('app.color.ink_muted')])
          }
        }
        .width('100%')
        .constraintSize({ minHeight: 76 })
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .visualEffect(contentLightEffect())
        .accessibilityText(this.canSync() ? $r('app.string.cloud_sync_now') :
          $r('app.string.cloud_sync_title'))
        .onClick(() => {
          if (this.canSync()) {
            this.onSync();
          }
        })

        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.line'))
          .margin({ left: 54 })

        Row({ space: 14 }) {
          SymbolGlyph($r('sys.symbol.translate_square_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.ink_muted')])
          Column({ space: 3 }) {
            Text($r('app.string.cloud_sync_scope_title'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
            Text($r('app.string.cloud_sync_scope_value'))
              .fontSize(13)
              .fontColor($r('app.color.ink_muted'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .constraintSize({ minHeight: 68 })
        .padding({ left: 18, right: 18, top: 10, bottom: 10 })
        .visualEffect(contentLightEffect())
      }
      .width('100%')
      .borderRadius(24)
      .clip(true)
      .backgroundColor($r('app.color.surface_raised'))

      Text($r('app.string.cloud_sync_privacy'))
        .width('100%')
        .padding({ left: 8, right: 8, top: 2 })
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('app.color.ink_muted'))

      if (this.account.phase !== HuaweiAccountPhase.SIGNED_IN) {
        Text($r('app.string.cloud_sync_sign_in_first'))
          .width('100%')
          .padding({ left: 8, right: 8 })
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private syncStatus() {
    if (this.syncState.phase === CloudSyncPhase.SYNCING) {
      Text($r('app.string.cloud_sync_syncing'))
        .fontSize(13)
        .fontColor($r('app.color.accent'))
    } else if (this.syncState.phase === CloudSyncPhase.SYNCED && this.lastSyncTime().length > 0) {
      Text($r('app.string.cloud_sync_last_time', this.lastSyncTime()))
        .fontSize(13)
        .fontColor($r('app.color.success'))
        .maxLines(2)
    } else if (this.syncState.phase === CloudSyncPhase.NEEDS_CONFIGURATION) {
      Text(this.syncState.detail === DISTRIBUTED_SYNC_PERMISSION_REQUIRED ?
        $r('app.string.cloud_sync_permission_required') :
        $r('app.string.cloud_sync_needs_configuration'))
        .fontSize(13)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(2)
    } else if (this.syncState.phase === CloudSyncPhase.ERROR) {
      Text($r('app.string.cloud_sync_error'))
        .fontSize(13)
        .fontColor($r('app.color.danger'))
    } else if (this.syncState.phase === CloudSyncPhase.LOCAL_ONLY) {
      Text($r('app.string.cloud_sync_local_only'))
        .fontSize(13)
        .fontColor($r('app.color.ink_muted'))
    } else {
      Text($r('app.string.cloud_sync_ready'))
        .fontSize(13)
        .fontColor($r('app.color.ink_muted'))
    }
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
      .constraintSize({ minHeight: 72 })
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .borderRadius(24)
      .backgroundColor($r('app.color.surface_raised'))
      .visualEffect(contentLightEffect())
      .accessibilityText(this.hasSavedApiKey() ? 'DeepSeek API Key，已配置' : 'DeepSeek API Key，未配置')
      .onClick(() => this.openDeepSeekSheet())
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
        Text('仅保存在此设备，并在 AI 场景或询问学习内容时用于请求 DeepSeek。')
          .layoutWeight(1)
          .fontSize(13)
          .lineHeight(19)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Button('保存', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
        .width('100%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .enabled(this.canSave())
        .accessibilityText('保存 DeepSeek API Key')
        .onClick(() => this.save())

      if (this.hasSavedApiKey()) {
        Button('移除 API Key', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
          .width('100%')
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.ERROR)
          .accessibilityText('移除本地 DeepSeek API Key')
          .onClick(() => this.removeApiKey())
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: 560 })
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 8, bottom: 28 })
  }

  @Builder
  private ttsSection() {
    Column({ space: 8 }) {
      Text('朗读')
        .width('100%')
        .padding({ left: 8 })
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_muted'))

      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.speaker_wave_2_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.accent')])

        Column({ space: 3 }) {
          Text('MiniMax 日语语音')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
          Text('云端合成，音质自然，需要联网')
            .fontSize(13)
            .fontColor($r('app.color.ink_muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.hasSavedMinimaxApiKey() ? '已配置' : '未配置')
          .fontSize(14)
          .fontColor(this.hasSavedMinimaxApiKey() ? $r('app.color.success') : $r('app.color.ink_muted'))

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('app.color.ink_muted')])
      }
      .width('100%')
      .constraintSize({ minHeight: 72 })
      .padding({ left: 18, right: 18, top: 10, bottom: 10 })
      .borderRadius(24)
      .backgroundColor($r('app.color.surface_raised'))
      .visualEffect(contentLightEffect())
      .accessibilityText(this.hasSavedMinimaxApiKey() ? 'MiniMax 语音，已配置' : 'MiniMax 语音，未配置')
      .onClick(() => this.openMinimaxSheet())

      Text('从 platform.minimaxi.com 获取 API Key。未配置时，点朗读没有声音。')
        .width('100%')
        .padding({ left: 8, right: 8, top: 2 })
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('app.color.ink_muted'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private minimaxSheet() {
    Column({ space: 18 }) {
      Row() {
        Text('API Key')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
        Blank()
        Text(this.hasSavedMinimaxApiKey() ? '已配置' : '未配置')
          .fontSize(14)
          .fontColor(this.hasSavedMinimaxApiKey() ? $r('app.color.success') : $r('app.color.ink_muted'))
      }
      .width('100%')

      TextInput({ text: this.minimaxApiKey, placeholder: '请输入 MiniMax API Key' })
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
        .onChange((value: string) => this.minimaxApiKey = value)

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .fontSize(14)
          .fontColor([$r('app.color.ink_muted')])
        Text('仅保存在此设备，用于请求 MiniMax 语音合成服务。')
          .layoutWeight(1)
          .fontSize(13)
          .lineHeight(19)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Button('保存', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
        .width('100%')
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .controlSize(ControlSize.NORMAL)
        .enabled(this.canSaveMinimax())
        .accessibilityText('保存 MiniMax API Key')
        .onClick(() => this.saveMinimax())

      if (this.hasSavedMinimaxApiKey()) {
        Button('移除 API Key', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
          .width('100%')
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.ERROR)
          .accessibilityText('移除本地 MiniMax API Key')
          .onClick(() => this.removeMinimaxApiKey())
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: 560 })
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 8, bottom: 28 })
  }
}
