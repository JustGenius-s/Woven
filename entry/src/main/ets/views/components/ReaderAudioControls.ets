import { immersiveFloatingPopupSurface } from '../../common/ImmersiveMaterial';
import { ReaderNavigation } from '../../services/ReaderNavigation';

/** The parent pins this control to the header's top-right corner using position(). */
@Component
export struct ReaderAudioControls {
  @Link @Watch('presentationChanged') expanded: boolean;
  @Prop @Watch('presentationChanged') overlayOpen: boolean = false;
  @Prop playing: boolean = false;
  @Prop ready: boolean = false;
  @Prop busy: boolean = false;
  @Prop positionMs: number = 0;
  @Prop durationMs: number = 0;
  @Prop availableWidth: number = 320;
  @Prop entryEndInset: number = 0;
  @Prop title: string = '原声朗读';
  @Prop previousLabel: string = '上一个';
  @Prop nextLabel: string = '下一个';
  @Prop canPrevious: boolean = false;
  @Prop canNext: boolean = false;
  @Prop hasTrackList: boolean = false;
  onToggle: () => void = () => {};
  onPrevious: () => void = () => {};
  onNext: () => void = () => {};
  onSeek: (positionMs: number) => void = (_positionMs: number) => {};
  onScrubbing: (scrubbing: boolean) => void = (_scrubbing: boolean) => {};
  onTrackList: () => void = () => {};

  @State private scrubbing: boolean = false;
  @State private previewMs: number = 0;

  aboutToDisappear(): void { this.presentationChanged(); }

  private setExpanded(): void {
    this.expanded = !this.expanded;
  }

  private presentationChanged(): void {
    this.scrubbing = false;
    this.onScrubbing(false);
  }

  private dismissPopup(action: DismissPopupAction): void {
    this.expanded = false;
    this.presentationChanged();
    action.dismiss();
  }

  private displayedPosition(): number {
    return this.scrubbing ? this.previewMs : this.positionMs;
  }

