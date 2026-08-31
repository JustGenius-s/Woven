import { common } from '@kit.AbilityKit';
import { HdsListItem } from '@kit.UIDesignKit';
import { FLOATING_TAB_CONTENT_INSET } from '../../common/AppTheme';
import { LearningJourney, VocabularyEntry } from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { VocabularyDataSource } from '../../services/VocabularyDataSource';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
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
  @State private wordSheetOpen: boolean = false;
  @State private resultCount: number = 0;
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
      this.focusWord = undefined;
      this.wordSheetOpen = false;
      this.loadError = '';
      this.applyFilter();
    } catch (error) {
      this.loadError = `${level} 词库没有正确载入`;
      this.source = [];
      this.resultCount = 0;
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
    this.resultCount = filtered.length;
    if (this.focusWord !== undefined && !this.containsWord(filtered, this.focusWord.id)) {
      this.focusWord = undefined;
      this.wordSheetOpen = false;
    }
  }

  private selectWord(item: VocabularyEntry): void {
    this.focusWord = item;
    this.wordSheetOpen = true;
  }

  private containsWord(items: VocabularyEntry[], id: string): boolean {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].id === id) {
        return true;
      }
    }
    return false;
  }

  private wordContext(item: VocabularyEntry): string {
    const example: string = item.example === undefined ? '' :
      `\n例句：${item.example.japanese}\n例句释义：${item.example.english}`;
    return `单词：${item.word}\n读音：${item.reading}\n释义：${item.meanings.join('；')}${example}`;
  }

  private askSelection(selection: string, item: VocabularyEntry): void {
    const context: AiInquiryContext = AiInquiryFactory.selection(
      selection, `${item.level} 词库 · ${item.word}`, this.wordContext(item));
    if (this.wordSheetOpen) {
      this.wordSheetOpen = false;
      setTimeout(() => this.onAsk(context), 180);
      return;
    }
    this.onAsk(context);
  }

  build() {
    Column() {
      PageChrome({ title: '词库' })
      if (this.journey !== undefined) {
        this.journeyBridge()
      }
      Row({ space: 2 }) {
        ForEach(['N5', 'N4', 'N3', 'N2', 'N1'], (level: string) => {
          Button(level, {
            type: ButtonType.ROUNDED_RECTANGLE,
            stateEffect: true
          })
            .layoutWeight(1)
            .buttonStyle(this.level === level ? ButtonStyleMode.NORMAL : ButtonStyleMode.TEXTUAL)
            .controlSize(ControlSize.SMALL)
            .accessibilityText(`${level} 单词`)
            .onClick(() => {
              this.journeyOnly = false;
              this.loadLevel(level);
            })
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 14 })
      .visualEffect(contentLightEffect())

      Row() {
        Search({ value: this.query, placeholder: this.journeyOnly ? '搜索本次旅程' : `搜索 ${this.level}` })
          .layoutWeight(1)
          .height(40)
          .textFont({ size: 14 })
          .fontColor($r('app.color.ink'))
          .placeholderColor($r('app.color.ink_muted'))
          .onChange((value: string) => {
            this.query = value;
            this.applyFilter();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 10 })

      Row() {
        Text(this.journeyOnly ? '旅程词组' : `${this.level} 词库`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
        Blank()
        Text(`${this.resultCount} 个`)
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 2, bottom: 8 })

      if (this.loadError.length > 0) {
        Text(this.loadError)
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
          .padding(28)
      } else if (this.resultCount === 0) {
        this.emptyState()
      } else {
        List({ space: 0 }) {
          LazyForEach(this.dataSource, (item: VocabularyEntry) => {
            HdsListItem({
              customItemBuilder: () => {
                this.wordRow(item)
              },
              isSelected: this.wordSheetOpen && this.focusWord?.id === item.id
            })
          }, (item: VocabularyEntry) => item.id)
          ListItem() {
            Column()
              .height(FLOATING_TAB_CONTENT_INSET)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .margin({ left: 16, right: 16 })
        .borderRadius(24)
        .clip(true)
        .backgroundEffect({ radius: 26, color: $r('app.color.immersive_plane'), saturation: 1.04 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .bindSheet($$this.wordSheetOpen, this.wordDetailSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.BOTTOM,
      title: { title: '单词详情' },
      dragBar: true,
      showClose: true,
      blurStyle: BlurStyle.COMPONENT_REGULAR,
      backgroundColor: $r('app.color.surface_raised'),
      maskColor: '#33202124',
      onDisappear: () => this.wordSheetOpen = false
    })
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
      Button(this.journeyOnly ? '查看完整词库' : `只看 ${this.journey?.wordIds.length ?? 0} 个词`, {
        type: ButtonType.ROUNDED_RECTANGLE,
        stateEffect: true
      })
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .controlSize(ControlSize.SMALL)
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
    .padding({ left: 20, right: 16, top: 4, bottom: 8 })
    .visualEffect(contentLightEffect())
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(32)
        .fontColor([$r('app.color.ink_muted')])
      Text(this.query.trim().length > 0 ? '没有匹配的单词' : '当前范围没有单词')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private wordDetailSheet() {
    if (this.focusWord !== undefined) {
      List({ space: 0 }) {
        ListItem() {
          Column({ space: 7 }) {
            Row({ space: 8 }) {
              Text(this.focusWord.level)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
                .letterSpacing(1)
              if (this.focusWord.common) {
                Text('常用')
                  .fontSize(11)
                  .fontColor($r('app.color.ink_muted'))
              }
            }
            .width('100%')

            Text(this.focusWord.word)
              .width('100%')
              .fontSize(this.focusWord.word.length > 7 ? 34 : 42)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .lineHeight(this.focusWord.word.length > 7 ? 44 : 52)
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.focusWord.word,
                (selection: string) => this.askSelection(selection, this.focusWord as VocabularyEntry)))
            Text(this.focusWord.reading)
              .width('100%')
              .fontSize(16)
              .fontColor($r('app.color.accent'))
              .copyOption(CopyOptions.LocalDevice)
              .editMenuOptions(aiTextSelectionMenu(this.focusWord.reading,
                (selection: string) => this.askSelection(selection, this.focusWord as VocabularyEntry)))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 8, bottom: 20 })
          .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
        }

        ListItem() {
          Column({ space: 10 }) {
            Text('释义')
              .width('100%')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_muted'))

            ForEach(this.focusWord.meanings, (meaning: string, index: number) => {
              Row({ space: 10 }) {
                Text((index + 1).toString().padStart(2, '0'))
                  .width(24)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.accent'))
                Text(meaning)
                  .layoutWeight(1)
                  .fontSize(16)
                  .lineHeight(25)
                  .fontColor($r('app.color.ink'))
                  .copyOption(CopyOptions.LocalDevice)
                  .editMenuOptions(aiTextSelectionMenu(meaning,
                    (selection: string) => this.askSelection(selection, this.focusWord as VocabularyEntry)))
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (meaning: string, index: number) => `${index}-${meaning}`)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 20, right: 20, top: 18, bottom: 18 })
        }

        if (this.focusWord.example !== undefined) {
          ListItem() {
            Column({ space: 9 }) {
              Text('例句')
                .width('100%')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink_muted'))

              Text(this.focusWord.example?.japanese ?? '')
                .width('100%')
                .fontSize(20)
                .lineHeight(30)
                .fontColor($r('app.color.ink'))
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(this.focusWord.example?.japanese ?? '',
                  (selection: string) => this.askSelection(selection, this.focusWord as VocabularyEntry)))
              Text(this.focusWord.example?.english ?? '')
                .width('100%')
                .fontSize(14)
                .lineHeight(22)
                .fontColor($r('app.color.ink_muted'))
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(this.focusWord.example?.english ?? '',
                  (selection: string) => this.askSelection(selection, this.focusWord as VocabularyEntry)))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(16)
            .margin({ left: 16, right: 16, bottom: 24 })
            .borderRadius(18)
            .backgroundEffect({ radius: 22, color: $r('app.color.immersive_plane'), saturation: 1.04 })
            .border({ width: 0.5, color: $r('app.color.immersive_edge') })
            .visualEffect(planeLightEffect())
          }
        }

        ListItem() {
          Column()
            .height(24)
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  private wordRow(item: VocabularyEntry) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(item.word)
          .width('100%')
          .fontSize(18)
          .fontWeight(item.common ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.focusWord?.id === item.id && this.wordSheetOpen ?
            $r('app.color.accent') : $r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(item.word,
            (selection: string) => this.askSelection(selection, item)))
        Text(item.reading)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.ink_muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(item.reading,
            (selection: string) => this.askSelection(selection, item)))
      }
      .width('36%')
      .alignItems(HorizontalAlign.Start)

      Text(item.meanings.slice(0, 2).join('；'))
        .layoutWeight(1)
        .fontSize(13)
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('app.color.ink_muted'))
        .copyOption(CopyOptions.LocalDevice)
        .editMenuOptions(aiTextSelectionMenu(item.meanings.slice(0, 2).join('；'),
          (selection: string) => this.askSelection(selection, item)))

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.ink_muted')])
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 12, top: 10, bottom: 10 })
    .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
    .accessibilityText(`${item.word}，${item.reading}，${item.meanings.slice(0, 2).join('，')}`)
    .onClick(() => this.selectWord(item))
  }
}
