import { common } from '@kit.AbilityKit';
import { applyReaderPaper } from '../../common/AppTheme';
import { GrammarAudioTrack, GrammarWork } from '../../model/GrammarModels';
import { GrammarBookService } from '../../services/GrammarBookService';
import {
  ReadingNarrationListener,
  ReadingNarrationService,
  ReadingNarrationSnapshot
} from '../../services/ReadingNarrationService';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { PdfReadingCanvas } from '../components/PdfReadingCanvas';

const EMPTY_LESSON: GrammarWork = {
  id: '',
  level: '',
  cefr: '',
  lessonNo: 0,
  title: '',
  titleJa: '',
  topic: '',
  summary: '',
  sourceName: '',
  sourceUrl: '',
  rights: '',
  pdfKey: '',
  pageCount: 0,
  audioTracks: [],
  sortOrder: 0
};

@Component
export struct GrammarLessonPage {
  lesson: GrammarWork = EMPTY_LESSON;
  onBack: () => void = () => {};

  @State private downloading: boolean = false;
  @State private downloadLabel: string = '';
  @State private failed: boolean = false;
  @State private failReason: string = '';
  @State private pdfPath: string = '';
  @State private trackIndex: number = 0;
  @State private trackSheetOpen: boolean = false;
  @State private playing: boolean = false;
  @State private audioReady: boolean = false;

  private leaving: boolean = false;
  private readonly onNarration: ReadingNarrationListener =
    (snapshot: ReadingNarrationSnapshot) => {
      this.playing = snapshot.playing;
      this.audioReady = snapshot.ready;
    };

  aboutToAppear(): void {
    applyReaderPaper(true);
    void this.openLesson();
  }

  aboutToDisappear(): void {
    this.leaving = true;
    applyReaderPaper(false);
    ReadingNarrationService.unsubscribe(this.onNarration);
    void ReadingNarrationService.release();
  }

  private hostContext(): common.Context {
    return this.getUIContext().getHostContext() as common.Context;
  }

  private lessonTitle(): string {
    if (this.lesson.lessonNo === 0) {
      return this.lesson.titleJa.length > 0 ? this.lesson.titleJa : this.lesson.title;
    }
    return `第${this.lesson.lessonNo}课`;
  }

  private lessonSubtitle(): string {
    const ja: string = this.lesson.titleJa;
    if (ja.length > 0 && this.lesson.lessonNo > 0) {
      return `${this.lesson.level} · ${ja}`;
    }
    return this.lesson.level;
  }

  private currentTrack(): GrammarAudioTrack | undefined {
    if (this.trackIndex < 0 || this.trackIndex >= this.lesson.audioTracks.length) {
      return undefined;
    }
    return this.lesson.audioTracks[this.trackIndex];
  }

  private trackLabel(): string {
    const track: GrammarAudioTrack | undefined = this.currentTrack();
    if (track === undefined) {
      return '这一课没有音频';
    }
    return `${this.trackIndex + 1}/${this.lesson.audioTracks.length}  ${track.title}`;
  }

  private async openLesson(): Promise<void> {
    this.downloading = true;
    this.downloadLabel = '正在准备教材…';
    this.failed = false;
    try {
      const files = await GrammarBookService.ensureLesson(
        this.hostContext(), this.lesson, (label: string) => {
          this.downloadLabel = label;
        });
      if (this.leaving) {
        return;
      }
      this.pdfPath = files.pdfPath;
      this.downloading = false;
      ReadingNarrationService.subscribe(this.onNarration);
      await this.prepareCurrentTrack();
    } catch (error) {
      this.failed = true;
      this.downloading = false;
      this.failReason = error instanceof Error ? error.message : `${error}`;
    }
  }

  private async prepareCurrentTrack(): Promise<void> {
    const track: GrammarAudioTrack | undefined = this.currentTrack();
    if (track === undefined) {
      return;
    }
    const path: string = GrammarBookService.localTrackPath(this.hostContext(), this.lesson, track);
    await ReadingNarrationService.prepare(this.hostContext(), path, track.durationMs);
  }

  private async toggleAudio(): Promise<void> {
    if (this.currentTrack() === undefined) {
      return;
    }
    if (!this.audioReady) {
      await this.prepareCurrentTrack();
    }
    await ReadingNarrationService.toggle();
  }

  private async selectTrack(index: number): Promise<void> {
    if (index < 0 || index >= this.lesson.audioTracks.length) {
      return;
    }
    this.trackIndex = index;
    this.trackSheetOpen = false;
    await ReadingNarrationService.release();
    ReadingNarrationService.subscribe(this.onNarration);
    await this.prepareCurrentTrack();
    await ReadingNarrationService.toggle();
  }

  private async stepTrack(delta: number): Promise<void> {
    const next: number = this.trackIndex + delta;
    if (next < 0 || next >= this.lesson.audioTracks.length) {
      return;
    }
    await this.selectTrack(next);
  }

  build() {
    Column() {
      ImmersiveBackChrome({
        title: this.lessonTitle(),
        subtitle: this.lessonSubtitle(),
        paper: true,
        onBack: this.onBack,
        pageContent: () => {
          this.pageBody()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .bindSheet($$this.trackSheetOpen, this.trackSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.BOTTOM,
      title: { title: '课文音频' },
      dragBar: true,
      showClose: true,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#52000000',
      onDisappear: () => this.trackSheetOpen = false
    })
  }

  @Builder
  private pageBody() {
    Column() {
      if (this.downloading) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(28)
            .height(28)
            .color($r('app.color.ink'))
          Text(this.downloadLabel)
            .fontSize(15)
            .fontColor($r('app.color.ink_muted'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.failed) {
        Text(this.failReason.length > 0 ? this.failReason : '教材加载失败')
          .width('100%')
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else if (this.pdfPath.length > 0) {
        PdfReadingCanvas({
          pdfPath: this.pdfPath,
          startPage: 0
        })
        .width('100%')
        .layoutWeight(1)
      } else {
        Blank()
          .layoutWeight(1)
      }
      this.controlBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  private controlBar() {
    Column() {
      Row({ space: 16 }) {
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(22)
          .fontColor([this.trackIndex > 0 ? $r('app.color.ink') : $r('app.color.ink_muted')])
          .onClick(() => {
            void this.stepTrack(-1);
          })
        SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .fontSize(30)
          .fontColor([$r('app.color.accent')])
          .onClick(() => {
            void this.toggleAudio();
          })
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(22)
          .fontColor([this.trackIndex + 1 < this.lesson.audioTracks.length ?
            $r('app.color.ink') : $r('app.color.ink_muted')])
          .onClick(() => {
            void this.stepTrack(1);
          })
        Text(this.trackLabel())
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => this.trackSheetOpen = true)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 18 })
    .backgroundColor($r('app.color.surface_raised'))
  }

  @Builder
  private trackSheet() {
    List({ space: 2 }) {
      ForEach(this.lesson.audioTracks, (track: GrammarAudioTrack, index: number) => {
        ListItem() {
          Row() {
            Text(track.title)
              .fontSize(16)
              .fontColor(this.trackIndex === index ? $r('app.color.accent') : $r('app.color.ink'))
              .layoutWeight(1)
            if (this.trackIndex === index) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(18)
                .fontColor([$r('app.color.accent')])
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          .onClick(() => {
            void this.selectTrack(index);
          })
        }
      }, (track: GrammarAudioTrack) => track.id)
    }
    .width('100%')
    .padding({ bottom: 24 })
  }
}
