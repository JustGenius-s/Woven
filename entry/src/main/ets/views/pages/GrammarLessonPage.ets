import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { applyReaderPaper, statusBarInset, systemGestureInset } from '../../common/AppTheme';
import { appSheetOptions } from '../../common/ImmersiveMaterial';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { GrammarAudioTrack, GrammarWork } from '../../model/GrammarModels';
import { GrammarBookService } from '../../services/GrammarBookService';
import { GrammarRealtimeSession } from '../../services/GrammarRealtimeSession';
import { ReaderNavigation } from '../../services/ReaderNavigation';
import { PdfFitMode, ReaderPreferences } from '../../services/ReaderPreferences';
import {
  ReadingNarrationListener,
  ReadingNarrationService,
  ReadingNarrationSnapshot
} from '../../services/ReadingNarrationService';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { PdfReadingCanvas } from '../components/PdfReadingCanvas';
import { PdfFitModeSelector } from '../components/PdfFitModeSelector';
import { ReaderAudioControls } from '../components/ReaderAudioControls';
import { ReaderPageProgress } from '../components/ReaderPageProgress';
import { GrammarRealtimeButton } from '../components/GrammarRealtimeButton';

const EMPTY_LESSON: GrammarWork = {
  id: '', level: '', cefr: '', lessonNo: 0, title: '', titleJa: '', topic: '', summary: '',
  sourceName: '', sourceUrl: '', rights: '', pdfKey: '', pageCount: 0, audioTracks: [], sortOrder: 0
};

@Component
export struct GrammarLessonPage {
  @Env(SystemProperties.WINDOW_AVOID_AREA) private avoidAreas: window.UIEnvWindowAvoidAreaInfoVP;
  lesson: GrammarWork = EMPTY_LESSON;
  onBack: () => void = () => {};
  onSettings: (section: 'deepseek' | 'realtime') => void = () => {};

  @State private downloading: boolean = false;
  @State private downloadLabel: string = '';
  @State private failed: boolean = false;
  @State private failReason: string = '';
  @State private pdfPath: string = '';
  @State private pageIndex: number = 0;
  @State private pageCount: number = 0;
  @State private jumpPage: number = 0;
  @State private pdfReady: boolean = false;
  @State private viewportWidth: number = 360;
  @State private trackIndex: number = 0;
  @State private panelOpen: boolean = false;
  @State private panelVisible: boolean = false;
  @State private realtimePanelVisible: boolean = false;
  @State private panelKind: number = 0;
  @State private pdfFitMode: PdfFitMode = PdfFitMode.WIDTH;
  @State private audioExpanded: boolean = false;
  @State private playing: boolean = false;
  @State private audioReady: boolean = false;
  @State private audioBusy: boolean = false;
  @State private positionMs: number = 0;
  @State private durationMs: number = 0;

  private leaving: boolean = false;
  private realtime?: GrammarRealtimeSession;
  private activeAudioPath: string = '';
  private readonly onNarration: ReadingNarrationListener = (snapshot: ReadingNarrationSnapshot) => {
    if (this.leaving) {
      return;
    }
    if (snapshot.audioFile !== this.activeAudioPath) {
      this.playing = false;
      this.audioReady = false;
      this.positionMs = 0;
      return;
    }
    this.playing = snapshot.playing;
    this.audioReady = snapshot.ready;
    this.positionMs = snapshot.positionMs;
    this.durationMs = snapshot.durationMs;
  };

