import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AiInquiryContext,
  DeepSeekMessage,
  PracticeMessage
} from '../../model/DeepSeekModels';
import {
  DEFAULT_COURSE_ID,
  DEFAULT_SUPPORT_LOCALE,
  DEFAULT_TARGET_LOCALE
} from '../../model/SyncModels';
import { DeepSeekClient } from '../../services/DeepSeekClient';
import { VocabularyLearningStore } from '../../services/VocabularyLearningStore';
import { ImmersiveAction } from './ImmersiveAction';

const LOG_DOMAIN: number = 0x4b4f;
const LOG_TAG: string = 'WovenInquiry';
const MAX_CONTEXT_MESSAGES: number = 12;
const EMPTY_CONTEXT: AiInquiryContext = {
  id: '',
  kind: '',
  title: '',
  subtitle: '',
  content: '',
  suggestions: []
};

@Component
export struct ContextAiPanel {
  context: AiInquiryContext = EMPTY_CONTEXT;
  apiKey: string = '';
  onClose: () => void = () => {};

  @State private messages: PracticeMessage[] = [];
  @State private draft: string = '';
  @State private generating: boolean = false;
  @State private status: string = '';
  private history: DeepSeekMessage[] = [];
  private client?: DeepSeekClient;
  private activeAssistantId: string = '';
  private scroller: Scroller = new Scroller();
  private initialPromptTimer: number = 0;

  aboutToAppear(): void {
    this.restoreConversation();
    this.status = '';
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Inquiry opened kind=%{public}s', this.context.kind);
    const initialPrompt: string = this.context.initialPrompt === undefined ? '' :
      this.context.initialPrompt.trim();
    if (initialPrompt.length > 0) {
      this.initialPromptTimer = setTimeout(() => {
        this.initialPromptTimer = 0;
        this.submit(initialPrompt);
      }, 120);
    } else {
      this.scrollToLatest();
    }
  }

  aboutToDisappear(): void {
    if (this.initialPromptTimer > 0) {
      clearTimeout(this.initialPromptTimer);
      this.initialPromptTimer = 0;
    }
    this.client?.cancel();
  }

  private askSuggestion(suggestion: string): void {
    this.submit(suggestion);
  }

  private send(): void {
    this.submit(this.draft);
  }

  private submit(rawValue: string): void {
    const value: string = rawValue.trim();
    if (value.length === 0 || this.generating) {
      return;
    }
    this.draft = '';
    this.status = '';
    this.appendMessage('user', value);
    this.history.push({ role: 'user', content: value });
    this.request();
  }

  private retry(): void {
    if (!this.generating && this.history.length > 0) {
      this.status = '';
      this.request();
    }
  }

  private stop(): void {
    if (!this.generating) {
      return;
    }
    this.client?.cancel();
    this.generating = false;
    this.status = '已停止，可以继续提问。';
    this.removeIfEmpty(this.activeAssistantId);
    this.activeAssistantId = '';
  }

  private request(): void {
    this.client = new DeepSeekClient(this.apiKey);
    this.generating = true;
    const assistantId: string = this.appendMessage('assistant', '');
    this.activeAssistantId = assistantId;
    this.client.complete(this.contextMessages()).then((answer: string) => {
      this.generating = false;
      this.activeAssistantId = '';
      this.updateMessage(assistantId, answer);
      this.history.push({ role: 'assistant', content: answer });
      this.scrollToLatest();
    }).catch((error: Error) => {
      if (DeepSeekClient.isCancelled(error)) {
        return;
      }
      this.generating = false;
      this.activeAssistantId = '';
      this.status = error.message;
      this.removeIfEmpty(assistantId);
    });
  }

  private contextMessages(): DeepSeekMessage[] {
    const messages: DeepSeekMessage[] = [{ role: 'system', content: this.instructions() }];
    const start: number = Math.max(0, this.history.length - MAX_CONTEXT_MESSAGES);
    for (let index: number = start; index < this.history.length; index++) {
      messages.push(this.history[index]);
    }
    return messages;
  }

  private instructions(): string {
    return `你是 Woven 日语学习助手。用户正在围绕一项学习内容对话。内容类型：${this.context.kind}。` +
      `\n学习内容：\n${this.context.content}\n` +
      '围绕这项内容回答，并根据问题解释读音、词义、语法、语气、使用场景或给出例句。' +
      '如果学习内容中带有用户的学习进度，造句时优先复用其中列出的语法和词汇，' +
      '同时保证日语自然，不需要为了复用而写出生硬句子。' +
      '优先使用简洁中文说明，日语示例附上必要的读音或翻译。不要输出 Markdown 标题，回答控制在容易在手机上阅读的长度。';
  }

  private restoreConversation(): void {
    this.messages = [];
    this.history = [];
    const conversationKey: string = this.context.conversationKey === undefined ? '' :
      this.context.conversationKey;
    if (conversationKey.length === 0) {
      return;
    }
    const context: common.Context = this.getUIContext().getHostContext() as common.Context;
    this.messages = VocabularyLearningStore.loadConversation(
      context,
      conversationKey,
      this.context.courseId === undefined ? DEFAULT_COURSE_ID : this.context.courseId
    );
    for (let index: number = 0; index < this.messages.length; index++) {
      this.history.push({
        role: this.messages[index].role,
        content: this.messages[index].text
      });
    }
  }

  private persistConversation(): void {
    const conversationKey: string = this.context.conversationKey === undefined ? '' :
      this.context.conversationKey;
    if (conversationKey.length === 0) {
      return;
    }
    VocabularyLearningStore.saveConversation(
      this.getUIContext().getHostContext() as common.Context,
      conversationKey,
      this.messages,
      this.context.targetLocale === undefined ? DEFAULT_TARGET_LOCALE : this.context.targetLocale,
      this.context.supportLocale === undefined ? DEFAULT_SUPPORT_LOCALE : this.context.supportLocale,
      this.context.courseId === undefined ? DEFAULT_COURSE_ID : this.context.courseId
    );
  }

