import { uiMaterial } from '@kit.ArkUI';
import { MusicTrack } from '../../model/ContentModels';
import {
  emptyMusicPlaybackSnapshot,
  MusicPlaybackPhase,
  MusicPlaybackSnapshot
} from '../../model/MusicPlaybackModels';

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
@Component
struct MiniBarTrackInfo {
  @Prop trackId: string = '';
  @Prop title: string = '';
  @Prop artist: string = '';
  @Prop artwork: Resource = $r('app.media.music_look_at_stars');
  onOpen: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Image(this.artwork)
        .width(48)
        .height(48)
        .borderRadius(15)
        .objectFit(ImageFit.Cover)
        // Small local artwork: loading it synchronously on the main thread is
        // what the Image docs recommend when it flickers while reloading.
        .syncLoad(true)
        .onClick(() => this.onOpen())

      Column({ space: 3 }) {
        Text(this.title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.artist)
          .width('100%')
          .fontSize(12)
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
  @Prop snapshot: MusicPlaybackSnapshot = emptyMusicPlaybackSnapshot();
  onOpen: () => void = () => {};
  onToggle: () => void = () => {};
  onNext: () => void = () => {};

  private track(): MusicTrack | undefined {
    if (this.snapshot.trackIndex < 0 || this.snapshot.trackIndex >= this.tracks.length) {
      return undefined;
    }
    return this.tracks[this.snapshot.trackIndex];
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
    if (this.snapshot.durationMs <= 0) {
      return '0%';
    }
    const percent: number = Math.max(0, Math.min(100,
      this.snapshot.positionMs * 100 / this.snapshot.durationMs));
    return `${percent}%`;
  }

  private playing(): boolean {
    return this.snapshot.phase === MusicPlaybackPhase.PLAYING;
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
            onOpen: () => this.onOpen()
          })
          .layoutWeight(1)

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            if (this.snapshot.phase === MusicPlaybackPhase.LOADING) {
              LoadingProgress()
                .width(22)
                .height(22)
                .color($r('app.color.ink'))
            } else {
              SymbolGlyph(this.playing() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(22)
                .fontColor([$r('sys.color.icon_primary')])
            }
          }
          .width(42)
          .height(42)
          .backgroundColor($r('app.color.accent_soft'))
          .accessibilityText(this.playing() ? '暂停' : '播放')
          .onClick(() => this.onToggle())

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.forward_end_fill'))
              .fontSize(21)
              .fontColor([$r('sys.color.icon_primary')])
          }
          .width(42)
          .height(42)
          .backgroundColor(Color.Transparent)
          .accessibilityText('下一首')
          .onClick(() => this.onNext())
        }
        .width('100%')
        .height(64)
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
      .height(66)
      // systemMaterial must come after the other style attributes, otherwise
      // its priority is not what the caller expects.
      .systemMaterial(MINI_BAR_MATERIAL)
    }
  }
}
