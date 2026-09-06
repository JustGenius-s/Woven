import { immersiveFloatingPopupSurface } from '../../common/ImmersiveMaterial';
import { ReaderNavigation } from '../../services/ReaderNavigation';

/** Shared page progress for books and grammar PDFs. Only commit a jump on release. */
@Component
export struct ReaderPageProgress {
  @Prop pageIndex: number = 0;
  @Prop @Watch('cancelScrubbing') pageCount: number = 0;
  @Prop pageSpan: number = 1;
  @Prop @Watch('cancelScrubbing') ready: boolean = false;
  @Prop @Watch('cancelScrubbing') visible: boolean = true;
  @Prop @Watch('cancelScrubbing') availableWidth: number = 328;
  onJump: (index: number) => void = (_index: number) => {};
  onScrubbing: (scrubbing: boolean) => void = (_scrubbing: boolean) => {};
  onBack: () => void = () => {};
  @BuilderParam actions: () => void = this.noActions;
  @State private scrubbing: boolean = false;
  @State private previewIndex: number = 0;

  @Builder private noActions() {}

  aboutToDisappear(): void { this.cancelScrubbing(); }

  private cancelScrubbing(): void {
    if (!this.scrubbing) { return; }
    this.scrubbing = false;
    this.onScrubbing(false);
  }

  private dismissPopup(action: DismissPopupAction): void {
    if (action.reason === DismissReason.PRESS_BACK && this.visible) {
      this.cancelScrubbing();
      action.dismiss();
      this.onBack();
    }
  }

  private label(): string {
    if (this.pageCount <= 0) {
      return '— / —';
    }
    if (this.scrubbing) {
      return `${this.previewIndex + 1} / ${this.pageCount}`;
    }
    const first: number = this.pageIndex + 1;
    const last: number = Math.min(this.pageCount, first + this.pageSpan - 1);
    return `${first === last ? first : `${first}–${last}`} / ${this.pageCount}`;
  }

  private changePage(value: number, mode: SliderChangeMode): void {
    // A sheet can hide the popup before a pending Slider End event arrives.
    if (!this.visible || !this.ready || this.pageCount <= 1) {
      this.cancelScrubbing();
      return;
    }
    if (mode === SliderChangeMode.End && !this.scrubbing) { return; }
    this.previewIndex = ReaderNavigation.page(value - 1, this.pageCount);
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
      this.scrubbing = true;
      this.onScrubbing(true);
    } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.scrubbing = false;
      this.onScrubbing(false);
      this.onJump(this.previewIndex);
    }
  }

  @Builder
  private progressPanel() {
    Row({ space: 12 }) {
      Column({ space: 0 }) {
        Text(this.label())
          .id('reader-page-label')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        if (this.pageCount > 1) {
          Slider({ value: this.scrubbing ? this.previewIndex + 1 : this.pageIndex + 1,
            min: 1, max: this.pageCount, step: 1, style: SliderStyle.OutSet })
            .id('reader-page-progress')
            .width('100%')
            .height(40)
            .selectedColor($r('sys.color.icon_primary'))
            .trackColor($r('sys.color.ohos_id_color_component_normal'))
            .systemMaterial(immersiveFloatingPopupSurface().material)
            .enabled(this.ready)
            .accessibilityText(`页面进度 ${this.label()}，拖动跳页`)
            .onChange((value: number, mode: SliderChangeMode) => this.changePage(value, mode))
        } else {
          Progress({ value: this.pageCount > 0 ? 1 : 0, total: 1, type: ProgressType.Linear })
            .width('100%')
            .height(40)
            .style({ strokeWidth: 3 })
            .color($r('sys.color.icon_primary'))
            .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
        }
      }
      .layoutWeight(1)
      this.actions()
    }
    .id('reader-page-bar')
    .width(this.availableWidth)
    .padding({ left: 16, right: 16, top: 10, bottom: 6 })
    .onClick(() => {})
  }

  build() {
    // Keep only a layout anchor in the page. Popup owns the single material
    // backplate; an ordinary page Row is outside the native material scope.
    Stack() {}
      .id('reader-page-anchor')
      .width(this.availableWidth)
      .height(1)
      .hitTestBehavior(HitTestMode.Transparent)
      .bindPopup(this.visible, {
        builder: this.progressPanel,
        placement: Placement.Top,
        targetSpace: 0,
        width: this.availableWidth,
        radius: 24,
        enableArrow: false,
        mask: false,
        autoCancel: false,
        focusable: false,
        showInSubWindow: false,
        systemMaterial: immersiveFloatingPopupSurface().material,
        popupColor: immersiveFloatingPopupSurface().backgroundColor,
        backgroundBlurStyle: immersiveFloatingPopupSurface().blurStyle,
        transition: TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
          .animation({ duration: 220, curve: Curve.Friction }),
        onStateChange: (event) => { if (!event.isVisible) { this.cancelScrubbing(); } },
        onWillDismiss: (action: DismissPopupAction) => this.dismissPopup(action)
      })
  }
}
