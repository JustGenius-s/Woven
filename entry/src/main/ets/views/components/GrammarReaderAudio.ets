import { common } from '@kit.AbilityKit';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { GrammarAudioTrack, GrammarWork } from '../../model/GrammarModels';
import { GrammarBookService } from '../../services/GrammarBookService';
import { ReadingNarrationService, ReadingNarrationSnapshot } from '../../services/ReadingNarrationService';
import { ReaderAudioControls } from './ReaderAudioControls';

/** Lesson audio on the native reader; downloads are independent of book loading. */
@Component
export struct GrammarReaderAudio {
  lesson: GrammarWork | undefined = undefined;
  @Prop overlayOpen: boolean = false;
  @Prop availableWidth: number = 320;
  @State private expanded: boolean = false;
  @State private tracksOpen: boolean = false;
  @State private trackIndex: number = 0;
  @State private busy: boolean = false;
  @State private playing: boolean = false;
  @State private ready: boolean = false;
  @State private positionMs: number = 0;
  @State private durationMs: number = 0;
  private leaving: boolean = false;
  private audioPath: string = '';
  private onNarration: (snapshot: ReadingNarrationSnapshot) => void = (snapshot: ReadingNarrationSnapshot) => {
    if (this.leaving) { return; }
    const ownsAudio: boolean = this.audioPath.length > 0 && snapshot.audioFile === this.audioPath;
    this.playing = ownsAudio && snapshot.playing;
    this.ready = ownsAudio && snapshot.ready;
    this.positionMs = ownsAudio ? snapshot.positionMs : 0;
    this.durationMs = ownsAudio ? snapshot.durationMs : 0;
  };

  aboutToAppear(): void {
    ReadingNarrationService.subscribe(this.onNarration);
  }

  aboutToDisappear(): void {
    this.leaving = true;
    ReadingNarrationService.unsubscribe(this.onNarration);
    void ReadingNarrationService.release();
  }

  private tracks(): GrammarAudioTrack[] { return this.lesson?.audioTracks ?? []; }

  private async prepare(): Promise<boolean> {
    const lesson: GrammarWork | undefined = this.lesson;
    const track: GrammarAudioTrack | undefined = this.tracks()[this.trackIndex];
    if (lesson === undefined || track === undefined || this.leaving) { return false; }
    const context = this.getUIContext().getHostContext() as common.Context;
    const path: string = await GrammarBookService.ensureTrack(context, lesson, track);
    if (this.leaving) { return false; }
    this.audioPath = path;
    await ReadingNarrationService.prepare(context, path, track.durationMs);
    if (this.leaving) { return false; }
    if (!ReadingNarrationService.snapshot().ready) { throw new Error('音频尚未就绪'); }
    return true;
  }

  private async playTrack(index: number, toggle: boolean): Promise<void> {
    if (this.busy || this.leaving || index < 0 || index >= this.tracks().length) { return; }
    this.tracksOpen = false;
    this.busy = true;
    try {
      if (index !== this.trackIndex) {
        await ReadingNarrationService.pause();
        this.trackIndex = index;
        this.audioPath = '';
        this.ready = false;
        this.playing = false;
        this.positionMs = 0;
        this.durationMs = 0;
      }
      if (await this.prepare()) {
        if (toggle) { await ReadingNarrationService.toggle(); }
        else { await ReadingNarrationService.play(); }
      }
    } catch (_error) {
      if (!this.leaving) {
        showImmersiveNotice(this.getUIContext(), '音频暂时无法播放', '请检查网络后重试，教材可以继续阅读。');
      }
    } finally {
      if (!this.leaving) { this.busy = false; }
    }
  }

  private seek(positionMs: number): void {
    if (!this.leaving && !this.busy && this.ready &&
      ReadingNarrationService.snapshot().audioFile === this.audioPath) {
      void ReadingNarrationService.seek(positionMs);
    }
  }

  @Builder
  private trackSheet() {
    List({ space: 2 }) {
      ForEach(this.tracks(), (track: GrammarAudioTrack, index: number) => {
        ListItem() {
          Row() {
            Text(track.title).fontSize(16).layoutWeight(1)
              .fontColor($r('sys.color.font_primary'))
            if (this.trackIndex === index) {
              SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18)
            }
          }
          .width('100%').constraintSize({ minHeight: 52 })
          .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          .enabled(!this.busy)
          .onClick(() => { void this.playTrack(index, false); })
        }
      }, (track: GrammarAudioTrack) => track.id)
    }.width('100%').height('100%').padding({ bottom: 24 })
  }

  build() {
    ReaderAudioControls({
      expanded: $expanded,
      overlayOpen: this.overlayOpen || this.tracksOpen,
      playing: this.playing, ready: this.ready, busy: this.busy,
      positionMs: this.positionMs, durationMs: this.durationMs,
      availableWidth: this.availableWidth,
      title: `${this.trackIndex + 1}/${this.tracks().length} · ${this.tracks()[this.trackIndex]?.title ?? '课文音频'}`,
      previousLabel: '上一个课文音频', nextLabel: '下一个课文音频',
      canPrevious: this.trackIndex > 0, canNext: this.trackIndex + 1 < this.tracks().length,
      hasTrackList: true,
      onToggle: () => { void this.playTrack(this.trackIndex, true); },
      onPrevious: () => { void this.playTrack(this.trackIndex - 1, false); },
      onNext: () => { void this.playTrack(this.trackIndex + 1, false); },
      onSeek: (positionMs: number) => this.seek(positionMs),
      onTrackList: () => { this.expanded = false; this.tracksOpen = true; }
    })
    .bindSheet($$this.tracksOpen, this.trackSheet(), {
      height: SheetSize.LARGE, title: { title: '课文音频' }, showClose: true,
      backgroundColor: $r('app.color.surface_raised')
    })
  }
}
