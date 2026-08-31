import { MusicTrack } from '../../model/ContentModels';
import {
  emptyMusicPlaybackSnapshot,
  MusicPlaybackPhase,
  MusicPlaybackSnapshot
} from '../../model/MusicPlaybackModels';
import { planeLightEffect } from './ImmersiveCanvas';

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
          Image(this.artwork(this.track()?.id ?? ''))
            .width(48)
            .height(48)
            .borderRadius(15)
            .objectFit(ImageFit.Cover)
            .onClick(() => this.onOpen())

          Column({ space: 3 }) {
            Text(this.track()?.title ?? '')
              .width('100%')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.track()?.artist ?? '')
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.ink_muted'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => this.onOpen())

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            if (this.snapshot.phase === MusicPlaybackPhase.LOADING) {
              LoadingProgress()
                .width(22)
                .height(22)
                .color($r('app.color.ink'))
            } else {
              SymbolGlyph(this.playing() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(22)
                .fontColor([$r('app.color.ink')])
            }
          }
          .width(42)
          .height(42)
          .backgroundColor($r('app.color.immersive_plane_strong'))
          .accessibilityText(this.playing() ? '暂停' : '播放')
          .onClick(() => this.onToggle())

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.forward_end_fill'))
              .fontSize(21)
              .fontColor([$r('app.color.ink')])
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
      .width('calc(100% - 32vp)')
      .constraintSize({ maxWidth: 560 })
      .borderRadius(24)
      .clip(true)
      .backgroundEffect({
        radius: 34,
        color: $r('app.color.immersive_plane_strong'),
        saturation: 1.12
      })
      .border({ width: 0.5, color: $r('app.color.immersive_edge') })
      .shadow({ radius: 20, color: $r('app.color.journey_card_shadow'), offsetY: 8 })
      .visualEffect(planeLightEffect())
    }
  }
}
