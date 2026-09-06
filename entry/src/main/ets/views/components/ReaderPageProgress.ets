import { FLOATING_ULTRA_THIN_MATERIAL } from '../../common/ImmersiveMaterial';
import { ReaderNavigation } from '../../services/ReaderNavigation';

/** Shared page progress for books and grammar PDFs. Only commit a jump on release. */
@Component
export struct ReaderPageProgress {
  @Prop pageIndex: number = 0;
  @Prop pageCount: number = 0;
  @Prop pageSpan: number = 1;
  @Prop ready: boolean = false;
  onJump: (index: number) => void = (_index: number) => {};
  onScrubbing: (scrubbing: boolean) => void = (_scrubbing: boolean) => {};
  @BuilderParam actions: () => void = this.noActions;
  @State private scrubbing: boolean = false;
  @State private previewIndex: number = 0;

  @Builder private noActions() {}

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

  build() {
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
            .height(28)
            .trackThickness(3)
            .blockSize({ width: 10, height: 10 })
            .selectedColor($r('sys.color.icon_primary'))
            .blockColor($r('sys.color.icon_primary'))
            .trackColor($r('sys.color.ohos_id_color_component_normal'))
            .enabled(this.ready)
            .accessibilityText(`页面进度 ${this.label()}，拖动跳页`)
            .onChange((value: number, mode: SliderChangeMode) => this.changePage(value, mode))
        } else {
          Progress({ value: this.pageCount > 0 ? 1 : 0, total: 1, type: ProgressType.Linear })
            .width('100%')
            .height(28)
            .style({ strokeWidth: 3 })
            .color($r('sys.color.icon_primary'))
            .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
        }
      }
      .layoutWeight(1)
      this.actions()
    }
    .id('reader-page-bar')
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 6 })
    .borderRadius(24)
    .backgroundColor(Color.Transparent)
    .systemMaterial(FLOATING_ULTRA_THIN_MATERIAL)
    .onClick(() => {})
  }
}