  private changePosition(value: number, mode: SliderChangeMode): void {
    // Dismissal or an overlaid sheet can end a drag before Slider's final event.
    if (!this.expanded || this.overlayOpen || !this.ready || this.busy || this.durationMs <= 0) {
      this.presentationChanged();
      return;
    }
    this.previewMs = Math.max(0, Math.min(value, this.durationMs));
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
      this.scrubbing = true;
      this.onScrubbing(true);
    } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.scrubbing = false;
      this.onScrubbing(false);
      this.onSeek(this.previewMs);
    }
  }

  @Builder
  private transportButton(kind: number) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(kind === 0 ? $r('sys.symbol.list_bullet') :
        (kind === 1 ? $r('sys.symbol.backward_end_fill') :
          (kind === 3 ? $r('sys.symbol.forward_end_fill') :
            (this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill')))))
        .fontSize(20)
        .fontColor([$r('sys.color.icon_primary')])
    }
    .id(kind === 0 ? 'reader-audio-list' :
      (kind === 1 ? 'reader-audio-previous' : (kind === 2 ? 'reader-audio-play' : 'reader-audio-next')))
    .width(44)
    .height(44)
    .backgroundColor(Color.Transparent)
    .opacity(this.busy || (kind === 1 && !this.canPrevious) || (kind === 3 && !this.canNext) ? 0.35 : 1)
    .enabled(!this.busy && (kind !== 1 || this.canPrevious) && (kind !== 3 || this.canNext))
    .accessibilityText(kind === 0 ? '选择课文音频' :
      (kind === 1 ? this.previousLabel : (kind === 3 ? this.nextLabel : (this.playing ? '暂停音频' : '播放音频'))))
    .onClick(() => {
      if (kind === 0) {
        this.onTrackList();
      } else if (kind === 1) {
        this.onPrevious();
      } else if (kind === 2) {
        this.onToggle();
      } else {
        this.onNext();
      }
    })
  }

  @Builder
  private timeline() {
    Column() {
      Slider({ value: this.displayedPosition(), min: 0, max: Math.max(1, this.durationMs),
        step: 100, style: SliderStyle.OutSet })
        .id('reader-audio-progress')
        .width('100%')
        .height(28)
        .trackThickness(3)
        .blockSize({ width: 10, height: 10 })
        .selectedColor($r('sys.color.icon_primary'))
        .blockColor($r('sys.color.icon_primary'))
        .trackColor($r('sys.color.ohos_id_color_component_normal'))
        .enabled(this.ready && this.durationMs > 0 && !this.busy)
        .accessibilityText(`音频进度 ${ReaderNavigation.time(this.displayedPosition())}，共 ${ReaderNavigation.time(this.durationMs)}`)
        .onChange((value: number, mode: SliderChangeMode) => this.changePosition(value, mode))
      Row() {
        Text(ReaderNavigation.time(this.displayedPosition()))
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
        Blank()
        Text(ReaderNavigation.time(this.durationMs))
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
    }
    .layoutWeight(1)
  }

  @Builder
  private expandedPanel() {
    Column() {
      Row() {
        Text(this.busy ? '正在准备音频…' : this.title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.hasTrackList) {
          this.transportButton(0)
        }
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_up'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .id('reader-audio-collapse')
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText('收起音频播放条')
        .onClick(() => this.setExpanded())
      }
      .width('100%')
      .height(44)
      Row({ space: 0 }) {
        this.transportButton(1)
        this.transportButton(2)
        this.transportButton(3)
        Blank().width(8)
        this.timeline()
      }
      .width('100%')
      .height(44)
    }
    // Popup owns the material. Its builder must not add a positioned/clipped root.
    .id('reader-audio-panel')
    .width(this.availableWidth)
    .height(112)
    .padding({ left: 14, right: 14, top: 8, bottom: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Button({ type: ButtonType.Circle }) {
        Stack() {
          Progress({ value: this.positionMs, total: Math.max(1, this.durationMs), type: ProgressType.Ring })
            .width(44)
            .height(44)
            .color($r('sys.color.icon_primary'))
            // Only the elapsed arc; no second ring track or decorative border.
            .backgroundColor(Color.Transparent)
            .style({ strokeWidth: 2, enableSmoothEffect: true })
            .hitTestBehavior(HitTestMode.None)
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(18)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(44)
        .height(44)
      }
      .id('reader-audio-expand')
      .width(44)
      .height(44)
      .position({ right: this.entryEndInset, top: 0 })
      .backgroundColor($r('app.color.immersive_plane'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
      .opacity(this.expanded ? 0 : 1)
      .hitTestBehavior(this.expanded ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(this.expanded ? 'no-hide-descendants' : 'auto')
      .accessibilityText(`展开音频播放条，${this.playing ? '正在播放' : '已暂停'}，${ReaderNavigation.time(this.positionMs)}`)
      .onClick(() => this.setExpanded())
    }
    // Align the popup to the page margin independently of adjacent entry buttons.
    // Keep this anchor visible even while the audio entry icon is hidden.
    .width(44 + this.entryEndInset)
    .height(44)
    .hitTestBehavior(HitTestMode.Transparent)
    .bindPopup(this.expanded && !this.overlayOpen, {
      builder: this.expandedPanel,
      placement: Placement.BottomRight,
      targetSpace: 12,
      width: this.availableWidth,
      radius: 24,
      enableArrow: false,
      mask: false,
      autoCancel: true,
      focusable: false,
      showInSubWindow: false,
      systemMaterial: immersiveFloatingPopupSurface().material,
      popupColor: immersiveFloatingPopupSurface().backgroundColor,
      backgroundBlurStyle: immersiveFloatingPopupSurface().blurStyle,
      transition: TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: -8 }))
        .animation({ duration: 250, curve: Curve.Friction }),
      onWillDismiss: (action: DismissPopupAction) => this.dismissPopup(action)
    })
  }
}
