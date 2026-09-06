import { common } from '@kit.AbilityKit';
import {
  FLOATING_IMMERSIVE_SURFACE, appSheetOptions, immersiveFloatingPopupSurface
} from '../../common/ImmersiveMaterial';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { RealtimeLine, RealtimeSnapshot, emptyRealtimeSnapshot } from '../../model/RealtimeVoiceModels';
import { GrammarRealtimeSession } from '../../services/GrammarRealtimeSession';
import { RealtimeVoicePreferences } from '../../services/RealtimeVoicePreferences';

@Component
export struct GrammarRealtimeButton {
  @Prop @Watch('contextChanged') pdfPath: string = '';
  @Prop @Watch('contextChanged') pageIndex: number = 0;
  @Prop pageCount: number = 0;
  @Prop title: string = '';
  @Prop ready: boolean = false;
  @Prop overlayOpen: boolean = false;
  onOpen: () => void = () => {};
  onBack: () => void = () => {};
  onSettings: (section: 'deepseek' | 'realtime') => void = () => {};
  onSessionReady: (session: GrammarRealtimeSession) => void = () => {};

  @State private sheetOpen: boolean = false;
  @State private panelVisible: boolean = false;
  @State private floating: boolean = false;
  @State private snapshot: RealtimeSnapshot = emptyRealtimeSnapshot();
  private session?: GrammarRealtimeSession;
  private scroller: Scroller = new Scroller();
  private leaving: boolean = false;
  private pendingSettings: boolean = false;

  aboutToAppear(): void {
    this.session = new GrammarRealtimeSession(this.context(), (snapshot: RealtimeSnapshot) => {
      if (this.leaving) { return; }
      const added: boolean = snapshot.lines.length > this.snapshot.lines.length;
      const newError: boolean = !!snapshot.error && snapshot.error !== this.snapshot.error;
      this.snapshot = snapshot;
      const active: boolean = snapshot.connecting || snapshot.connected;
      if (active !== this.floating) {
        this.getUIContext().animateTo({ duration: 250, curve: Curve.Friction }, () => {
          this.floating = active;
        });
      }
      if (newError && !this.sheetOpen) {
        showImmersiveNotice(this.getUIContext(), '语音伴读', snapshot.error);
      }
      if (added && this.sheetOpen) {
        setTimeout(() => {
          if (!this.leaving && this.sheetOpen) { this.scroller.scrollEdge(Edge.Bottom); }
        }, 80);
      }
    });
    this.onSessionReady(this.session);
  }

