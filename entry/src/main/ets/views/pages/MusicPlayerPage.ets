import { MusicLine, MusicTrack } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import {
  emptyMusicPlaybackSnapshot,
  MusicPlaybackPhase,
  MusicPlaybackSnapshot
} from '../../model/MusicPlaybackModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { planeLightEffect } from '../components/ImmersiveCanvas';

const RESPONSIVE_SPLIT_BREAKPOINT: number = 600;

@Component
export struct MusicPlayerPage {
  @Prop tracks: MusicTrack[] = [];
  @Prop snapshot: MusicPlaybackSnapshot = emptyMusicPlaybackSnapshot();
  onBack: () => void = () => {};
  onToggle: () => void = () => {};
  onPrevious: () => void = () => {};
  onNext: () => void = () => {};
  onSeek: (positionMs: number) => void = (positionMs: number) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private pageWidth: number = 360;
  private mobileScroller: Scroller = new Scroller();
  private lyricScroller: Scroller = new Scroller();

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

  private updatePageWidth(width: Length): void {
    const next: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    if (!Number.isNaN(next) && next > 0) {
      this.pageWidth = next;
    }
  }

  private splitLayout(): boolean {
    return this.pageWidth >= RESPONSIVE_SPLIT_BREAKPOINT;
  }

  private isPlaying(): boolean {
    return this.snapshot.phase === MusicPlaybackPhase.PLAYING;
  }

  private activeLineIndex(track: MusicTrack): number {
    let active: number = 0;
    for (let index: number = 0; index < track.lines.length; index++) {
      if (track.lines[index].startMs <= this.snapshot.positionMs) {
        active = index;
      } else {
        break;
      }
    }
    return active;
  }

