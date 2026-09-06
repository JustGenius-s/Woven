import { fileUri } from '@kit.CoreFileKit';
import { FLOATING_ULTRA_THIN_MATERIAL } from '../../common/ImmersiveMaterial';
import { SHELF_VIDEO_HEIGHT, SHELF_VIDEO_WIDTH } from './ContentShelf';

@Component
export struct VideoShelfCard {
  @Prop videoId: string = '';
  @Prop title: string = '';
  @Prop duration: string = '';
  @Prop selected: boolean = false;
  @Prop @Watch('resetCover') coverPath: string = '';
  @State private coverFailed: boolean = false;
  onOpen: () => void = () => {};
  onRemove: () => void = () => {};

  private resetCover(): void {
    this.coverFailed = false;
  }

  @Builder
  private cardMenu() {
    Menu() {
      MenuItem({ content: '删除视频', startIcon: $r('sys.symbol.trash') })
        .id(`video-delete-${this.videoId}`)
        .contentFontColor($r('sys.color.warning'))
        .onClick(() => this.onRemove())
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.coverPath.length > 0 && !this.coverFailed) {
        Image(fileUri.getUriFromPath(this.coverPath))
          .id(`video-cover-${this.videoId}`)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .onError(() => this.coverFailed = true)
          .hitTestBehavior(HitTestMode.None)
      }
      Column() {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(12)
            .fontColor([$r('app.color.immersive_light')])
          Text(this.duration)
            .fontSize(11)
            .fontColor($r('app.color.immersive_light'))
        }
        .height(24)
        Blank()
        Text(this.title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .linearGradient({ angle: 180, colors: [['#2617181A', 0], ['#CC17181A', 1]] })
      .id(`video-open-${this.videoId}`)
      .accessibilityText(`播放 ${this.title}`)
      .onClick(() => this.onOpen())
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.more_fill'))
          .fontSize(19)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .id(`video-menu-${this.videoId}`)
      .width(44)
      .height(44)
      .margin(4)
      .backgroundColor(Color.Transparent)
      .systemMaterial(FLOATING_ULTRA_THIN_MATERIAL)
      .accessibilityText(`${this.title}，更多操作`)
      .bindMenu(this.cardMenu())
    }
    .id(`video-card-${this.videoId}`)
    .width(SHELF_VIDEO_WIDTH)
    .height(SHELF_VIDEO_HEIGHT)
    .borderRadius(16)
    .linearGradient({ angle: 135, colors: [['#FF2A3340', 0], ['#FF17181A', 1]] })
    .border({ width: this.selected ? 1.5 : 0.5,
      color: this.selected ? $r('app.color.accent') : $r('app.color.line') })
    .clip(true)
    .bindContextMenu(this.cardMenu(), ResponseType.LongPress)
  }
}