  aboutToDisappear(): void {
    this.leaving = true;
    this.floating = false;
    void this.session?.dispose();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private contextChanged(): void { void this.session?.stop(); }

  private startCall(): void {
    if (!this.ready || this.snapshot.connecting || this.snapshot.connected || this.leaving) { return; }
    try {
      if (!RealtimeVoicePreferences.read(this.context()).apiKey.trim()) {
        showImmersiveNotice(this.getUIContext(), '语音伴读', '请先在实时语音设置中填写 API Key');
        this.openSettings();
        return;
      }
    } catch (_error) {
      showImmersiveNotice(this.getUIContext(), '语音伴读', '暂时无法读取配置，请在设置中检查');
      this.openSettings();
      return;
    }
    this.onOpen();
    void this.session?.start(this.pdfPath, this.title, this.pageIndex);
  }

  private openPanel(): void {
    this.onOpen();
    this.panelVisible = true;
    this.sheetOpen = true;
    setTimeout(() => {
      if (!this.leaving && this.sheetOpen) { this.scroller.scrollEdge(Edge.Bottom); }
    }, 80);
  }

  private collapsePanel(): void {
    // The sheet only presents the conversation; it does not own the connection.
    this.sheetOpen = false;
  }

  private endCall(): void {
    void this.session?.stop(false);
    this.collapsePanel();
  }

  private openSettings(): void {
    void this.session?.stop(false);
    if (this.sheetOpen) {
      this.pendingSettings = true;
      this.collapsePanel();
    } else if (!this.leaving) {
      this.onSettings('realtime');
    }
  }

  private panelDisappeared(): void {
    this.collapsePanel();
    this.panelVisible = false;
    const settings: boolean = this.pendingSettings;
    this.pendingSettings = false;
    if (settings && !this.leaving) { this.onSettings('realtime'); }
  }

  private dismissFloating(action: DismissPopupAction): void {
    if (action.reason === DismissReason.PRESS_BACK) {
      // A nonmodal popup must preserve the reader's existing system-back action.
      this.floating = false;
      action.dismiss();
      this.onBack();
    }
  }

  private outputLabel(): string {
    return this.snapshot.speaking ? '讲解中' : (this.snapshot.responding ? '生成中' : '对话');
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.waveform_headphones'))
          .fontSize(22).fontColor([$r('sys.color.icon_primary')])
      }
      .id('grammar-realtime-open').width(44).height(44)
      // Page content is outside the native material scope; keep an explicit
      // readable entry surface. The active capsule gets its material from Popup.
      .backgroundColor($r('app.color.immersive_plane'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
      .enabled(this.ready && !this.floating)
      .opacity(this.floating || this.panelVisible ? 0 : (this.ready ? 1 : 0.4))
      .hitTestBehavior(this.floating || this.panelVisible ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(this.floating || this.panelVisible ? 'no-hide-descendants' : 'auto')
      .accessibilityText('开始本页实时语音通话')
      .accessibilityDescription('接通后共享麦克风声音和当前页教材，右侧显示通话控制')
      .onClick(() => this.startCall())
    }
    // The layout anchor stays enabled/visible when its entry button fades out.
    // Both overlay hosts stay on the page; the sheet is not inside the popup.
    .width(52).height(44).hitTestBehavior(HitTestMode.Transparent)
    .bindPopup(this.floating && !this.panelVisible && !this.overlayOpen, {
      builder: this.floatingControls,
      placement: Placement.BottomRight,
      targetSpace: 12,
      width: 52,
      radius: 26,
      enableArrow: false,
      mask: false,
      autoCancel: false,
      focusable: false,
      showInSubWindow: false,
      systemMaterial: immersiveFloatingPopupSurface().material,
      popupColor: immersiveFloatingPopupSurface().backgroundColor,
      backgroundBlurStyle: immersiveFloatingPopupSurface().blurStyle,
      transition: TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -8 }))
        .animation({ duration: 250, curve: Curve.Friction }),
      onWillDismiss: (action: DismissPopupAction) => this.dismissFloating(action)
    })
    .bindSheet($$this.sheetOpen, this.panel(), appSheetOptions({
      height: SheetSize.LARGE,
      title: { title: '语音伴读', subtitle: `PDF 第 ${this.pageIndex + 1} / ${this.pageCount} 页` },
      showClose: false,
      onWillDisappear: () => this.collapsePanel(),
      onDisappear: () => this.panelDisappeared()
    }))
  }

  @Builder
  private floatingControls() {
    Column({ space: 6 }) {
      Button({ type: ButtonType.Circle }) {
        if (this.snapshot.connecting) {
          LoadingProgress().width(22).height(22).color($r('sys.color.icon_primary'))
        } else {
          SymbolGlyph(this.snapshot.muted ? $r('sys.symbol.mic_slash_fill') : $r('sys.symbol.mic_fill'))
            .fontSize(22).fontColor([$r('sys.color.icon_primary')])
        }
      }
      .id('realtime-floating-mute').width(44).height(44).backgroundColor(Color.Transparent)
      .enabled(this.snapshot.connected && !this.snapshot.connecting)
      .accessibilityText(this.snapshot.connecting ? this.snapshot.status :
        (this.snapshot.muted ? '打开麦克风' : '静音麦克风'))
      .accessibilityDescription(this.snapshot.status)
      .onClick(() => { void this.session?.toggleMute(); })
      Button({ type: ButtonType.Circle }) {
        Column({ space: 2 }) {
          if (this.snapshot.responding && !this.snapshot.speaking) {
            LoadingProgress().width(18).height(18).color($r('sys.color.icon_primary'))
          } else {
            SymbolGlyph(this.snapshot.speaking ? $r('sys.symbol.waveform') : $r('sys.symbol.message_fill'))
              .fontSize(18).fontColor([$r('sys.color.icon_primary')])
              .symbolEffect(new PulseSymbolEffect(),
                this.snapshot.speaking && this.floating && !this.panelVisible && !this.overlayOpen)
          }
          Text(this.outputLabel()).fontSize(10).lineHeight(12)
            .fontColor($r('sys.color.font_primary')).maxLines(1)
        }.width(44).height(44).justifyContent(FlexAlign.Center)
      }
      .id('realtime-floating-panel').width(44).height(44).backgroundColor(Color.Transparent)
      .accessibilityText('打开语音对话面板')
      .accessibilityDescription(this.snapshot.speaking ? 'AI 正在讲解' :
        (this.snapshot.responding ? 'AI 正在生成回复' : this.snapshot.status))
      .onClick(() => this.openPanel())
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.phone_down_fill')).fontSize(22).fontColor([$r('app.color.danger')])
      }
      .id('realtime-floating-end').width(44).height(44).backgroundColor(Color.Transparent)
      .accessibilityText(this.snapshot.connecting ? '取消连接' : '挂断通话')
      .onClick(() => this.endCall())
    }
    .id('realtime-floating-controls').width(52).height(152).padding(4)
    // Popup owns the sole material rim. Its builder root must stay in normal flow.
  }

  @Builder
  private panel() {
    Column({ space: 16 }) {
      Row() {
        Text(this.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Button('设置').height(44).fontSize(14).fontColor($r('sys.color.font_secondary'))
          .backgroundColor(Color.Transparent).onClick(() => this.openSettings())
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(20).fontColor([$r('sys.color.icon_primary')])
        }
        .id('realtime-collapse').width(44).height(44).backgroundColor(Color.Transparent)
        .accessibilityText('收起面板，保持通话').onClick(() => this.collapsePanel())
      }.width('100%')
      this.conversation()
    }.width('100%').height('100%').padding({ left: 20, right: 20, bottom: 24 })
  }

  @Builder
  private conversation() {
    Scroll(this.scroller) {
      Column({ space: 20 }) {
        if (this.snapshot.lines.length === 0) {
          Column({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.waveform_headphones')).fontSize(38).fontColor([$r('sys.color.icon_secondary')])
            Text('这一页，我们一起聊').fontSize(21).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
            Text('接通后说“讲解这一页”，或直接提问。\n可以随时插话，不用反复点击录音。')
              .fontSize(14).lineHeight(22).textAlign(TextAlign.Center).fontColor($r('sys.color.font_secondary'))
          }.width('100%').padding({ top: 24, bottom: 24 })
        }
        ForEach(this.snapshot.lines, (line: RealtimeLine) => {
          Column({ space: 7 }) {
            Text(line.speaker).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%')
            Text(line.text).fontSize(16).lineHeight(26).fontColor($r('sys.color.font_primary'))
              .width('100%').copyOption(CopyOptions.LocalDevice)
          }.width('100%')
        }, (line: RealtimeLine) => line.id)
      }.width('100%').padding({ top: 4, bottom: 12 })
    }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    if (this.snapshot.error) {
      Text(this.snapshot.error).fontSize(13).fontColor($r('app.color.danger')).width('100%')
    }
    Row({ space: 8 }) {
      if (this.snapshot.connecting) {
        LoadingProgress().width(16).height(16).color($r('sys.color.icon_secondary'))
      } else {
        SymbolGlyph(this.snapshot.speaking ? $r('sys.symbol.waveform') : $r('sys.symbol.mic_fill'))
          .fontSize(16).fontColor([$r('sys.color.icon_secondary')])
          .opacity(this.snapshot.connected && !this.snapshot.muted ? 1 : 0.4)
      }
      Text(this.snapshot.status).fontSize(13).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
    }.width('100%')
    if (this.snapshot.connected && !this.snapshot.connecting) {
      Row({ space: 12 }) {
        Button(this.snapshot.muted ? '打开麦克风' : '静音')
          .id('realtime-mute').height(48).layoutWeight(1).fontSize(15)
          .fontColor($r('sys.color.font_primary')).attributeModifier(FLOATING_IMMERSIVE_SURFACE)
          .onClick(() => { void this.session?.toggleMute(); })
        Button('打断').id('realtime-interrupt').height(48).layoutWeight(1).fontSize(15)
          .fontColor($r('sys.color.font_primary')).attributeModifier(FLOATING_IMMERSIVE_SURFACE)
          .enabled(this.snapshot.speaking)
          .onClick(() => this.session?.interrupt())
        Button('挂断').id('realtime-end').height(48).layoutWeight(1).fontSize(15)
          .fontColor($r('app.color.danger')).attributeModifier(FLOATING_IMMERSIVE_SURFACE)
          .accessibilityText('挂断语音通话').onClick(() => this.endCall())
      }.width('100%')
    } else {
      Button(this.snapshot.connecting ? '取消连接' : '开始语音对话')
        .id('realtime-start').height(48).width('100%').fontSize(15)
        .fontColor($r('sys.color.font_primary')).attributeModifier(FLOATING_IMMERSIVE_SURFACE)
        .enabled(this.ready || this.snapshot.connecting)
        .onClick(() => {
          if (this.snapshot.connecting) { this.endCall(); }
          else { this.startCall(); }
        })
    }
    Text('收起面板后仍可继续对话。右侧可静音或挂断。通话时共享麦克风声音和教材文字。')
      .fontSize(11).lineHeight(17).fontColor($r('sys.color.font_secondary')).width('100%')
  }
}