  aboutToAppear(): void {
    applyReaderPaper(true);
    this.pdfFitMode = ReaderPreferences.pdfFitMode(this.hostContext());
    this.pageCount = this.lesson.pageCount;
    this.pageIndex = Math.max(0, ReaderPreferences.progress(this.hostContext(), this.progressId()).resourceIndex);
    this.jumpPage = this.pageIndex;
    ReadingNarrationService.subscribe(this.onNarration);
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

  private progressId(): string {
    return `grammar_${this.lesson.id}`;
  }

  private lessonTitle(): string {
    return this.lesson.lessonNo === 0 ? (this.lesson.titleJa.length > 0 ? this.lesson.titleJa : this.lesson.title) :
      `第${this.lesson.lessonNo}课`;
  }

  private lessonSubtitle(): string {
    return this.lesson.titleJa.length > 0 && this.lesson.lessonNo > 0 ?
      `${this.lesson.level} · ${this.lesson.titleJa}` : this.lesson.level;
  }

  private currentTrack(): GrammarAudioTrack | undefined {
    return this.lesson.audioTracks[this.trackIndex];
  }

  private trackLabel(): string {
    const track: GrammarAudioTrack | undefined = this.currentTrack();
    return track === undefined ? '课文音频' : `${this.trackIndex + 1}/${this.lesson.audioTracks.length} · ${track.title}`;
  }

  private onPageChanged(index: number): void {
    this.pageIndex = ReaderNavigation.page(index, this.pageCount);
    this.jumpPage = this.pageIndex;
    ReaderPreferences.saveProgress(this.hostContext(), this.progressId(), {
      resourceIndex: this.pageIndex, domPos: '', pageOffset: 0
    });
  }

  private async openLesson(): Promise<void> {
    this.downloading = true;
    this.downloadLabel = '正在准备教材…';
    this.failed = false;
    try {
      const files = await GrammarBookService.ensureLesson(this.hostContext(), this.lesson, (label: string) => {
        if (!this.leaving) {
          this.downloadLabel = label;
        }
      });
      if (this.leaving) {
        return;
      }
      this.pdfPath = files.pdfPath;
      this.downloading = false;
    } catch (error) {
      if (!this.leaving) {
        this.failed = true;
        this.downloading = false;
        this.failReason = error instanceof Error ? error.message : `${error}`;
      }
      return;
    }
    this.audioBusy = true;
    try {
      await this.prepareCurrentTrack();
    } finally {
      this.audioBusy = false;
    }
  }

  private async prepareCurrentTrack(): Promise<boolean> {
    const track: GrammarAudioTrack | undefined = this.currentTrack();
    if (track === undefined || this.leaving) {
      return false;
    }
    this.activeAudioPath = GrammarBookService.localTrackPath(this.hostContext(), this.lesson, track);
    try {
      await ReadingNarrationService.prepare(this.hostContext(), this.activeAudioPath, track.durationMs);
      return !this.leaving && ReadingNarrationService.snapshot().ready;
    } catch (_error) {
      if (!this.leaving) {
        showImmersiveNotice(this.getUIContext(), '音频暂时无法播放', '请稍后重试，教材可以继续阅读');
      }
      return false;
    }
  }

  private async toggleAudio(): Promise<void> {
    if (this.currentTrack() === undefined || this.audioBusy || this.downloading || this.leaving) {
      return;
    }
    this.audioBusy = true;
    try {
      await this.realtime?.stop();
      if ((!this.audioReady || ReadingNarrationService.snapshot().audioFile !== this.activeAudioPath) &&
        !await this.prepareCurrentTrack()) {
        return;
      }
      if (!this.leaving) {
        await ReadingNarrationService.toggle();
      }
    } finally {
      this.audioBusy = false;
    }
  }

  private async selectTrack(index: number, autoplay: boolean): Promise<void> {
    if (index < 0 || index >= this.lesson.audioTracks.length || this.audioBusy || this.leaving) {
      return;
    }
    this.panelOpen = false;
    this.audioBusy = true;
    try {
      await this.realtime?.stop();
      await ReadingNarrationService.pause();
      if (this.leaving) {
        return;
      }
      this.trackIndex = index;
      this.playing = false;
      this.audioReady = false;
      this.positionMs = 0;
      this.durationMs = this.currentTrack()?.durationMs ?? 0;
      if (await this.prepareCurrentTrack() && autoplay && !this.leaving) {
        await ReadingNarrationService.play();
      }
    } finally {
      this.audioBusy = false;
    }
  }

  private async seekAudio(position: number): Promise<void> {
    if (this.audioReady && !this.audioBusy && !this.leaving &&
      ReadingNarrationService.snapshot().audioFile === this.activeAudioPath) {
      await ReadingNarrationService.seek(position);
    }
  }

  build() {
    Stack() {
      ImmersiveBackChrome({
        title: this.lessonTitle(),
        subtitle: this.lessonSubtitle(),
        paper: true,
        trailingSpace: this.lesson.audioTracks.length > 0 ? 128 : 72,
        onBack: this.onBack,
        pageContent: (): void => this.pageBody()
      })
      if (this.lesson.audioTracks.length > 0) {
        ReaderAudioControls({
          expanded: this.audioExpanded,
          overlayOpen: this.panelOpen || this.panelVisible,
          playing: this.playing,
          ready: this.audioReady,
          busy: this.audioBusy || this.downloading,
          positionMs: this.positionMs,
          durationMs: this.durationMs,
          availableWidth: this.viewportWidth - 32,
          entryEndInset: 56,
          title: this.trackLabel(),
          previousLabel: '上一个课文音频',
          nextLabel: '下一个课文音频',
          canPrevious: this.trackIndex > 0,
          canNext: this.trackIndex + 1 < this.lesson.audioTracks.length,
          hasTrackList: true,
          onToggle: () => { void this.toggleAudio(); },
          onPrevious: () => { void this.selectTrack(this.trackIndex - 1, this.playing); },
          onNext: () => { void this.selectTrack(this.trackIndex + 1, this.playing); },
          onSeek: (position: number) => { void this.seekAudio(position); },
          onTrackList: () => this.openReaderPanel(0)
        })
          .position({ right: 16, top: statusBarInset(this.avoidAreas) + 6 })
          .hitTestBehavior(HitTestMode.Transparent)
      }
      GrammarRealtimeButton({
        pdfPath: this.pdfPath,
        pageIndex: this.pageIndex,
        pageCount: this.pageCount,
        title: this.lesson.lessonNo === 0 ? this.lessonTitle() :
          `${this.lessonTitle()} · ${this.lesson.titleJa || this.lesson.title}`,
        ready: this.pdfReady && !this.failed && !this.downloading && !this.audioBusy,
        overlayOpen: this.panelOpen || this.panelVisible,
        onOpen: () => this.audioExpanded = false,
        onPanelVisibilityChanged: (visible: boolean) => this.realtimePanelVisible = visible,
        onBack: this.onBack,
        onSettings: this.onSettings,
        onSessionReady: (session: GrammarRealtimeSession) => this.realtime = session
      })
        .position({ right: 16, top: statusBarInset(this.avoidAreas) + 6 })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .backgroundColor(Color.White)
    .onAreaChange((_oldArea: Area, area: Area) => this.viewportWidth = Number(area.width))
    .bindSheet($$this.panelOpen, this.readerPanel(), appSheetOptions({
      height: this.panelKind === 0 ? SheetSize.LARGE : SheetSize.MEDIUM,
      title: { title: this.panelKind === 0 ? '课文音频' : '阅读设置' },
      showClose: true,
      onWillAppear: () => this.panelVisible = true,
      onDisappear: () => {
        this.panelOpen = false;
        this.panelVisible = false;
      }
    }))
  }

  @Builder
  private pageBody() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.downloading) {
        Column({ space: 10 }) {
          LoadingProgress().width(28).height(28).color($r('app.color.ink'))
          Text(this.downloadLabel).fontSize(15).fontColor($r('app.color.ink_muted'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.failed) {
        Text(this.failReason.length > 0 ? this.failReason : '教材加载失败')
          .width('100%')
          .height('100%')
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else if (this.pdfPath.length > 0) {
        PdfReadingCanvas({
          pdfPath: this.pdfPath,
          startPage: this.pageIndex,
          fitMode: this.pdfFitMode,
          jumpPage: this.jumpPage,
          onPageCountChanged: (count: number) => {
            this.pageCount = count;
            this.pdfReady = count > 0;
          },
          onPageChanged: (index: number) => this.onPageChanged(index),
          onFailed: (reason: string) => {
            this.pdfReady = false;
            this.failed = true;
            this.failReason = reason;
          }
        })
          .width('100%')
          .height('100%')
      }
      ReaderPageProgress({
        pageIndex: this.pageIndex,
        pageCount: this.pageCount,
        ready: this.pdfReady && !this.failed && !this.downloading,
        visible: !this.panelOpen && !this.panelVisible && !this.realtimePanelVisible,
        availableWidth: Math.min(640, this.viewportWidth - 32),
        onJump: (index: number) => this.onPageChanged(index),
        onBack: this.onBack,
        actions: (): void => this.readerTools()
      })
        .width(Math.min(640, this.viewportWidth - 32))
        .margin({ bottom: systemGestureInset(this.avoidAreas) + 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  private openReaderPanel(kind: number): void {
    this.panelKind = kind;
    this.audioExpanded = false;
    this.panelOpen = true;
  }

  private selectPdfFitMode(mode: PdfFitMode): void {
    this.pdfFitMode = mode;
    ReaderPreferences.savePdfFitMode(this.hostContext(), mode);
  }

  @Builder
  private readerTools() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(21).fontColor([$r('sys.color.icon_primary')])
    }
    .id('grammar-reader-settings')
    .width(44).height(44).backgroundColor(Color.Transparent)
    .accessibilityText('阅读设置')
    .onClick(() => this.openReaderPanel(1))
  }

  @Builder
  private readerPanel() {
    if (this.panelKind === 0) {
      this.trackSheet()
    } else {
      Column() {
        PdfFitModeSelector({
          fitMode: this.pdfFitMode,
          onChange: (mode: PdfFitMode) => this.selectPdfFitMode(mode)
        })
      }
      .width('100%').height('100%')
      .padding({ left: 22, right: 22, top: 14, bottom: 34 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private trackSheet() {
    List({ space: 2 }) {
      ForEach(this.lesson.audioTracks, (track: GrammarAudioTrack, index: number) => {
        ListItem() {
          Row() {
            Text(track.title)
              .fontSize(16)
              .fontColor(this.trackIndex === index ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
              .layoutWeight(1)
            if (this.trackIndex === index) {
              SymbolGlyph($r('sys.symbol.checkmark'))
                .fontSize(18)
                .fontColor([$r('sys.color.icon_primary')])
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 52 })
          .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          .enabled(!this.audioBusy)
          .onClick(() => { void this.selectTrack(index, true); })
        }
      }, (track: GrammarAudioTrack) => track.id)
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 24 })
  }
}
