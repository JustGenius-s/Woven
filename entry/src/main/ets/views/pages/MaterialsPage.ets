import { common } from '@kit.AbilityKit';
import { curves } from '@kit.ArkUI';
import {
  NewsArticle,
  NewsItem,
  NewsSnapshot,
  VideoStudyItem
} from '../../model/ContentModels';
import { ResponseInputMessage, ResponsesCreateRequest } from '../../model/AiModels';
import { compactDate, FLOATING_TAB_CONTENT_INSET, MOTION_DURATION } from '../../common/AppTheme';
import { showImmersiveNotice } from '../../common/ImmersiveNotice';
import { LearningPreferences } from '../../services/LearningPreferences';
import { NewsClient } from '../../services/NewsClient';
import { ResponsesClient } from '../../services/ResponsesClient';
import { ImmersiveAction } from '../components/ImmersiveAction';
import { contentLightEffect, planeLightEffect } from '../components/ImmersiveCanvas';
import { InlineAiResult, PageChrome } from '../components/PageChrome';

const EMPTY_NEWS_ITEM: NewsItem = {
  id: '',
  title: '',
  summary: '',
  url: ''
};
const EMPTY_VIDEO_ITEM: VideoStudyItem = {
  id: '',
  title: '',
  url: '',
  transcript: '',
  createdAt: 0
};

@Component
export struct MaterialsPage {
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';
  onSettings: () => void = () => {};

  @State private mode: number = 0;
  @State private news: NewsSnapshot | undefined = undefined;
  @State private newsIndex: number = 0;
  @State private newsLoading: boolean = false;
  @State private newsError: string = '';
  @State private videos: VideoStudyItem[] = [];
  @State private videoIndex: number = 0;
  @State private editorOpen: boolean = false;
  @State private draftTitle: string = '';
  @State private draftUrl: string = '';
  @State private draftTranscript: string = '';
  @State private formError: string = '';

  aboutToAppear(): void {
    this.videos = LearningPreferences.videos(this.getUIContext().getHostContext() as common.Context);
    this.loadNews();
  }

  private loadNews(): void {
    if (this.newsLoading) {
      return;
    }
    this.newsLoading = true;
    this.newsError = '';
    const client: NewsClient = new NewsClient(this.gatewayUrl, this.appToken);
    client.loadNews().then((snapshot: NewsSnapshot) => {
      this.news = snapshot;
      this.newsIndex = 0;
      this.newsLoading = false;
    }).catch((error: Error) => {
      this.newsLoading = false;
      this.newsError = error.message;
    });
  }

  private beginVideo(): void {
    this.draftTitle = '';
    this.draftUrl = '';
    this.draftTranscript = '';
    this.formError = '';
    this.editorOpen = true;
  }

  private saveVideo(): void {
    const title: string = this.draftTitle.trim();
    const url: string = this.draftUrl.trim();
    if (title.length === 0) {
      this.formError = '请填写视频标题';
      showImmersiveNotice(this.getUIContext(), '无法保存素材', this.formError);
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      this.formError = '请填写完整的 http 或 https 视频链接';
      showImmersiveNotice(this.getUIContext(), '无法保存素材', this.formError);
      return;
    }
    const item: VideoStudyItem = {
      id: `video-${Date.now()}`,
      title: title,
      url: url,
      transcript: this.draftTranscript.trim(),
      createdAt: Date.now()
    };
    this.videos = [item].concat(this.videos);
    LearningPreferences.saveVideos(this.getUIContext().getHostContext() as common.Context, this.videos);
    this.videoIndex = 0;
    this.editorOpen = false;
  }

