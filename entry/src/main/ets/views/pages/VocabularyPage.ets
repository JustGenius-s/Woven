import { common } from '@kit.AbilityKit';
import { HdsListItem } from '@kit.UIDesignKit';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { LearningJourney, VocabularyEntry } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { VocabularyDataSource } from '../../services/VocabularyDataSource';
import { AiAskAction } from '../components/AiAskAction';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';

@Component
export struct VocabularyPage {
  journey: LearningJourney | undefined = undefined;
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};

  @State private level: string = 'N5';
  @State private source: VocabularyEntry[] = [];
  @State private query: string = '';
  @State private focusWord: VocabularyEntry | undefined = undefined;
  @State private selectedInquiryKey: string = '';
  @State private loadError: string = '';
  @State private journeyOnly: boolean = false;
  private dataSource: VocabularyDataSource = new VocabularyDataSource();

  aboutToAppear(): void {
    if (this.journey !== undefined) {
      this.journeyOnly = true;
      this.loadLevel(this.journey.vocabularyLevel);
    } else {
      this.loadLevel(this.level);
    }
  }

  private loadLevel(level: string): void {
    try {
      this.level = level;
      this.source = ContentRepository.loadVocabulary(
        this.getUIContext().getHostContext() as common.Context, level);
      this.focusWord = this.source.length > 0 ? this.source[0] : undefined;
      this.loadError = '';
      this.applyFilter();
    } catch (error) {
      this.loadError = `${level} 词库没有正确载入`;
      this.source = [];
      this.dataSource.reset([]);
    }
  }

  private applyFilter(): void {
    const needle: string = this.query.trim().toLowerCase();
    const filtered: VocabularyEntry[] = [];
    for (let index: number = 0; index < this.source.length; index++) {
      const item: VocabularyEntry = this.source[index];
      const meaning: string = item.meanings.join(' ');
      const belongsToJourney: boolean = this.journey === undefined ||
        this.journey.wordIds.includes(item.id);
      const matchesQuery: boolean = needle.length === 0 ||
        `${item.word}\n${item.reading}\n${meaning}`.toLowerCase().includes(needle);
      if ((!this.journeyOnly || belongsToJourney) && matchesQuery) {
        filtered.push(item);
      }
    }
    this.dataSource.reset(filtered);
    this.focusWord = filtered.length > 0 ? filtered[0] : undefined;
    this.selectedInquiryKey = '';
  }

  private wordInquiryKey(item: VocabularyEntry): string {
    return `word-${item.id}`;
  }

  private exampleInquiryKey(item: VocabularyEntry): string {
    return `example-${item.id}`;
  }

  private toggleInquirySelection(key: string): void {
    this.selectedInquiryKey = this.selectedInquiryKey === key ? '' : key;
  }

  private selectWord(item: VocabularyEntry): void {
    this.focusWord = item;
    this.toggleInquirySelection(this.wordInquiryKey(item));
  }

  build() {
    Column() {
      PageChrome({ title: '单词' })
      if (this.journey !== undefined) {
        this.journeyBridge()
      }
      Row({ space: 18 }) {
        ForEach(['N5', 'N4', 'N3', 'N2', 'N1'], (level: string) => {
          Text(level)
            .fontSize(13)
            .fontWeight(this.level === level ? FontWeight.Bold : FontWeight.Regular)
            .fontColor(this.level === level ? $r('app.color.accent') : $r('app.color.ink_muted'))
            .onClick(() => {
              this.journeyOnly = false;
              this.loadLevel(level);
            })
        })
      }
      .width('100%')
      .padding({ left: 26, right: 26, top: 4, bottom: 14 })
      .visualEffect(contentLightEffect())

      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(17)
          .fontColor([$r('app.color.ink_muted')])
        TextInput({ text: this.query, placeholder: this.journeyOnly ? '搜索本次旅程' : `搜索 ${this.level}` })
          .layoutWeight(1)
          .height('100%')
          .fontSize(14)
          .fontColor($r('app.color.ink'))
          .placeholderColor($r('app.color.ink_muted'))
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onChange((value: string) => {
            this.query = value;
            this.applyFilter();
          })
      }
        .height(46)
        .margin({ left: 24, right: 24, bottom: 8 })
        .padding({ left: 4, right: 4 })
        .backgroundEffect({ radius: 24, color: $r('app.color.immersive_plane'), saturation: 1.06 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .borderRadius(23)
        .visualEffect(planeLightEffect())

      if (this.focusWord !== undefined && this.loadError.length === 0) {
        this.wordStage(this.focusWord)
      }

      if (this.loadError.length > 0) {
        Text(this.loadError)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else {
        List({ space: 0 }) {
          LazyForEach(this.dataSource, (item: VocabularyEntry) => {
            HdsListItem({
              customItemBuilder: () => {
                this.wordRow(item)
              },
              isSelected: this.focusWord?.id === item.id
            })
          }, (item: VocabularyEntry) => item.id)
          ListItem() {
            Column()
              .height(FLOATING_TAB_CONTENT_INSET)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14 })
        .margin({ left: 14, right: 14, top: 6 })
        .borderRadius(28)
        .clip(true)
        .backgroundEffect({ radius: 28, color: $r('app.color.immersive_plane'), saturation: 1.06 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private journeyBridge() {
    Row({ space: 14 }) {
      Column({ space: 3 }) {
        Text('当前旅程词组')
          .fontSize(10)
          .fontColor($r('app.color.accent'))
        Text(this.journey?.title ?? '')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(this.journeyOnly ? '查看完整词库' : `只看 ${this.journey?.wordIds.length ?? 0} 个词`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent'))
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .borderRadius(16)
        .backgroundColor($r('app.color.accent_soft'))
        .onClick(() => {
          if (this.journeyOnly) {
            this.journeyOnly = false;
            this.applyFilter();
          } else {
            this.journeyOnly = true;
            this.query = '';
            this.loadLevel(this.journey?.vocabularyLevel ?? 'N5');
          }
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 4, bottom: 8 })
    .visualEffect(contentLightEffect())
  }

  @Builder
  private wordStage(item: VocabularyEntry) {
    Column({ space: 18 }) {
      Column({ space: 12 }) {
        Row() {
          Text(item.word)
            .fontSize(item.word.length > 7 ? 36 : 50)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          Column({ space: 5 }) {
            Text(item.reading)
              .fontSize(15)
              .fontColor($r('app.color.accent'))
            Text(item.level)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_muted'))
              .letterSpacing(1)
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Text(item.meanings.join('；'))
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
          .lineHeight(29)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .borderRadius(20)
      .backgroundColor(this.selectedInquiryKey === this.wordInquiryKey(item) ?
        $r('app.color.accent_soft') : Color.Transparent)
      .onClick(() => this.toggleInquirySelection(this.wordInquiryKey(item)))

      if (this.selectedInquiryKey === this.wordInquiryKey(item)) {
        Row() {
          Blank()
          AiAskAction({
            label: '问这个词',
            onAsk: () => this.onAsk(AiInquiryFactory.word(item))
          })
        }
        .width('100%')
      }

      if (item.example !== undefined) {
        Column({ space: 6 }) {
          Text(item.example.japanese)
            .width('100%')
            .fontSize(20)
            .lineHeight(31)
            .fontColor($r('app.color.ink'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.example.english)
            .width('100%')
            .fontSize(12)
            .lineHeight(20)
            .fontColor($r('app.color.ink_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .borderRadius(18)
        .backgroundColor(this.selectedInquiryKey === this.exampleInquiryKey(item) ?
          $r('app.color.accent_soft') : Color.Transparent)
        .onClick(() => this.toggleInquirySelection(this.exampleInquiryKey(item)))

        if (this.selectedInquiryKey === this.exampleInquiryKey(item)) {
          Row() {
            Blank()
            AiAskAction({
              label: '问例句',
              onAsk: () => this.onAsk(AiInquiryFactory.example(
                item.example?.japanese ?? '', item.example?.english ?? '', item.word))
            })
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .margin({ left: 14, right: 14, bottom: 8 })
    .borderRadius(30)
    .clip(true)
    .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
  }

  @Builder
  private wordRow(item: VocabularyEntry) {
    Row({ space: 18 }) {
      Text(item.word)
        .width('34%')
        .fontSize(19)
        .fontWeight(item.common ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.focusWord?.id === item.id ? $r('app.color.accent') : $r('app.color.ink'))
      Text(item.reading)
        .width('25%')
        .fontSize(12)
        .fontColor($r('app.color.ink_muted'))
      Text(item.meanings.slice(0, 2).join('；'))
        .layoutWeight(1)
        .fontSize(13)
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
        .fontColor($r('app.color.ink_muted'))
    }
    .width('100%')
    .padding({ top: 15, bottom: 15 })
    .visualEffect(contentLightEffect())
    .onClick(() => this.selectWord(item))
  }
}
