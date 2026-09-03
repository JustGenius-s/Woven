import { planeLightEffect } from './ImmersiveCanvas';

/**
 * Full-bleed cover used by Explore and Vocabulary. Image fills the card, a
 * dark gradient keeps the light type readable, and the action sits on the
 * same plate as the music / reading / scenario cards.
 */
@Component
export struct CoverCard {
  @Prop artwork: Resource = $r('app.media.vocabulary_n5');
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
      Image(this.artwork)
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
          if (this.actionLabel.length > 0) {
            Button(this.actionLabel, { type: ButtonType.ROUNDED_RECTANGLE, stateEffect: true })
              .controlSize(ControlSize.NORMAL)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.immersive_light'))
              .enabled(this.actionEnabled)
              .onClick(() => this.onOpen())
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

  private accessLabel(): string {
    return `${this.title}，${this.subtitle}，${this.badge}`;
  }
}