  build() {
    Column() {
      PageChrome({ title: '素材学习', onSettings: this.onSettings })
      Row({ space: 18 }) {
        Text('新聞')
          .fontSize(this.mode === 0 ? 28 : 16)
          .fontWeight(this.mode === 0 ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.mode === 0 ? $r('app.color.accent') : $r('app.color.ink_muted'))
          .onClick(() => this.mode = 0)
        Text('映像')
          .fontSize(this.mode === 1 ? 28 : 16)
          .fontWeight(this.mode === 1 ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(this.mode === 1 ? $r('app.color.accent') : $r('app.color.ink_muted'))
          .onClick(() => this.mode = 1)
        Blank()
      }
      .width('100%')
      .height(52)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 28, right: 28, bottom: 4 })
      .visualEffect(contentLightEffect())

      if (this.mode === 0) {
        this.newsView()
      } else {
        this.videoView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private newsView() {
    if (this.newsLoading && this.news === undefined) {
      Column({ space: 10 }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color($r('app.color.accent'))
        Text('正在获取新闻正文')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.newsError.length > 0 && this.news === undefined) {
      Column({ space: 16 }) {
        Text('新闻源暂时不可用')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.newsError)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
        ImmersiveAction({
          label: '重试',
          actionAccessibilityText: '重新获取新闻',
          icon: $r('sys.symbol.arrow_right'),
          onAction: () => this.loadNews()
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding(30)
    } else if (this.news !== undefined) {
      Swiper() {
        ForEach(this.news?.items ?? [], (item: NewsItem) => {
          NewsArticlePage({
            item: item,
            gatewayUrl: this.gatewayUrl,
            appToken: this.appToken,
            model: this.model
          })
        }, (item: NewsItem) => item.id)
      }
      .index(this.newsIndex)
      .indicator(false)
      .loop(false)
      .duration(MOTION_DURATION)
      .curve(curves.springMotion(0.42, 0.86, 0.16))
      .layoutWeight(1)
      .onChange((index: number) => this.newsIndex = index)
    }
  }

  @Builder
  private videoView() {
    if (this.editorOpen || this.videos.length === 0) {
      Scroll() {
        Column({ space: 22 }) {
          Column() {
            Text('添加你正在看的视频')
              .fontSize(29)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
          }
          .alignItems(HorizontalAlign.Start)

          this.inputField('标题', '例如：日本の朝ごはん', this.draftTitle,
            (value: string) => this.draftTitle = value)
          this.inputField('视频链接', 'https://', this.draftUrl,
            (value: string) => this.draftUrl = value)
          Column({ space: 8 }) {
            Text('字幕或逐字稿')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink_muted'))
            TextArea({ text: this.draftTranscript, placeholder: '粘贴日语字幕' })
              .height(230)
              .fontSize(15)
              .fontColor($r('app.color.ink'))
              .placeholderColor($r('app.color.ink_muted'))
              .backgroundColor(Color.Transparent)
              .border({ width: { left: 2 }, color: $r('app.color.line') })
              .padding({ left: 14, right: 4, top: 8, bottom: 8 })
              .onChange((value: string) => this.draftTranscript = value)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Row({ space: 10 }) {
            if (this.videos.length > 0) {
              ImmersiveAction({
                label: '取消',
                actionAccessibilityText: '取消添加素材',
                icon: $r('sys.symbol.xmark'),
                onAction: () => this.editorOpen = false
              })
            }
            ImmersiveAction({
              label: '保存素材',
              actionAccessibilityText: '保存视频素材',
              icon: $r('sys.symbol.bookmark'),
              emphasized: true,
              onAction: () => this.saveVideo()
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ bottom: FLOATING_TAB_CONTENT_INSET })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 24 })
        .margin({ left: 16, right: 16, top: 12, bottom: 16 })
        .borderRadius(30)
        .clip(true)
        .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    } else {
      Column() {
        Row() {
          Scroll() {
            Row({ space: 18 }) {
              ForEach(this.videos, (video: VideoStudyItem, index: number) => {
                Text(video.title)
                  .fontSize(13)
                  .fontWeight(index === this.videoIndex ? FontWeight.Bold : FontWeight.Regular)
                  .fontColor(index === this.videoIndex ? $r('app.color.ink') : $r('app.color.ink_muted'))
                  .maxLines(1)
                  .onClick(() => this.videoIndex = index)
              }, (video: VideoStudyItem) => video.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
          ImmersiveAction({
            actionAccessibilityText: '添加视频素材',
            icon: $r('sys.symbol.plus'),
            actionSize: 42,
            onAction: () => this.beginVideo()
          })
        }
        .width('100%')
        .padding({ left: 26, right: 20, bottom: 8 })
        .margin({ left: 14, right: 14 })
        .borderRadius(22)
        .backgroundEffect({ radius: 24, color: $r('app.color.immersive_plane'), saturation: 1.06 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())

        VideoStudyPage({
          item: this.videos[Math.min(this.videoIndex, this.videos.length - 1)],
          gatewayUrl: this.gatewayUrl,
          appToken: this.appToken,
          model: this.model
        })
      }
      .layoutWeight(1)
    }
  }

  @Builder
  private inputField(label: string, placeholder: string, value: string, onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_muted'))
      TextInput({ text: value, placeholder: placeholder })
        .height(48)
        .fontSize(15)
        .fontColor($r('app.color.ink'))
        .placeholderColor($r('app.color.ink_muted'))
        .backgroundColor(Color.Transparent)
        .border({ width: { bottom: 0.5 }, color: $r('app.color.line') })
        .padding({ left: 2, right: 2 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
struct NewsArticlePage {
  item: NewsItem = EMPTY_NEWS_ITEM;
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';

  @State private article: NewsArticle | undefined = undefined;
  @State private loading: boolean = false;
  @State private error: string = '';
  @State private aiText: string = '';
  @State private aiLoading: boolean = false;
  @State private aiError: string = '';
  private aiClient?: ResponsesClient;

  aboutToAppear(): void {
    this.load();
  }

  aboutToDisappear(): void {
    this.aiClient?.cancel();
  }

  private load(): void {
    if (this.loading || this.article !== undefined) {
      return;
    }
    this.loading = true;
    this.error = '';
    new NewsClient(this.gatewayUrl, this.appToken).loadArticle(this.item.url).then((article: NewsArticle) => {
      this.article = article;
      this.loading = false;
    }).catch((error: Error) => {
      this.error = error.message;
      this.loading = false;
    });
  }

  private askAi(): void {
    if (this.article === undefined || this.aiLoading) {
      return;
    }
    this.aiText = '';
    this.aiError = '';
    this.aiLoading = true;
    this.aiClient = new ResponsesClient(this.gatewayUrl, this.appToken);
    const input: ResponseInputMessage[] = [{ role: 'user', content: [{
      type: 'input_text',
      text: `请精读下面这篇日语新闻。先用两句中文概括，再解释最多五个新闻日语表达，最后出一个理解问题。\n\n标题：${this.article.title}\n\n${this.article.body.slice(0, 18000)}`
    }] }];
    const body: ResponsesCreateRequest = {
      model: this.model,
      instructions: '你是日语新闻精读老师。只依据提供的原文，不补写新闻事实。保持简洁，输出纯文本。',
      input: input,
      stream: true,
      store: false
    };
    this.aiClient.stream(body, {
      onDelta: (delta: string) => this.aiText += delta,
      onCompleted: (responseId: string) => this.aiLoading = false,
      onError: (message: string) => {
        this.aiLoading = false;
        this.aiError = message;
      }
    }).catch(() => this.aiLoading = false);
  }

  private openOriginal(): void {
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.startAbility({
      action: 'ohos.want.action.viewData',
      uri: this.item.url
    }).catch(() => this.error = '无法打开原文链接');
  }

  build() {
    if (this.loading && this.article === undefined) {
      Column({ space: 10 }) {
        LoadingProgress()
          .width(26)
          .height(26)
          .color($r('app.color.accent'))
        Text('正在展开完整正文')
          .fontSize(13)
          .fontColor($r('app.color.ink_muted'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.article !== undefined) {
      List({ space: 0 }) {
        ListItem() {
          Column({ space: 12 }) {
            Text(compactDate(this.item.publishedAt))
              .fontSize(12)
              .fontColor($r('app.color.accent'))
            Text(this.article?.title ?? this.item.title)
              .fontSize(31)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .lineHeight(42)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 22, right: 22, top: 24, bottom: 24 })
          .margin({ top: 14, bottom: 18 })
          .borderRadius(30)
          .clip(true)
          .backgroundEffect({ radius: 34, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
          .border({ width: 0.5, color: $r('app.color.immersive_edge') })
          .visualEffect(planeLightEffect())
        }
        if ((this.article?.imageUrl ?? '').length > 0) {
          ListItem() {
            Image(this.article?.imageUrl ?? '')
              .width('100%')
              .height(220)
              .objectFit(ImageFit.Cover)
              .borderRadius(26)
              .clip(true)
              .margin({ bottom: 18 })
              .visualEffect(contentLightEffect())
          }
        }
        ForEach((this.article?.body ?? '').split('\n\n'), (paragraph: string, index: number) => {
          ListItem() {
            Text(paragraph)
              .width(index === 0 ? '100%' : (index % 3 === 0 ? '92%' : '97%'))
              .fontSize(index === 0 ? 21 : 18)
              .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
              .lineHeight(index === 0 ? 34 : 31)
              .fontColor($r('app.color.ink'))
              .padding({ top: index === 0 ? 12 : 8, bottom: index === 0 ? 20 : 12 })
              .alignSelf(index % 3 === 0 && index > 0 ? ItemAlign.End : ItemAlign.Start)
              .visualEffect(contentLightEffect())
          }
        }, (paragraph: string, index: number) => index.toString())
        ListItem() {
          Column({ space: 16 }) {
            Row({ space: 10 }) {
              ImmersiveAction({
                label: '阅读原文',
                actionAccessibilityText: '在浏览器中打开新闻原文',
                icon: $r('sys.symbol.arrow_right'),
                onAction: () => this.openOriginal()
              })
              if (!this.aiLoading && this.aiText.length === 0) {
                ImmersiveAction({
                  label: 'AI 精读',
                  actionAccessibilityText: '生成新闻精读',
                  icon: $r('sys.symbol.dot_radiowaves_left_and_right'),
                  emphasized: true,
                  onAction: () => this.askAi()
                })
              }
            }
            InlineAiResult({ title: '新闻精读', text: this.aiText, loading: this.aiLoading, error: this.aiError })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 24, bottom: FLOATING_TAB_CONTENT_INSET })
        }
      }
      .width('100%')
      .height('100%')
        .padding({ left: 26, right: 26 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    } else {
      Column({ space: 14 }) {
        Text('正文没有加载出来')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.error)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
        ImmersiveAction({
          label: '重试正文',
          actionAccessibilityText: '重新加载新闻正文',
          icon: $r('sys.symbol.arrow_right'),
          onAction: () => this.load()
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(30)
    }
  }
}

@Component
struct VideoStudyPage {
  item: VideoStudyItem = EMPTY_VIDEO_ITEM;
  gatewayUrl: string = '';
  appToken: string = '';
  model: string = '';

  @State private aiText: string = '';
  @State private aiLoading: boolean = false;
  @State private aiError: string = '';
  private aiClient?: ResponsesClient;

  aboutToDisappear(): void {
    this.aiClient?.cancel();
  }

  private askAi(): void {
    if (this.item.transcript.trim().length === 0 || this.aiLoading) {
      this.aiError = '先为这段视频添加字幕或逐字稿';
      return;
    }
    this.aiText = '';
    this.aiError = '';
    this.aiLoading = true;
    this.aiClient = new ResponsesClient(this.gatewayUrl, this.appToken);
    const input: ResponseInputMessage[] = [{ role: 'user', content: [{
      type: 'input_text',
      text: `请把这份日语视频字幕整理成学习材料：概括内容，挑选五个自然表达，给出跟读片段。只分析字幕。\n\n标题：${this.item.title}\n\n${this.item.transcript.slice(0, 24000)}`
    }] }];
    const body: ResponsesCreateRequest = {
      model: this.model,
      instructions: '你是日语听力老师。不要声称看过视频画面，不推测字幕外的信息。输出简洁纯文本。',
      input: input,
      stream: true,
      store: false
    };
    this.aiClient.stream(body, {
      onDelta: (delta: string) => this.aiText += delta,
      onCompleted: (responseId: string) => this.aiLoading = false,
      onError: (message: string) => {
        this.aiLoading = false;
        this.aiError = message;
      }
    }).catch(() => this.aiLoading = false);
  }

  build() {
    List({ space: 0 }) {
      ListItem() {
        Column({ space: 10 }) {
          Text('VIDEO')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
            .letterSpacing(1)
          Text(this.item.title)
            .fontSize(31)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .lineHeight(41)
          Text(this.item.url)
            .fontSize(12)
            .fontColor($r('app.color.ink_muted'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 22, right: 22, top: 22, bottom: 22 })
        .margin({ top: 14, bottom: 24 })
        .borderRadius(28)
        .clip(true)
        .backgroundEffect({ radius: 32, color: $r('app.color.immersive_plane_strong'), saturation: 1.08 })
        .border({ width: 0.5, color: $r('app.color.immersive_edge') })
        .visualEffect(planeLightEffect())
      }
      ListItem() {
        Column({ space: 12 }) {
          Text('字幕')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent'))
          if (this.item.transcript.length > 0) {
            ForEach(this.item.transcript.split('\n\n'), (paragraph: string, index: number) => {
              if (paragraph.trim().length > 0) {
                Text(paragraph.trim())
                  .width(index % 2 === 0 ? '100%' : '92%')
                  .fontSize(index === 0 ? 21 : 18)
                  .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
                  .lineHeight(index === 0 ? 34 : 31)
                  .fontColor($r('app.color.ink'))
                  .alignSelf(index % 2 === 0 ? ItemAlign.Start : ItemAlign.End)
                  .visualEffect(contentLightEffect())
              }
            }, (paragraph: string, index: number) => `${index}-${paragraph.length}`)
          } else {
            Text('这条素材还没有字幕。')
              .fontSize(18)
              .lineHeight(31)
              .fontColor($r('app.color.ink_muted'))
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      ListItem() {
        Column({ space: 16 }) {
          if (!this.aiLoading && this.aiText.length === 0) {
            ImmersiveAction({
              label: '分析这份字幕',
              actionAccessibilityText: '生成字幕学习内容',
              icon: $r('sys.symbol.dot_radiowaves_left_and_right'),
              emphasized: true,
              onAction: () => this.askAi()
            })
          }
          InlineAiResult({ title: '字幕学习', text: this.aiText, loading: this.aiLoading, error: this.aiError })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 30, bottom: FLOATING_TAB_CONTENT_INSET })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 26, right: 26 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
