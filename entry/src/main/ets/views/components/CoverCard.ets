import { fileUri } from '@kit.CoreFileKit';
import { FLOATING_ULTRA_THIN_MATERIAL } from '../../common/ImmersiveMaterial';
import { planeLightEffect } from './ImmersiveCanvas';

/**
 * Full-bleed cover used by Explore and Vocabulary. Image fills the card, a
 * dark gradient keeps the light type readable, and the action sits on the
 * same plate as the music / reading / scenario cards.
 */
@Component
export struct CoverCard {
  @Prop artwork: Resource = $r('app.media.vocabulary_n5');
  @Prop artworkPath: string = '';
  @Prop badge: string = '';
  @Prop meta: string = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop caption: string = '';
  @Prop captionLines: number = 1;
  @Prop footer: string = '';
  @Prop actionIcon: Resource = $r('sys.symbol.arrow_right');
  @Prop actionLabel: string = '';
  @Prop actionEnabled: boolean = true;
  @Prop selected: boolean = false;
  @Prop cardHeight: number = 304;
  @Prop coverRatio: number = 0;
  @Prop coverOnly: boolean = false;
  @Prop downloaded: boolean = false;
  onOpen: () => void = () => {};

  build() {
    if (this.coverRatio > 0) {
      Column() {
        this.coverStack()
      }
      .width('100%')
      .aspectRatio(this.coverRatio)
      .backgroundColor(Color.White)
      .borderRadius(28)
      .clip(true)
      .border({
        width: this.selected ? 1.5 : 0.5,
        color: this.selected ? $r('app.color.accent') : $r('app.color.line')
      })
      .visualEffect(planeLightEffect())
      .accessibilityText(this.accessLabel())
      .onClick(() => this.onOpen())
    } else {
      Column() {
        this.coverStack()
      }
      .width('100%')
      .height(this.cardHeight)
      .borderRadius(28)
      .clip(true)
      .border({
        width: this.selected ? 1.5 : 0.5,
        color: this.selected ? $r('app.color.accent') : $r('app.color.line')
      })
      .visualEffect(planeLightEffect())
      .accessibilityText(this.accessLabel())
      .onClick(() => this.onOpen())
    }
  }

  @Builder
  private coverStack() {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.artworkPath.length > 0) {
        Image(this.coverUri())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.High)
          .syncLoad(true)
          .hitTestBehavior(HitTestMode.None)
      } else {
        Image(this.artwork)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .hitTestBehavior(HitTestMode.None)
      }

      if (this.coverOnly) {
        this.coverOnlyChrome()
      } else {
        this.coverOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private coverOnlyChrome() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('sys.color.icon_primary')])
          .opacity(this.downloaded ? 1 : 0.28)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(Color.Transparent)
      .systemMaterial(FLOATING_ULTRA_THIN_MATERIAL)
      .hitTestBehavior(HitTestMode.None)

      Blank()
      this.coverAction()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(16)
  }

  @Builder
  private coverOverlay() {
    Stack({ alignContent: Alignment.BottomStart }) {
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
          if (this.badge.length > 0) {
            Text(this.badge)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.immersive_light'))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .borderRadius(13)
              .backgroundColor('#6617181A')
          }
          Blank()
          if (this.meta.length > 0) {
            Text(this.meta)
              .fontSize(12)
              .fontColor('#D9F7F8FA')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Blank()

        Text(this.title)
          .width('100%')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.immersive_light'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .width('100%')
            .fontSize(13)
            .fontColor('#D9F7F8FA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 5 })
        }

        if (this.caption.length > 0) {
          Text(this.caption)
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor('#CCF7F8FA')
            .maxLines(this.captionLines)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 5 })
        }

        Row() {
          Text(this.footer)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor('#D9F7F8FA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          this.coverAction()
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
    .height('100%')
  }

  @Builder
  private coverAction() {
    if (this.actionLabel.length > 0) {
      Button(this.actionLabel, { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
        .controlSize(ControlSize.NORMAL)
        .fontColor($r('app.color.ink'))
        .backgroundColor($r('app.color.immersive_light'))
        .enabled(this.actionEnabled)
        .onClick(() => this.onOpen())
    } else if (this.coverOnly) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.actionIcon)
          .fontSize(20)
          .fontColor([$r('sys.color.icon_primary')])
      }
      .width(40)
      .height(40)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(Color.Transparent)
      .systemMaterial(FLOATING_ULTRA_THIN_MATERIAL)
    } else {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.actionIcon)
          .fontSize(24)
          .fontColor([$r('app.color.ink')])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor($r('app.color.immersive_light'))
    }
  }

  private accessLabel(): string {
    if (this.coverOnly) {
      return this.downloaded ? `${this.title}，已下载` : `${this.title}，未下载`;
    }
    return `${this.title}，${this.subtitle}，${this.badge}`;
  }

  private coverUri(): string {
    if (this.artworkPath.indexOf('file://') === 0 || this.artworkPath.indexOf('http') === 0) {
      return this.artworkPath;
    }
    return fileUri.getUriFromPath(this.artworkPath);
  }
}
