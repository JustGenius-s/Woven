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
import { ContentRepository } from '../../services/ContentRepository';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { ImmersiveBackChrome } from '../components/ImmersiveBackChrome';
import { contentLightEffect, ImmersivePlane, planeLightEffect } from '../components/ImmersiveCanvas';
import { GravityMark } from '../components/GravityMark';
import { PageChrome } from '../components/PageChrome';
import { GrammarPage } from './GrammarPage';

@Component
export struct LearnPage {
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';
  savedLessonIndex: number = 0;
  journeys: LearningJourney[] = [];
  currentJourney: LearningJourney | undefined = undefined;
  journeyStage: number = 0;
  journeyCompletedMask: number = 0;
  onLessonChange: (index: number) => void = (index: number) => {};
  onJourney: (journey: LearningJourney) => void = (journey: LearningJourney) => {};
  onSettings: () => void = () => {};
  onPractice: () => void = () => {};

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

  build() {
    if (this.mode === 1) {
      GrammarPage({
        entries: this.grammarIndex,
        initialIndex: this.savedLessonIndex,
        gatewayUrl: this.gatewayUrl,
        appToken: this.appToken,
        model: this.model,
        onIndexChange: this.onLessonChange,
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
      PageChrome({ eyebrow: '今日の流れ', title: '学习旅程', onSettings: this.onSettings })
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
          Column({ space: 22 }) {
            Row({ space: 18 }) {
              Column({ space: 8 }) {
                Text('今天，从一句话出发')
                  .width('100%')
                  .fontSize(31)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                  .lineHeight(40)
                Text('让声音、词和句型在场景里自然汇合。')
                  .width('100%')
                  .fontSize(14)
                  .fontColor($r('app.color.ink_muted'))
                  .lineHeight(22)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              GravityMark({ diameter: 88, progress: this.journeyStage })
            }
            .width('100%')
            .padding({ left: 4, right: 4, top: 10, bottom: 2 })
            .alignItems(VerticalAlign.Center)
            .visualEffect(contentLightEffect())

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
              Column({ space: 12 }) {
                Row() {
                  Text('换一个场景')
                    .fontSize(19)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.ink'))
                  Blank()
                  Text(`${this.journeys.length} 条旅程`)
                    .fontSize(11)
                    .fontColor($r('app.color.ink_muted'))
                }
                .width('100%')
                List({ space: 10 }) {
                  ForEach(this.journeys, (journey: LearningJourney) => {
                    ListItem() {
                      this.journeyChoice(journey)
                    }
                  }, (journey: LearningJourney) => journey.id)
                }
                .width('100%')
                .height(104)
                .listDirection(Axis.Horizontal)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            if (this.grammarIndex.length > 0) {
              Column({ space: 8 }) {
                Text('补强当前语法')
                  .width('100%')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.ink'))
                this.continueLesson(
                  this.grammarIndex[Math.min(this.savedLessonIndex, this.grammarIndex.length - 1)])
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            this.sceneBridge()
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
  private journeyHero(journey: LearningJourney | undefined) {
    if (journey !== undefined) {
      Column({ space: 18 }) {
        Row() {
          Text(`${journey.setting}  ${journey.level}`)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .letterSpacing(0.8)
          Blank()
          Text(`正在进行：${this.journeyStageLabel()}`)
            .fontSize(11)
            .fontColor($r('app.color.ink_muted'))
        }
        Text(journey.japaneseTitle)
          .width('100%')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .lineHeight(46)
        Text(journey.goal)
          .width('100%')
          .fontSize(15)
          .fontColor($r('app.color.ink_muted'))
          .lineHeight(24)
        Row({ space: 5 }) {
          ForEach(['景', '音', '词', '句', '话', '说'], (label: string, index: number) => {
            Text(this.journeyStage === index ? label :
              ((this.journeyCompletedMask & (1 << index)) !== 0 ? '✓' : (index + 1).toString()))
              .width(this.journeyStage === index ? 62 : 36)
              .height(36)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.journeyStage === index ? Color.White :
                ((this.journeyCompletedMask & (1 << index)) !== 0 ?
                  $r('app.color.accent') : $r('app.color.ink_muted')))
              .textAlign(TextAlign.Center)
              .borderRadius(18)
              .backgroundColor(this.journeyStage === index ?
                $r('app.color.accent') : $r('app.color.immersive_plane'))
              .border({ width: 0.5, color: this.journeyStage === index ?
                $r('app.color.accent') : $r('app.color.immersive_edge') })
              .shadow({ radius: this.journeyStage === index ? 12 : 0,
                color: $r('app.color.gravity_glow'), offsetY: 4 })
              .animation({ curve: curves.springMotion(0.38, 0.82, 0.18) })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        Row() {
          Text(`${this.completedStageCount()}/6 已贯通`)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
          Blank()
          ImmersiveAction({
            label: this.completedStageCount() === 0 ? '开始旅程' : '继续旅程',
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
    Column({ space: 6 }) {
      Text(journey.setting)
        .width('100%')
        .fontSize(10)
        .fontColor(this.currentJourney?.id === journey.id ? $r('app.color.accent') : $r('app.color.ink_muted'))
      Text(journey.title)
        .width('100%')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text(journey.japaneseTitle)
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.ink_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(150)
    .height(96)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 16, right: 14 })
    .borderRadius(22)
    .backgroundEffect({
      radius: 24,
      color: this.currentJourney?.id === journey.id ?
        $r('app.color.immersive_plane_strong') : $r('app.color.immersive_plane'),
      saturation: 1.06
    })
    .border({
      width: this.currentJourney?.id === journey.id ? 1 : 0.5,
      color: this.currentJourney?.id === journey.id ? $r('app.color.accent') : $r('app.color.immersive_edge')
    })
    .visualEffect(planeLightEffect())
    .onClick(() => this.onJourney(journey))
  }

  @Builder
  private sceneBridge() {
    Row({ space: 18 }) {
      Column({ space: 6 }) {
        Text('会話の棚')
          .fontSize(10)
          .fontColor($r('app.color.accent'))
          .letterSpacing(1)
        Text('浏览完整场景语料')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text('先看自然对话，也可以直接进入自由对练。')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 8 }) {
        ImmersiveAction({
          actionAccessibilityText: '浏览场景语料',
          icon: $r('sys.symbol.arrow_right'),
          onAction: () => this.changeMode(2)
        })
        Text('自由对练')
          .fontSize(11)
          .fontColor($r('app.color.accent'))
          .onClick(this.onPractice)
      }
    }
    .width('100%')
    .padding({ left: 8, right: 6, top: 20, bottom: 20 })
    .border({ width: { top: 0.5 }, color: $r('app.color.line') })
    .visualEffect(contentLightEffect())
  }

  @Builder
  private continueLesson(lesson: GrammarIndexEntry) {
    Column({ space: 14 }) {
      Row() {
        Text('继续语法')
          .fontSize(13)
          .fontColor($r('app.color.accent'))
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(`${lesson.level} · ${lesson.order.toString().padStart(2, '0')}`)
          .fontSize(12)
          .fontColor($r('app.color.ink_muted'))
      }
      Text(lesson.title)
        .width('100%')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .lineHeight(31)
        .maxLines(3)
      Text(lesson.summary)
        .width('100%')
        .fontSize(15)
        .fontColor($r('app.color.ink_muted'))
        .lineHeight(24)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      ImmersiveAction({
        label: '继续学习',
        actionAccessibilityText: '继续当前语法课',
        icon: $r('sys.symbol.arrow_right'),
        emphasized: true,
        onAction: () => this.changeMode(1)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 8, right: 6, top: 16, bottom: 18 })
    .border({ width: { top: 0.5 }, color: $r('app.color.line') })
    .onClick(() => this.changeMode(1))
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
        .onChange((index: number) => this.dialogueIndex = index)
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
          Text(dialogue.title)
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text(dialogue.goal)
            .fontSize(14)
            .lineHeight(23)
            .fontColor($r('app.color.ink_muted'))
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
              Text(line.reading)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
              Text(line.meaning)
                .width('100%')
                .fontSize(13)
                .fontColor($r('app.color.ink_muted'))
                .textAlign(line.learner === true ? TextAlign.End : TextAlign.Start)
            }
            .width(line.learner === true ? '78%' : '90%')
            .alignItems(line.learner === true ? HorizontalAlign.End : HorizontalAlign.Start)
            if (line.learner !== true) {
              Blank()
            }
          }
          .width('100%')
          .padding({ top: 24, bottom: 24 })
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