  private appendMessage(role: string, text: string): string {
    const id: string = util.generateRandomUUID();
    this.messages = this.messages.concat([{
      id: id,
      role: role,
      text: text,
      revision: 0,
      languageTag: role === 'user' ?
        (this.context.supportLocale === undefined ? DEFAULT_SUPPORT_LOCALE : this.context.supportLocale) : 'und',
      createdAt: Date.now()
    }]);
    this.persistConversation();
    this.scrollToLatest();
    return id;
  }

  private updateMessage(id: string, text: string): void {
    const next: PracticeMessage[] = this.messages.slice();
    for (let index: number = 0; index < next.length; index++) {
      if (next[index].id === id) {
        next[index] = {
          id: next[index].id,
          role: next[index].role,
          text: text,
          revision: next[index].revision + 1,
          languageTag: next[index].languageTag,
          createdAt: next[index].createdAt
        };
        break;
      }
    }
    this.messages = next;
    this.persistConversation();
  }

  private removeIfEmpty(id: string): void {
    const next: PracticeMessage[] = [];
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id !== id || this.messages[index].text.length > 0) {
        next.push(this.messages[index]);
      }
    }
    this.messages = next;
    this.persistConversation();
  }

  private scrollToLatest(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 30);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 7 }) {
          Text(this.context.kind)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .letterSpacing(1)
          Text(this.context.title)
            .width('100%')
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .lineHeight(29)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.context.subtitle.length > 0) {
            Text(this.context.subtitle)
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.ink_muted'))
              .lineHeight(19)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 62, top: 14, bottom: 18 })

        ImmersiveAction({
          actionAccessibilityText: '关闭 AI 对话',
          icon: $r('sys.symbol.xmark'),
          actionSize: 38,
          onAction: this.onClose
        })
        .margin({ top: 8, right: 8 })
      }
      .width('100%')
      .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })

      List({ space: 0, scroller: this.scroller }) {
        if (this.messages.length === 0) {
          ListItem() {
            Column({ space: 12 }) {
              Text('你可以这样问')
                .width('100%')
                .fontSize(12)
                .fontColor($r('app.color.ink_muted'))
              Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                ForEach(this.context.suggestions, (suggestion: string) => {
                  Button(suggestion, {
                    type: ButtonType.ROUNDED_RECTANGLE,
                    stateEffect: true
                  })
                    .buttonStyle(ButtonStyleMode.NORMAL)
                    .controlSize(ControlSize.SMALL)
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => this.askSuggestion(suggestion))
                }, (suggestion: string) => suggestion)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 22, right: 22, top: 14, bottom: 10 })
          }
        }

        ForEach(this.messages, (message: PracticeMessage) => {
          ListItem() {
            Row() {
              if (message.role === 'user') {
                Blank()
              }
              Column({ space: 7 }) {
                Text(message.role === 'user' ? '你' : 'AI')
                  .fontSize(9)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(message.role === 'user' ? $r('app.color.accent') : $r('app.color.ink_muted'))
                if (message.text.length > 0) {
                  Text(message.text)
                    .width('100%')
                    .fontSize(message.role === 'user' ? 15 : 16)
                    .fontColor($r('app.color.ink'))
                    .lineHeight(message.role === 'user' ? 23 : 26)
                    .textAlign(message.role === 'user' ? TextAlign.End : TextAlign.Start)
                    .copyOption(CopyOptions.LocalDevice)
                } else {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color($r('app.color.accent'))
                }
              }
              .width(message.role === 'user' ? '78%' : '90%')
              .alignItems(message.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
              if (message.role !== 'user') {
                Blank()
              }
            }
            .width('100%')
            .padding({ left: 22, right: 22, top: 13, bottom: 13 })
          }
        }, (message: PracticeMessage) => `${message.id}-${message.revision}`)

        if (this.status.length > 0) {
          ListItem() {
            Row({ space: 10 }) {
              Text(this.status)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor($r('app.color.danger'))
                .lineHeight(19)
              ImmersiveAction({
                label: '重试',
                actionAccessibilityText: '重试 AI 问答',
                actionSize: 38,
                onAction: () => this.retry()
              })
            }
            .width('100%')
            .padding({ left: 22, right: 18, top: 8, bottom: 8 })
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Row({ space: 9 }) {
        TextInput({ text: this.draft, placeholder: this.generating ? 'AI 正在回答' : '继续问这段内容' })
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontColor($r('app.color.ink'))
          .placeholderColor($r('app.color.ink_muted'))
          .backgroundColor($r('app.color.surface'))
          .borderRadius(23)
          .padding({ left: 14, right: 10 })
          .enabled(!this.generating)
          .maxLength(500)
          .enterKeyType(EnterKeyType.Send)
          .onChange((value: string) => this.draft = value)
          .onSubmit(() => this.send())
        if (this.generating) {
          ImmersiveAction({
            actionAccessibilityText: '停止 AI 回答',
            icon: $r('sys.symbol.xmark'),
            actionSize: 44,
            emphasized: true,
            onAction: () => this.stop()
          })
        } else {
          ImmersiveAction({
            actionAccessibilityText: '发送问题',
            icon: $r('sys.symbol.paperplane_fill'),
            actionSize: 44,
            actionEnabled: this.draft.trim().length > 0,
            emphasized: true,
            onAction: () => this.send()
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 18, right: 14, top: 12, bottom: 12 })
      .border({ width: { top: 0.5 }, color: $r('app.color.line') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_raised'))
  }
}
