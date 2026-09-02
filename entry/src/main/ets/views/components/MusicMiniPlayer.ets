import { uiMaterial } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MusicTrack } from '../../model/ContentModels';
import {
  emptyMusicPlaybackSnapshot,
  MusicPlaybackPhase,
  MusicPlaybackSnapshot
} from '../../model/MusicPlaybackModels';
import { MusicPlaybackService } from '../../services/MusicPlaybackService';

const DOMAIN: number = 0x4b4f;
const TAG: string = 'KotobaMusic';

// The mini bar reports two styles and the two have different heights. In the
// collapsed style the bar is the shorter of the two, so the artwork and
// controls step down to fit; the expanded style gets the full row and uses the
// regular sizes.
const ARTWORK_COMPACT: number = 36;
const ARTWORK_REGULAR: number = 48;
const BUTTON_COMPACT: number = 34;
const BUTTON_REGULAR: number = 42;
const GLYPH_COMPACT: number = 18;
const GLYPH_REGULAR: number = 22;
const ROW_COMPACT: number = 54;
const ROW_REGULAR: number = 66;
const CONTENT_ROW_COMPACT: number = 52;
const CONTENT_ROW_REGULAR: number = 64;
// One full turn of the artwork while playing.
const VINYL_SPIN_DURATION_MS: number = 9000;
const SHADOW_COLOR: string = '#33000000';
// The mini bar is custom content, so it can use uiMaterial directly and gets
// the auto-invert capability that HDS's hdsMaterial does not expose. Invert
// only kicks in for thin materials and only for the official special color
// resources, hence the sys.color.* foreground colors below.
const MINI_BAR_MATERIAL: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
  style: uiMaterial.ImmersiveStyle.THIN,
  colorInvert: true
});

/**
 * Static half of the mini bar: artwork and track text.
 *
 * The service emits a new snapshot on every timeUpdate (roughly twice a
 * second). Keeping this in its own component lets ArkUI skip it when only the
 * position or phase changed, which otherwise re-decodes the artwork on every
 * tick and makes it flicker.
 */
/**
 * The rotating artwork on its own.
 *
 * Rotation updates a @State on every frame during playback. Keeping just the
 * image in this component confines those rebuilds to the image itself, so the
 * track text around it is not torn down and rebuilt while the disc turns.
 */
@Component
struct SpinningArtwork {
  @Prop artwork: Resource = $r('app.media.music_look_at_stars');
  // Not named `size`: that is already a component attribute.
  @Prop artworkSize: number = 48;
  @Prop rotation: number = 0;
  @Prop compact: boolean = false;
  onOpen: () => void = () => {};

  build() {
    Image(this.artwork)
      .width(this.artworkSize)
      .height(this.artworkSize)
      // A disc is a circle: half the size, plus a soft drop shadow.
      .borderRadius(this.artworkSize / 2)
      .objectFit(ImageFit.Cover)
      .shadow({
        radius: this.compact ? 6 : 8,
        color: SHADOW_COLOR,
        offsetX: 0,
        offsetY: this.compact ? 1 : 2
      })
      .rotate({ angle: this.rotation })
      // Small local artwork: loading it synchronously on the main thread is
      // what the Image docs recommend when it flickers while reloading.
      .syncLoad(true)
      .onClick(() => this.onOpen())
  }
}

@Component
struct MiniBarTrackInfo {
  @Prop trackId: string = '';
  @Prop title: string = '';
  @Prop artist: string = '';
  @Prop artwork: Resource = $r('app.media.music_look_at_stars');
  @Prop compact: boolean = false;
  @Prop @Watch('onPlayingChange') playing: boolean = false;
  onOpen: () => void = () => {};

  // Accumulates rather than resetting, so each animation pass continues from
  // where the previous one ended and the disc never jumps back to zero.
  @State private rotation: number = 0;
  private spinning: boolean = false;

  private artworkSize(): number {
    return this.compact ? ARTWORK_COMPACT : ARTWORK_REGULAR;
  }

  onPlayingChange(): void {
    if (this.playing) {
      this.startSpin();
    } else {
      this.spinning = false;
    }
  }

  aboutToAppear(): void {
    if (this.playing) {
      this.startSpin();
    }
  }

  aboutToDisappear(): void {
    // Stop the recursion, otherwise onFinish keeps rescheduling after the
    // component is gone.
    this.spinning = false;
  }

  private startSpin(): void {
    if (this.spinning) {
      return;
    }
    this.spinning = true;
    this.spinStep();
  }

  private spinStep(): void {
    if (!this.spinning) {
      return;
    }
    animateTo({
      duration: VINYL_SPIN_DURATION_MS,
      curve: Curve.Linear,
      onFinish: () => {
        if (this.spinning) {
          this.spinStep();
        }
      }
    }, () => {
      this.rotation += 360;
    });
  }

  build() {
    Row({ space: this.compact ? 10 : 12 }) {
      SpinningArtwork({
        artwork: this.artwork,
        artworkSize: this.artworkSize(),
        rotation: this.rotation,
        compact: this.compact,
        onOpen: () => this.onOpen()
      })

      Column({ space: this.compact ? 2 : 3 }) {
        Text(this.title)
          .width('100%')
          .fontSize(this.compact ? 14 : 15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artist)
          .width('100%')
          .fontSize(this.compact ? 11 : 12)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.onOpen())
    }
    .width('100%')
  }
}

