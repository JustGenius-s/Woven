import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { BlurStrategy, DividerMode, HdsTabs } from '@kit.UIDesignKit';
import { FLOATING_TAB_CONTENT_INSET, MOTION_DURATION } from '../../common/AppTheme';
import { preferredImmersiveMaterial } from '../../common/ImmersiveMaterial';
import {
  LearningCatalog,
  MusicLine,
  MusicTrack,
  PracticeScenario,
  ReadingPassage,
  ReadingWork
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
  @State private readingWorks: ReadingWork[] = [];
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
      this.readingWorks = ContentRepository.loadReadingWorks(context);
      this.loadError = '';
    } catch (error) {
      this.catalog = undefined;
      this.musicTracks = [];
      this.readingWorks = [];
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

  private musicArtwork(trackId: string): Resource {
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

  private readingArtwork(readingId: string): Resource {
    switch (readingId) {
      case 'spiders-thread':
        return $r('app.media.reading_spiders_thread');
      case 'i-am-a-cat':
        return $r('app.media.reading_i_am_a_cat');
      case 'many-orders':
        return $r('app.media.reading_many_orders');
      case 'gon-fox':
        return $r('app.media.reading_gon_fox');
      default:
        return $r('app.media.reading_run_melos');
    }
  }

  private scenarioArtwork(scenarioId: string): Resource {
    switch (scenarioId) {
      case 'cafe':
        return $r('app.media.scenario_cafe');
      case 'directions':
        return $r('app.media.scenario_directions');
      case 'restaurant':
        return $r('app.media.scenario_restaurant');
      case 'small-talk':
        return $r('app.media.scenario_small_talk');
      default:
        return $r('app.media.scenario_opinion');
    }
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

  private selectedReading(): ReadingWork | undefined {
    if (this.detailKind !== 1 || this.detailIndex < 0 || this.detailIndex >= this.readingWorks.length) {
      return undefined;
    }
    return this.readingWorks[this.detailIndex];
  }

  private askMusicSelection(selection: string, track: MusicTrack, line?: MusicLine): void {
    const detail: string = line === undefined ?
      `曲目：${track.title}\n主题：${track.focus}\n等级：${track.level}` :
      `曲目：${track.title}\n原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`;
    this.onAsk(AiInquiryFactory.selection(selection, `音乐 · ${track.title}`, detail));
  }

  private askReadingSelection(selection: string, reading: ReadingWork, passage?: ReadingPassage): void {
    const detail: string = passage === undefined ?
      `作品：${reading.title}\n作者：${reading.author}\n简介：${reading.summary}` :
      `作品：${reading.title}\n作者：${reading.author}\n原文：${passage.text}\n学习提示：${passage.note}`;
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
      Image(this.musicArtwork(track.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0.24], ['#4D17181A', 0.56], ['#E617181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(track.level)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.immersive_light'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor('#6617181A')
          Blank()
          Text(`${track.lines.length} 句`)
            .fontSize(12)
            .fontColor($r('app.color.immersive_light'))
        }
        Blank()
        Text(track.title)
          .width('100%')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
        Text(`${track.chineseTitle} · ${track.artist}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#D9F7F8FA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(track.focus)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.music_note_circle_fill'))
              .fontSize(27)
              .fontColor([$r('app.color.ink')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.immersive_light'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 14 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(304)
    .borderRadius(28)
    .clip(true)
    .border({ width: this.musicIndex === index ? 1.5 : 0.5,
      color: this.musicIndex === index ? $r('app.color.accent') : $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${track.title}，${track.chineseTitle}，${track.level}`)
    .onClick(() => this.openMusic(index))
  }

  @Builder
  private readingPage() {
    Grid() {
      ForEach(this.readingWorks, (reading: ReadingWork, index: number) => {
        GridItem() {
          this.readingCard(reading, index)
        }
      }, (reading: ReadingWork) => reading.id)
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
  private readingCard(reading: ReadingWork, index: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.readingArtwork(reading.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0.28], ['#4217181A', 0.58], ['#E617181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(reading.genre)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.immersive_light'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor('#6617181A')
          Blank()
          Text(reading.level)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
        }
        Blank()
        Text(reading.title)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
        Text(`${reading.author} · ${reading.titleReading}`)
          .width('100%')
          .fontSize(13)
          .fontColor('#D9F7F8FA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Text(reading.summary)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#CCF7F8FA')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 5 })
        Row() {
          Text(`${reading.passages.length} 段节选`)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
          Blank()
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.book_pages_fill'))
              .fontSize(24)
              .fontColor([$r('app.color.ink')])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.immersive_light'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(284)
    .borderRadius(28)
    .clip(true)
    .border({ width: this.readingIndex === index ? 1.5 : 0.5,
      color: this.readingIndex === index ? $r('app.color.accent') : $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${reading.title}，${reading.author}，${reading.level}`)
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
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.scenarioArtwork(scenario.id))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0.22], ['#4D17181A', 0.52], ['#ED17181A', 1]]
        })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Row() {
          Text(scenario.level)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.immersive_light'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor('#6617181A')
          Blank()
          Text(scenario.setting)
            .fontSize(11)
            .fontColor('#D9F7F8FA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank()
        Text(scenario.title)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
        Text(`${scenario.learnerRole} × ${scenario.aiRole}`)
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#D9F7F8FA')
          .margin({ top: 5 })
        Text(scenario.goal)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#D9F7F8FA')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })
        Row() {
          if (this.scenarioIndex === index) {
            Text('上次进行')
              .fontSize(11)
              .fontColor($r('app.color.immersive_light'))
          }
          Blank()
          Button('开始', { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
            .controlSize(ControlSize.NORMAL)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.immersive_light'))
            .enabled(this.apiKeyConfigured)
            .onClick(() => this.startScenario(scenario, index))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 13 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
    }
    .width('100%')
    .height(304)
    .borderRadius(28)
    .clip(true)
    .border({ width: this.scenarioIndex === index ? 1.5 : 0.5,
      color: this.scenarioIndex === index ? $r('app.color.accent') : $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .accessibilityText(`${scenario.title}，${scenario.setting}，${scenario.level}`)
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
            Image(this.musicArtwork(this.selectedMusic()?.id ?? ''))
              .width('100%')
              .height(246)
              .borderRadius(26)
              .objectFit(ImageFit.Cover)
              .margin({ bottom: 15 })
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
            Image(this.readingArtwork(this.selectedReading()?.id ?? ''))
              .width('100%')
              .height(232)
              .borderRadius(26)
              .objectFit(ImageFit.Cover)
              .margin({ bottom: 15 })
            Text(`${this.selectedReading()?.genre ?? ''} · ${this.selectedReading()?.level ?? ''}`)
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
                  selection, this.selectedReading() as ReadingWork)))
            Text(`${this.selectedReading()?.author ?? ''} · ${this.selectedReading()?.titleReading ?? ''}`)
              .width('100%')
              .fontSize(14)
              .fontColor($r('app.color.accent'))
              .copyOption(CopyOptions.LocalDevice)
            Text(this.selectedReading()?.summary ?? '')
              .width('100%')
              .fontSize(14)
              .lineHeight(22)
              .fontColor($r('app.color.ink_muted'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 22, right: 22, top: 12, bottom: 22 })
        }

        ForEach(this.selectedReading()?.passages ?? [], (passage: ReadingPassage) => {
          ListItem() {
            Column({ space: 7 }) {
              Text(passage.text)
                .width('100%')
                .fontSize(21)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
                .lineHeight(31)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(passage.text,
                  (selection: string) => this.askReadingSelection(
                    selection, this.selectedReading() as ReadingWork, passage)))
              Text(passage.note)
                .width('100%')
                .fontSize(14)
                .lineHeight(22)
                .fontColor($r('app.color.ink_muted'))
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 22, right: 22, top: 18, bottom: 18 })
            .border({ width: { top: 0.5 }, color: $r('app.color.line') })
          }
        }, (passage: ReadingPassage) => passage.text)

        ListItem() {
          Column({ space: 7 }) {
            Text('内容来源')
              .width('100%')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent'))
            Text(this.selectedReading()?.sourceName ?? '')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .copyOption(CopyOptions.LocalDevice)
            Text(this.selectedReading()?.sourceUrl ?? '')
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.ink_muted'))
              .copyOption(CopyOptions.LocalDevice)
            Text(this.selectedReading()?.rights ?? '')
              .width('100%')
              .fontSize(12)
              .lineHeight(19)
              .fontColor($r('app.color.ink_muted'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 22, right: 22, top: 22, bottom: 36 })
          .border({ width: { top: 0.5 }, color: $r('app.color.line') })
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }
}