  private formatTime(valueMs: number): string {
    const totalSeconds: number = Math.max(0, Math.floor(valueMs / 1000));
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private askSelection(selection: string, track: MusicTrack, line?: MusicLine): void {
    const detail: string = line === undefined ?
      `曲目：${track.title}\n主题：${track.focus}\n等级：${track.level}` :
      `曲目：${track.title}\n原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`;
    this.onAsk(AiInquiryFactory.selection(selection, `音乐 · ${track.title}`, detail));
  }

  build() {
    Stack() {
      if (this.track() !== undefined) {
        Image(this.artwork(this.track()?.id ?? ''))
          .width('116%')
          .height('116%')
          .objectFit(ImageFit.Cover)
          .blur(58)
          .opacity(0.24)
          .hitTestBehavior(HitTestMode.None)

        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [[$r('app.color.surface'), 0], [$r('app.color.surface'), 0.62],
              [$r('app.color.surface'), 1]]
          })
          .opacity(0.78)
          .hitTestBehavior(HitTestMode.None)

        ImmersiveBackChrome({
          title: '正在播放',
          subtitle: `${this.track()?.artist ?? ''} · 探索`,
          scrollers: [this.mobileScroller, this.lyricScroller],
          onBack: () => this.onBack(),
          pageContent: () => {
            if (this.splitLayout()) {
              this.wideLayout(this.track() as MusicTrack)
            } else {
              this.mobileLayout(this.track() as MusicTrack)
            }
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
    .onAreaChange((oldArea: Area, newArea: Area) => this.updatePageWidth(newArea.width))
  }

  @Builder
  private mobileLayout(track: MusicTrack) {
    Scroll(this.mobileScroller) {
      Column() {
        this.artworkBlock(track, 360)
        this.trackIdentity(track)
        this.transportControls()
        this.mobileLyrics(track)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 12, bottom: 42 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)
  }

  @Builder
  private wideLayout(track: MusicTrack) {
    Row({ space: 28 }) {
      Scroll(this.mobileScroller) {
        Column() {
          this.artworkBlock(track, 420)
          this.trackIdentity(track)
          this.transportControls()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 28, right: 8, top: 20, bottom: 32 })
      }
      .layoutWeight(46)
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .clip(false)

      Column() {
        Row() {
          Column({ space: 4 }) {
            Text('歌词与学习')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text(`${track.level} · ${track.focus}`)
              .fontSize(13)
              .fontColor($r('app.color.ink_muted'))
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
        }
        .width('100%')
        .padding({ left: 8, right: 28, top: 22, bottom: 12 })

        List({ scroller: this.lyricScroller, space: 8 }) {
          ForEach(track.lines, (line: MusicLine, index: number) => {
            ListItem() {
              this.lyricLine(track, line, index)
            }
          }, (line: MusicLine) => `${track.id}-${line.startMs}`)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 8, right: 28, bottom: 30 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(false)
      }
      .layoutWeight(54)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: 1180 })
    .align(Alignment.Center)
  }

  @Builder
  private artworkBlock(track: MusicTrack, maxSize: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.artwork(track.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column()
        .width('100%')
        .height('45%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0], ['#A617181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Text(track.focus)
        .fontSize(12)
        .fontColor('#F2FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .margin(18)
        .borderRadius(16)
        .backgroundColor('#6617181A')
    }
    .width('100%')
    .aspectRatio(1)
    .constraintSize({ maxWidth: maxSize, maxHeight: maxSize })
    .borderRadius(this.splitLayout() ? 32 : 28)
    .clip(true)
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .shadow({ radius: 28, color: $r('app.color.journey_card_shadow'), offsetY: 14 })
    .visualEffect(planeLightEffect())
  }

  @Builder
  private trackIdentity(track: MusicTrack) {
    Column({ space: 5 }) {
      Text(track.title)
        .width('100%')
        .fontSize(this.splitLayout() ? 32 : 30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(track.title,
          (selection: string) => this.askSelection(selection, track)))
      Text(`${track.chineseTitle} · ${track.artist}`)
        .width('100%')
        .fontSize(14)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .constraintSize({ maxWidth: 460 })
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 22 })
  }

  @Builder
  private transportControls() {
    Column({ space: 8 }) {
      Slider({
        value: this.snapshot.positionMs,
        min: 0,
        max: Math.max(1, this.snapshot.durationMs),
        step: 100,
        style: SliderStyle.InSet
      })
        .width('100%')
        .selectedColor($r('app.color.accent'))
        .blockColor($r('app.color.ink'))
        .trackColor($r('app.color.line'))
        .onChange((value: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.onSeek(value);
          }
        })

      Row() {
        Text(this.formatTime(this.snapshot.positionMs))
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
        Blank()
        Text(this.formatTime(this.snapshot.durationMs))
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')

      Row({ space: 24 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.backward_end_fill'))
            .fontSize(27)
            .fontColor([$r('app.color.ink')])
        }
        .width(50)
        .height(50)
        .backgroundColor(Color.Transparent)
        .accessibilityText('上一首')
        .onClick(() => this.onPrevious())

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          if (this.snapshot.phase === MusicPlaybackPhase.LOADING) {
            LoadingProgress()
              .width(30)
              .height(30)
              .color($r('app.color.immersive_light'))
          } else {
            SymbolGlyph(this.isPlaying() ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
              .fontSize(32)
              .fontColor([$r('app.color.immersive_light')])
          }
        }
        .width(70)
        .height(70)
        .backgroundColor($r('app.color.accent'))
        .shadow({ radius: 18, color: $r('app.color.accent_soft'), offsetY: 8 })
        .accessibilityText(this.isPlaying() ? '暂停' : '播放')
        .onClick(() => this.onToggle())

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(27)
            .fontColor([$r('app.color.ink')])
        }
        .width(50)
        .height(50)
        .backgroundColor(Color.Transparent)
        .accessibilityText('下一首')
        .onClick(() => this.onNext())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 6 })

      if (this.snapshot.phase === MusicPlaybackPhase.ERROR) {
        Text(`音频暂时无法播放 · ${this.snapshot.error}`)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: 460 })
    .margin({ top: 18 })
  }

  @Builder
  private mobileLyrics(track: MusicTrack) {
    Column({ space: 8 }) {
      Row() {
        Text('歌词与学习')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Blank()
        Text(track.level)
          .fontSize(12)
          .fontColor($r('app.color.accent'))
      }
      .width('100%')
      .margin({ top: 34, bottom: 6 })

      ForEach(track.lines, (line: MusicLine, index: number) => {
        this.lyricLine(track, line, index)
      }, (line: MusicLine) => `${track.id}-${line.startMs}`)
    }
    .width('100%')
    .constraintSize({ maxWidth: 520 })
  }

  @Builder
  private lyricLine(track: MusicTrack, line: MusicLine, index: number) {
    Column({ space: 6 }) {
      Text(line.text)
        .width('100%')
        .fontSize(this.activeLineIndex(track) === index ? 23 : 18)
        .fontWeight(this.activeLineIndex(track) === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.activeLineIndex(track) === index ? $r('app.color.ink') :
          $r('app.color.ink_muted'))
        .lineHeight(this.activeLineIndex(track) === index ? 33 : 28)
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(line.text,
          (selection: string) => this.askSelection(selection, track, line)))
      Text(line.reading)
        .width('100%')
        .fontSize(12)
        .fontColor(this.activeLineIndex(track) === index ? $r('app.color.accent') :
          $r('app.color.ink_muted'))
        .copyOption(CopyOptions.LocalDevice)
      Text(line.meaning)
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.ink_muted'))
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .borderRadius(22)
    .backgroundColor(this.activeLineIndex(track) === index ?
      $r('app.color.immersive_plane_strong') : Color.Transparent)
    .border({
      width: this.activeLineIndex(track) === index ? 0.5 : 0,
      color: $r('app.color.immersive_edge')
    })
    .visualEffect(this.activeLineIndex(track) === index ? planeLightEffect() : undefined)
    .accessibilityText(`${line.text}，${line.meaning}`)
    .onClick(() => this.onSeek(line.startMs))
  }
}