@Component
export struct MusicMiniPlayer {
  @Prop tracks: MusicTrack[] = [];
  @Prop @Watch('onSnapshotChange') snapshot: MusicPlaybackSnapshot = emptyMusicPlaybackSnapshot();
  // True when HdsTabs reports the collapsed style, which is the shorter of the
  // two. Drives the smaller artwork and control sizes.
  @Prop compact: boolean = false;
  onOpen: () => void = () => {};
  onToggle: () => void = () => {};
  onNext: () => void = () => {};

  // The bar owns its own live snapshot. HdsTabs rebuilds miniBarBuilder content
  // whenever the surrounding configuration object changes, so driving the bar
  // from a parent @State that updates every timeUpdate (~100ms) destroyed and
  // recreated it continuously — taps landed on an instance about to be thrown
  // away and were lost, and the artwork re-decoded each time. Subscribing here
  // keeps the parent out of the high-frequency path.
  @State private live: MusicPlaybackSnapshot = emptyMusicPlaybackSnapshot();
  private subscribed: boolean = false;

  private track(): MusicTrack | undefined {
    const index: number = this.live.trackIndex;
    if (index < 0 || index >= this.tracks.length) {
      return undefined;
    }
    return this.tracks[index];
  }

  private artwork(trackId: string): Resource {
    switch (trackId) {
      case 'morning-train':
        return $r('app.media.music_morning_train');
      case 'rain-cafe':
        return $r('app.media.music_rain_cafe');
      case 'small-trip':
        return $r('app.media.music_small_trip');
      case 'seaside-letter':
        return $r('app.media.music_seaside_letter');
      default:
        return $r('app.media.music_look_at_stars');
    }
  }

  private progressWidth(): string {
    if (this.live.durationMs <= 0) {
      return '0%';
    }
    const percent: number = Math.max(0, Math.min(100,
      this.live.positionMs * 100 / this.live.durationMs));
    return `${percent}%`;
  }

  private playing(): boolean {
    return this.live.phase === MusicPlaybackPhase.PLAYING;
  }

  private currentPhase(): number {
    return this.live.phase;
  }

  aboutToAppear(): void {
    this.live = this.snapshot;
    if (!this.subscribed) {
      this.subscribed = true;
      MusicPlaybackService.subscribe(this.listener);
    }
  }

  aboutToDisappear(): void {
    // The service holds the closure, so it must be removed — otherwise every
    // rebuild leaks a listener and stale bars keep receiving updates.
    MusicPlaybackService.unsubscribe(this.listener);
    this.subscribed = false;
  }

  private listener: (snapshot: MusicPlaybackSnapshot) => void = (snapshot: MusicPlaybackSnapshot) => {
    this.live = snapshot;
  };

  onSnapshotChange(): void {
    // Structural data comes from the parent; adopt it, then let the live
    // subscription carry position updates from here.
    this.live = this.snapshot;
  }

  build() {
    if (this.track() !== undefined) {
      Column() {
        Row({ space: 12 }) {
          MiniBarTrackInfo({
            trackId: this.track()?.id ?? '',
            title: this.track()?.title ?? '',
            artist: this.track()?.artist ?? '',
            artwork: this.artwork(this.track()?.id ?? ''),
            compact: this.compact,
            playing: this.playing(),
            onOpen: () => this.onOpen()
          })
          .layoutWeight(1)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            if (this.currentPhase() === MusicPlaybackPhase.LOADING) {
              LoadingProgress()
                .width(this.compact ? GLYPH_COMPACT : GLYPH_REGULAR)
                .height(this.compact ? GLYPH_COMPACT : GLYPH_REGULAR)
                .color($r('app.color.ink'))
            } else {
              SymbolGlyph(this.playing() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(this.compact ? GLYPH_COMPACT : GLYPH_REGULAR)
                .fontColor([$r('sys.color.icon_primary')])
            }
          }
          .width(this.compact ? BUTTON_COMPACT : BUTTON_REGULAR)
          .height(this.compact ? BUTTON_COMPACT : BUTTON_REGULAR)
          .backgroundColor($r('app.color.accent_soft'))
          .accessibilityText(this.playing() ? '暂停' : '播放')
          .onClick(() => {
            hilog.info(DOMAIN, TAG, 'miniBar toggle tapped: state=%{public}d', this.currentPhase());
            this.onToggle();
          })

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.forward_end_fill'))
              .fontSize(this.compact ? GLYPH_COMPACT - 1 : GLYPH_REGULAR - 1)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(this.compact ? BUTTON_COMPACT : BUTTON_REGULAR)
          .height(this.compact ? BUTTON_COMPACT : BUTTON_REGULAR)
          .backgroundColor(Color.Transparent)
          .accessibilityText('下一首')
          .onClick(() => this.onNext())
        }
        .width('100%')
        .height(this.compact ? CONTENT_ROW_COMPACT : CONTENT_ROW_REGULAR)
        .padding({ left: 8, right: 8 })

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(2)
            .backgroundColor($r('app.color.line'))
          Row()
            .width(this.progressWidth())
            .height(2)
            .backgroundColor($r('app.color.accent'))
        }
        .width('100%')
        .height(2)
      }
      .width('100%')
      .height(this.compact ? ROW_COMPACT : ROW_REGULAR)
      // systemMaterial must come after the other style attributes, otherwise
      // its priority is not what the caller expects.
      .systemMaterial(MINI_BAR_MATERIAL)
    }
  }
}
