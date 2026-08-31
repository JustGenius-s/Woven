import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { BlurStrategy, DividerMode, HdsTabs } from '@kit.UIDesignKit';
import { FLOATING_TAB_CONTENT_INSET, MOTION_DURATION } from '../../common/AppTheme';
import { preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';
import {
  Dialogue,
  DialogueLine,
  LearningCatalog,
  MusicLine,
  MusicTrack,
  PracticeScenario
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

@Component
export struct ExplorePage {
  @Prop selectedTab: number = 0;
  @Prop musicIndex: number = -1;
  @Prop readingIndex: number = -1;
  @Prop scenarioIndex: number = -1;
  apiKeyConfigured: boolean = false;
  onTabChange: (index: number) => void = (index: number) => {};
  onMusicChange: (index: number) => void = (index: number) => {};
  onReadingChange: (index: number) => void = (index: number) => {};
  onScenarioChange: (index: number) => void = (index: number) => {};
  onStartScenario: (scenario: PracticeScenario) => void = (scenario: PracticeScenario) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private catalog: LearningCatalog | undefined = undefined;
  @State private musicTracks: MusicTrack[] = [];
  @State private loadError: string = '';
  @State private pageWidth: number = 360;
  @State private detailOpen: boolean = false;
  @State private detailKind: number = 0;
  @State private detailIndex: number = -1;

  aboutToAppear(): void {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.catalog = ContentRepository.loadCatalog(context);
      this.musicTracks = ContentRepository.loadMusicTracks(context);
      this.loadError = '';
    } catch (error) {
      this.catalog = undefined;
      this.musicTracks = [];
      this.loadError = '探索内容没有正确载入';
    }
  }

  private columns(): string {
    return this.pageWidth >= 700 ? '1fr 1fr' : '1fr';
  }

  private updatePageWidth(width: Length): void {
    const next: number = typeof width === 'number' ? width : Number.parseFloat(width as string);
    if (!Number.isNaN(next) && next > 0) {
      this.pageWidth = next;
    }
  }

  private tone(index: number): ResourceColor {
    const tones: ResourceColor[] = [
      $r('app.color.word_card_blue'),
      $r('app.color.word_card_rose'),
      $r('app.color.word_card_green'),
      $r('app.color.word_card_cyan'),
      $r('app.color.word_card_violet'),
      $r('app.color.word_card_amber')
    ];
    return tones[index % tones.length];
  }

  private openMusic(index: number): void {
    this.detailKind = 0;
    this.detailIndex = index;
    this.onMusicChange(index);
    this.detailOpen = true;
  }

  private openReading(index: number): void {
    this.detailKind = 1;
    this.detailIndex = index;
    this.onReadingChange(index);
    this.detailOpen = true;
  }

  private startScenario(scenario: PracticeScenario, index: number): void {
    if (!this.apiKeyConfigured) {
      return;
    }
    this.onScenarioChange(index);
    this.onStartScenario(scenario);
  }

  private selectedMusic(): MusicTrack | undefined {
    if (this.detailKind !== 0 || this.detailIndex < 0 || this.detailIndex >= this.musicTracks.length) {
      return undefined;
    }
    return this.musicTracks[this.detailIndex];
  }

  private selectedReading(): Dialogue | undefined {
    const readings: Dialogue[] = this.catalog?.dialogues ?? [];
    if (this.detailKind !== 1 || this.detailIndex < 0 || this.detailIndex >= readings.length) {
      return undefined;
    }
    return readings[this.detailIndex];
  }

  private askMusicSelection(selection: string, track: MusicTrack, line?: MusicLine): void {
    const detail: string = line === undefined ?
      `曲目：${track.title}\n主题：${track.focus}\n等级：${track.level}` :
      `曲目：${track.title}\n原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`;
    this.onAsk(AiInquiryFactory.selection(selection, `音乐 · ${track.title}`, detail));
  }

  private askReadingSelection(selection: string, reading: Dialogue, line?: DialogueLine): void {
    const detail: string = line === undefined ?
      `阅读：${reading.title}\n场景：${reading.setting}\n目标：${reading.goal}` :
      `阅读：${reading.title}\n原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`;
    this.onAsk(AiInquiryFactory.selection(selection, `阅读 · ${reading.title}`, detail));
  }

  build() {
    Column() {
      PageChrome({ title: '探索', largeTitle: false })

      if (this.loadError.length > 0) {
        Text(this.loadError)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else {
        HdsTabs({ barPosition: BarPosition.Start, index: this.selectedTab }) {
          TabContent() {
            this.musicPage()
          }
          .tabBar(SubTabBarStyle.of('音乐'))

          TabContent() {
            this.readingPage()
          }
          .tabBar(SubTabBarStyle.of('阅读'))

          TabContent() {
            this.scenarioPage()
          }
          .tabBar(SubTabBarStyle.of('场景'))
        }
        .layoutWeight(1)
        .width('100%')
        .barMode(BarMode.Fixed)
        .scrollable(false)
        .animationDuration(MOTION_DURATION)
        .barBackgroundColor(Color.Transparent)
        .blurStrategy(BlurStrategy.ADAPTIVE)
        .divider({ mode: DividerMode.NONE })
        .barOverlap(false)
        .onChange((index: number) => this.onTabChange(index))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .onAreaChange((oldArea: Area, newArea: Area) => this.updatePageWidth(newArea.width))
    .bindSheet($$this.detailOpen, this.detailSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.BOTTOM,
      title: { title: this.detailKind === 0 ? '音乐' : '阅读' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#33202124',
      onDisappear: () => this.detailOpen = false
    })
  }

  @Builder
  private musicPage() {
    Grid() {
      ForEach(this.musicTracks, (track: MusicTrack, index: number) => {
        GridItem() {
          this.musicCard(track, index)
        }
      }, (track: MusicTrack) => track.id)
    }
    .columnsTemplate(this.columns())
    .columnsGap(14)
    .rowsGap(14)
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: FLOATING_TAB_CONTENT_INSET })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private musicCard(track: MusicTrack, index: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Text(track.title.slice(0, 1))
        .fontSize(132)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .opacity(0.055)
        .position({ x: 142, y: -26 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(track.level)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
          Blank()
          Text(track.duration)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
        }
        Blank()
        Text(track.title)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
        Text(`${track.chineseTitle} · ${track.artist}`)
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(track.focus)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          SymbolGlyph($r('sys.symbol.music_note_circle_fill'))
            .fontSize(34)
            .fontColor([$r('app.color.accent')])
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 16 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(22)
    }
    .width('100%')
    .height(210)
    .borderRadius(28)
    .clip(true)
    .linearGradient({
      angle: 155,
      colors: [[$r('app.color.immersive_plane_strong'), 0], [this.tone(index), 1]]
    })
    .border({ width: this.musicIndex === index ? 1.5 : 0.5,
      color: this.musicIndex === index ? $r('app.color.accent') : $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${track.title}，${track.chineseTitle}，${track.level}`)
    .onClick(() => this.openMusic(index))
  }

  @Builder
  private readingPage() {
    Grid() {
      ForEach(this.catalog?.dialogues ?? [], (reading: Dialogue, index: number) => {
        GridItem() {
          this.readingCard(reading, index)
        }
      }, (reading: Dialogue) => reading.id)
    }
    .columnsTemplate(this.columns())
    .columnsGap(14)
    .rowsGap(14)
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: FLOATING_TAB_CONTENT_INSET })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private readingCard(reading: Dialogue, index: number) {
    Column() {
      Row() {
        Text(reading.setting)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Blank()
        Text(reading.level)
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
      }
      Blank()
      Text(reading.title)
        .width('100%')
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(1)
      Text(reading.goal)
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 7 })
      Row() {
        Text(`${reading.lines.length} 段`)
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
        Blank()
        SymbolGlyph($r('sys.symbol.book_pages_fill'))
          .fontSize(24)
          .fontColor([$r('app.color.accent')])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 15 })
    }
    .width('100%')
    .height(184)
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .borderRadius(26)
    .clip(true)
    .backgroundEffect({ radius: 30, color: $r('app.color.immersive_plane_strong'), saturation: 1.06 })
    .border({ width: this.readingIndex === index ? 1.5 : 0.5,
      color: this.readingIndex === index ? $r('app.color.accent') : $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .onClick(() => this.openReading(index))
  }

  @Builder
  private scenarioPage() {
    Grid() {
      ForEach(this.catalog?.practiceScenarios ?? [], (scenario: PracticeScenario, index: number) => {
        GridItem() {
          this.scenarioCard(scenario, index)
        }
      }, (scenario: PracticeScenario) => scenario.id)
    }
    .columnsTemplate(this.columns())
    .columnsGap(14)
    .rowsGap(14)
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: FLOATING_TAB_CONTENT_INSET })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private scenarioCard(scenario: PracticeScenario, index: number) {
    Column() {
      Row() {
        Text(scenario.level)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
        Blank()
        Text(scenario.setting)
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(scenario.title)
        .width('100%')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(1)
        .margin({ top: 18 })
      Text(`${scenario.learnerRole} × ${scenario.aiRole}`)
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
        .margin({ top: 6 })
      Text(scenario.goal)
        .width('100%')
        .fontSize(13)
        .lineHeight(21)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10 })
      Blank()
      Row() {
        if (this.scenarioIndex === index) {
          Text('上次进行')
            .fontSize(11)
            .fontColor($r('app.color.success'))
        }
        Blank()
        Button('开始', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .enabled(this.apiKeyConfigured)
          .onClick(() => this.startScenario(scenario, index))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(228)
    .alignItems(HorizontalAlign.Start)
    .padding(21)
    .borderRadius(26)
    .clip(true)
    .linearGradient({
      angle: 160,
      colors: [[$r('app.color.immersive_plane_strong'), 0], [this.tone(index + 2), 1]]
    })
    .border({ width: this.scenarioIndex === index ? 1.5 : 0.5,
      color: this.scenarioIndex === index ? $r('app.color.accent') : $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
  }

  @Builder
  private detailSheet() {
    if (this.detailKind === 0) {
      this.musicDetail()
    } else {
      this.readingDetail()
    }
  }

  @Builder
  private musicDetail() {
    if (this.selectedMusic() !== undefined) {
      List({ space: 0 }) {
        ListItem() {
          Column({ space: 7 }) {
            Text(this.selectedMusic()?.title ?? '')
              .width('100%')
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.selectedMusic()?.title ?? '',
                (selection: string) => this.askMusicSelection(selection, this.selectedMusic() as MusicTrack)))
            Text(`${this.selectedMusic()?.chineseTitle ?? ''} · ${this.selectedMusic()?.artist ?? ''}`)
              .width('100%')
              .fontSize(14)
              .fontColor($r('app.color.ink_muted'))
            Text(this.selectedMusic()?.focus ?? '')
              .width('100%')
              .fontSize(13)
              .fontColor($r('app.color.accent'))
              .margin({ top: 5 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 22, right: 22, top: 12, bottom: 22 })
        }

        ForEach(this.selectedMusic()?.lines ?? [], (line: MusicLine) => {
          ListItem() {
            Column({ space: 7 }) {
              Text(line.text)
                .width('100%')
                .fontSize(21)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
                .lineHeight(31)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.text,
                  (selection: string) => this.askMusicSelection(
                    selection, this.selectedMusic() as MusicTrack, line)))
              Text(line.reading)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.accent'))
                .copyOption(CopyOptions.LocalDevice)
              Text(line.meaning)
                .width('100%')
                .fontSize(14)
                .fontColor($r('app.color.ink_muted'))
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 22, right: 22, top: 18, bottom: 18 })
            .border({ width: { top: 0.5 }, color: $r('app.color.line') })
          }
        }, (line: MusicLine) => line.text)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  private readingDetail() {
    if (this.selectedReading() !== undefined) {
      List({ space: 0 }) {
        ListItem() {
          Column({ space: 7 }) {
            Text(this.selectedReading()?.setting ?? '')
              .width('100%')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
            Text(this.selectedReading()?.title ?? '')
              .width('100%')
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.selectedReading()?.title ?? '',
                (selection: string) => this.askReadingSelection(
                  selection, this.selectedReading() as Dialogue)))
            Text(this.selectedReading()?.goal ?? '')
              .width('100%')
              .fontSize(14)
              .lineHeight(22)
              .fontColor($r('app.color.ink_muted'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 22, right: 22, top: 12, bottom: 22 })
        }

        ForEach(this.selectedReading()?.lines ?? [], (line: DialogueLine) => {
          ListItem() {
            Column({ space: 7 }) {
              Text(line.text)
                .width('100%')
                .fontSize(21)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
                .lineHeight(31)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.text,
                  (selection: string) => this.askReadingSelection(
                    selection, this.selectedReading() as Dialogue, line)))
              Text(line.reading)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.accent'))
                .copyOption(CopyOptions.LocalDevice)
              Text(line.meaning)
                .width('100%')
                .fontSize(14)
                .fontColor($r('app.color.ink_muted'))
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 22, right: 22, top: 18, bottom: 18 })
            .border({ width: { top: 0.5 }, color: $r('app.color.line') })
          }
        }, (line: DialogueLine) => `${line.speaker}-${line.text}`)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }
}
