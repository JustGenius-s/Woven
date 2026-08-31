import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import { FLOATING_TAB_CONTENT_INSET, MOTION_DURATION } from '../../common/AppTheme';
import {
  Dialogue,
  DialogueLine,
  GrammarIndexEntry,
  LearningCatalog,
  LearningJourney
} from '../../model/ContentModels';
import { AiInquiryContext } from '../../model/DeepSeekModels';
import { AiInquiryFactory } from '../../services/AiInquiryFactory';
import { ContentRepository } from '../../services/ContentRepository';
import { aiTextSelectionMenu } from '../components/AiTextSelection';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, ImmersivePlane, planeLightEffect } from '../components/ImmersiveCanvas';
import { PageChrome } from '../components/PageChrome';
import { GrammarPage } from './GrammarPage';

@Component
export struct LearnPage {
  savedLessonIndex: number = 0;
  journeys: LearningJourney[] = [];
  currentJourney: LearningJourney | undefined = undefined;
  journeyStage: number = 0;
  journeyCompletedMask: number = 0;
  showHomeGuide: boolean = false;
  onLessonChange: (index: number) => void = (index: number) => {};
  onJourney: (journey: LearningJourney) => void = (journey: LearningJourney) => {};
  onAsk: (context: AiInquiryContext) => void = (context: AiInquiryContext) => {};
  onDismissHomeGuide: () => void = () => {};

  @State private mode: number = 0;
  @State private grammarIndex: GrammarIndexEntry[] = [];
  @State private catalog: LearningCatalog | undefined = undefined;
  @State private dialogueIndex: number = 0;
  @State private loadError: string = '';

