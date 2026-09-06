import { FLOATING_ULTRA_THIN_MATERIAL } from '../../common/ImmersiveMaterial';
import { ReaderNavigation } from '../../services/ReaderNavigation';

/** The parent pins this control to the header's top-right corner using position(). */
@Component
export struct ReaderAudioControls {
  @Link @Watch('expansionChanged') expanded: boolean;
  @Prop playing: boolean = false;
  @Prop ready: boolean = false;
  @Prop busy: boolean = false;
  @Prop positionMs: number = 0;
  @Prop durationMs: number = 0;
  @Prop availableWidth: number = 320;
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
  @State private surfaceExpanded: boolean = false;

  aboutToAppear(): void {
    this.surfaceExpanded = this.expanded;
  }

  private panelWidth(): number {
    return Math.min(360, this.availableWidth);
  }

  private setExpanded(): void {
    this.expanded = !this.expanded;
  }

  private expansionChanged(): void {
    this.scrubbing = false;
    this.onScrubbing(false);
    // One persistent surface: size, position and corners travel together and
    // reverse from their current values when the user interrupts the motion.
    this.getUIContext().animateTo({ duration: 250, curve: Curve.Friction }, () => {
      this.surfaceExpanded = this.expanded;
    });
  }

  private displayedPosition(): number {
    return this.scrubbing ? this.previewMs : this.positionMs;
  }

  private changePosition(value: number, mode: SliderChangeMode): void {
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

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.surfaceExpanded) {
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
          .id('reader-audio-panel')
          .width(this.panelWidth())
          .height(112)
          .padding({ left: 14, right: 14, top: 8, bottom: 16 })
          .position({ right: 0, top: 0 })
          // Keep text/icons at their final size while the container reveals them.
          // Unlike the shared surface, these are entering / leaving elements.
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 150, delay: 70, curve: Curve.Linear }),
            TransitionEffect.OPACITY.animation({ duration: 80, curve: Curve.Linear })
          ))
        } else {
          Button({ type: ButtonType.Circle }) {
            Stack() {
              Progress({ value: this.positionMs, total: Math.max(1, this.durationMs), type: ProgressType.Ring })
                .width(44)
                .height(44)
                .color($r('sys.color.icon_primary'))
                // The material already supplies the outline. Draw only the
                // elapsed arc on that edge, rather than a second inset track.
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
          .backgroundColor(Color.Transparent)
          .position({ top: 0, right: 0 })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 80, delay: 120, curve: Curve.Linear }),
            TransitionEffect.OPACITY.animation({ duration: 80, curve: Curve.Linear })
          ))
          .accessibilityText(`展开音频播放条，${this.playing ? '正在播放' : '已暂停'}，${ReaderNavigation.time(this.positionMs)}`)
          .onClick(() => this.setExpanded())
        }
      }
      .id('reader-audio-surface')
      .width(this.surfaceExpanded ? this.panelWidth() : 44)
      .height(this.surfaceExpanded ? 112 : 44)
      .borderRadius(this.surfaceExpanded ? 24 : 22)
      .backgroundColor(Color.Transparent)
      .systemMaterial(FLOATING_ULTRA_THIN_MATERIAL)
      .clip(true)
      .position({ right: 0, top: this.surfaceExpanded ? 56 : 0 })
      .onClick(() => {})
    }
    // Reserve a stable overlay envelope; only the visible surface takes input.
    .width(this.panelWidth())
    .height(168)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