  aboutToAppear(): void {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.grammarIndex = ContentRepository.loadGrammarIndex(context);
      this.catalog = ContentRepository.loadCatalog(context);
      this.loadError = '';
    } catch (error) {
      this.loadError = '课程资源读取失败，请重新安装应用';
    }
  }

  private changeMode(mode: number): void {
    this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.86, 0.16) }, () => {
      this.mode = mode;
    });
  }

  private dialogueContext(dialogue: Dialogue, line?: DialogueLine): string {
    if (line === undefined) {
      return `场景：${dialogue.setting}\n主题：${dialogue.title}\n学习目标：${dialogue.goal}`;
    }
    return `场景：${dialogue.setting}\n主题：${dialogue.title}\n说话人：${line.speaker}\n` +
      `原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`;
  }

  private askDialogueSelection(selection: string, dialogue: Dialogue, line?: DialogueLine): void {
    const source: string = line === undefined ? dialogue.title : `${dialogue.title} · ${line.speaker}`;
    this.onAsk(AiInquiryFactory.selection(selection, source, this.dialogueContext(dialogue, line)));
  }

  private askJourneySelection(selection: string, journey: LearningJourney): void {
    const context: string = `场景：${journey.setting}\n旅程：${journey.title}\n` +
      `日语标题：${journey.japaneseTitle}\n目标：${journey.goal}`;
    this.onAsk(AiInquiryFactory.selection(selection, journey.title, context));
  }

  private startFromGuide(): void {
    this.onDismissHomeGuide();
    if (this.currentJourney !== undefined) {
      this.onJourney(this.currentJourney);
    }
  }

  build() {
    if (this.mode === 1) {
      GrammarPage({
        entries: this.grammarIndex,
        initialIndex: this.savedLessonIndex,
        onIndexChange: this.onLessonChange,
        onAsk: this.onAsk,
        onBack: () => this.changeMode(0)
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ x: 20 }))
        .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
    } else if (this.mode === 2) {
      this.dialogues()
    } else {
      this.home()
    }
  }

  @Builder
  private home() {
    Column() {
      PageChrome({ title: '旅程' })
      if (this.loadError.length > 0) {
        Column({ space: 12 }) {
          Text('课程没有加载出来')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(this.loadError)
            .fontSize(15)
            .fontColor($r('app.color.danger'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 20 }) {
            if (this.showHomeGuide) {
              ImmersivePlane({
                planeStrong: true,
                planeContent: () => {
                  this.firstUseGuide()
                }
              })
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: -10 }))
                .animation({ curve: curves.springMotion(0.38, 0.88, 0.16) }))
            }

            if (this.currentJourney !== undefined) {
              ImmersivePlane({
                planeStrong: true,
                interactive: true,
                planeContent: () => {
                  this.journeyHero(this.currentJourney)
                }
              })
            }

            if (this.journeys.length > 1) {
              Column({ space: 10 }) {
                Text('其他场景')
                  .width('100%')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                List({ space: 10 }) {
                  ForEach(this.journeys, (journey: LearningJourney) => {
                    if (journey.id !== this.currentJourney?.id) {
                      ListItem() {
                        this.journeyChoice(journey)
                      }
                    }
                  }, (journey: LearningJourney) => journey.id)
                }
                .width('100%')
                .height(80)
                .listDirection(Axis.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            this.learningShortcuts()
            Column()
              .height(FLOATING_TAB_CONTENT_INSET)
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.98, y: 0.98 }))
      .animation({ curve: curves.springMotion(0.4, 0.88, 0.14) }))
  }

  private completedStageCount(): number {
    let count: number = 0;
    for (let index: number = 0; index < 6; index++) {
      if ((this.journeyCompletedMask & (1 << index)) !== 0) {
        count += 1;
      }
    }
    return count;
  }

  private journeyStageLabel(): string {
    const stages: string[] = ['入景', '识音', '记词', '懂句', '会话', '开口'];
    return stages[Math.max(0, Math.min(this.journeyStage, stages.length - 1))];
  }

  @Builder
  private firstUseGuide() {
    Column({ space: 16 }) {
      Text('欢迎来到言葉')
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text('从一个真实场景开始。每次完成一个小阶段，进度会自动保存。')
        .width('100%')
        .fontSize(14)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(22)
        .maxLines(3)
      Row() {
        Blank()
        ImmersiveAction({
          label: '开始旅程',
          actionAccessibilityText: '完成首次使用引导并开始旅程',
          icon: $r('sys.symbol.arrow_right'),
          emphasized: true,
          onAction: () => this.startFromGuide()
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 22, right: 20, top: 22, bottom: 18 })
  }

  @Builder
  private journeyHero(journey: LearningJourney | undefined) {
    if (journey !== undefined) {
      Column({ space: 16 }) {
        Row() {
          Text('当前旅程')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
          Blank()
          Text(journey.duration)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
        }
        Column({ space: 4 }) {
          Text(journey.title)
            .width('100%')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .lineHeight(37)
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(journey.title,
              (selection: string) => this.askJourneySelection(selection, journey)))
          Text(journey.japaneseTitle)
            .width('100%')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink_muted'))
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(journey.japaneseTitle,
              (selection: string) => this.askJourneySelection(selection, journey)))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        Text(journey.goal)
          .width('100%')
          .fontSize(14)
          .fontColor($r('app.color.ink_muted'))
          .lineHeight(22)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
          .editMenuOptions(aiTextSelectionMenu(journey.goal,
            (selection: string) => this.askJourneySelection(selection, journey)))
        Row({ space: 6 }) {
          ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
            Column()
              .height(5)
              .layoutWeight(1)
              .borderRadius(3)
              .backgroundColor(this.journeyStage === index ||
                (this.journeyCompletedMask & (1 << index)) !== 0 ?
                $r('app.color.accent') : $r('app.color.line'))
              .animation({ curve: curves.springMotion(0.38, 0.82, 0.18) })
          })
        }
        .width('100%')
        Row() {
          Text(`${this.journeyStageLabel()}  ${this.completedStageCount()}/6`)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
          Blank()
          ImmersiveAction({
            label: this.completedStageCount() === 0 ? '开始' : '继续',
            actionAccessibilityText: `打开${journey.title}学习旅程`,
            icon: $r('sys.symbol.arrow_right'),
            emphasized: true,
            onAction: () => this.onJourney(journey)
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 22, top: 24, bottom: 22 })
      .onClick(() => this.onJourney(journey))
    }
  }

  @Builder
  private journeyChoice(journey: LearningJourney) {
    Column({ space: 4 }) {
      Text(journey.title)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(journey.japaneseTitle)
        .width('100%')
        .fontSize(11)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(140)
    .height(76)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 16, right: 14 })
    .borderRadius(20)
    .backgroundEffect({
      radius: 24,
      color: $r('app.color.immersive_plane'),
      saturation: 1.06
    })
    .border({ width: 0.5, color: $r('app.color.immersive_edge') })
    .visualEffect(planeLightEffect())
    .onClick(() => this.onJourney(journey))
  }

  @Builder
  private learningShortcuts() {
    Column() {
      if (this.grammarIndex.length > 0) {
        this.learningShortcut(
          '语法',
          this.grammarIndex[Math.min(this.savedLessonIndex, this.grammarIndex.length - 1)].title,
          `${this.grammarIndex[Math.min(this.savedLessonIndex, this.grammarIndex.length - 1)].level}  第${this.grammarIndex[Math.min(this.savedLessonIndex, this.grammarIndex.length - 1)].order}课`,
          $r('sys.symbol.bookmark'),
          () => this.changeMode(1))
        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.line'))
          .margin({ left: 54 })
      }
      this.learningShortcut(
        '对话',
        '日常对话',
        `${this.catalog?.dialogues.length ?? 0} 个场景`,
        $r('sys.symbol.message'),
        () => this.changeMode(2))
    }
    .width('100%')
    .border({ width: { top: 0.5 }, color: $r('app.color.line') })
  }

  @Builder
  private learningShortcut(category: string, title: string, meta: string, icon: Resource, onSelect: () => void) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(icon)
          .fontSize(19)
          .fontColor([$r('app.color.accent')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.accent_soft'))
      Column({ space: 3 }) {
        Text(category)
          .width('100%')
          .fontSize(11)
          .fontColor($r('app.color.ink_muted'))
        Text(title)
          .width('100%')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(meta)
        .fontSize(11)
        .fontColor($r('app.color.ink_muted'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('app.color.ink_muted')])
    }
    .width('100%')
    .height(76)
    .alignItems(VerticalAlign.Center)
    .visualEffect(contentLightEffect())
    .onClick(onSelect)
  }

  @Builder
  private dialogues() {
    Column() {
      ImmersiveBackChrome({ title: '日常对话', onBack: () => this.changeMode(0) })

      if (this.catalog !== undefined) {
        Swiper() {
          ForEach(this.catalog?.dialogues ?? [], (dialogue: Dialogue) => {
            this.dialoguePage(dialogue)
          }, (dialogue: Dialogue) => dialogue.id)
        }
        .index(this.dialogueIndex)
        .indicator(false)
        .loop(false)
        .duration(MOTION_DURATION)
        .curve(curves.springMotion(0.42, 0.86, 0.16))
        .layoutWeight(1)
        .onChange((index: number) => {
          this.dialogueIndex = index;
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: 20 }))
      .animation({ curve: curves.springMotion(0.4, 0.86, 0.16) }))
  }

  @Builder
  private dialoguePage(dialogue: Dialogue) {
    List({ space: 0 }) {
      ListItem() {
        Column({ space: 10 }) {
          Text(dialogue.setting)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .letterSpacing(1.3)
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(dialogue.setting,
              (selection: string) => this.askDialogueSelection(selection, dialogue)))
          Text(dialogue.title)
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(dialogue.title,
              (selection: string) => this.askDialogueSelection(selection, dialogue)))
          Text(dialogue.goal)
            .fontSize(14)
            .lineHeight(23)
            .fontColor($r('app.color.ink_muted'))
            .copyOption(CopyOptions.LocalDevice)
            .editMenuOptions(aiTextSelectionMenu(dialogue.goal,
              (selection: string) => this.askDialogueSelection(selection, dialogue)))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(24)
        .margin({ top: 16, bottom: 26 })
        .borderRadius(28)
        .clip(true)
        .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
      }
      ForEach(dialogue.lines, (line: DialogueLine, index: number) => {
        ListItem() {
          Row({ space: 10 }) {
            if (line.learner === true) {
              Blank()
            }
            Text((index + 1).toString().padStart(2, '0'))
              .fontSize(11)
              .fontColor(line.learner === true ? $r('app.color.accent') : $r('app.color.ink_muted'))
              .opacity(0.62)
              .alignSelf(ItemAlign.Start)
            Column({ space: 8 }) {
              Text(line.speaker)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(line.learner === true ? $r('app.color.accent') : $r('app.color.ink_muted'))
                .letterSpacing(0.8)
              Text(line.text)
                .width('100%')
                .fontSize(line.learner === true ? 22 : 27)
                .fontWeight(line.learner === true ? FontWeight.Medium : FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .lineHeight(line.learner === true ? 33 : 38)
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.text,
                  (selection: string) => this.askDialogueSelection(selection, dialogue, line)))
              Text(line.reading)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.reading,
                  (selection: string) => this.askDialogueSelection(selection, dialogue, line)))
              Text(line.meaning)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
                .copyOption(CopyOptions.LocalDevice)
                .editMenuOptions(aiTextSelectionMenu(line.meaning,
                  (selection: string) => this.askDialogueSelection(selection, dialogue, line)))
            }
            .width(line.learner === true ? '78%' : '90%')
            .alignItems(line.learner === true ? HorizontalAlign.End : HorizontalAlign.Start)
            if (line.learner !== true) {
              Blank()
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 24, bottom: 24 })
          .borderRadius(18)
          .visualEffect(contentLightEffect())
        }
      }, (line: DialogueLine, index: number) => `${dialogue.id}-${index}`)
      ListItem() {
        Column()
          .height(FLOATING_TAB_CONTENT_INSET)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 28, right: 28 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
