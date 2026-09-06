import {
  BorderRadiusMode, ItemRestriction, LengthMetrics,
  SegmentButton, SegmentButtonOptions, SegmentButtonTextItem
} from '@kit.ArkUI';
import { PdfFitMode } from '../../services/ReaderPreferences';

@Component
export struct PdfFitModeSelector {
  @Prop @Watch('syncSelection') fitMode: PdfFitMode = PdfFitMode.WIDTH;
  onChange: (mode: PdfFitMode) => void = (_mode: PdfFitMode) => {};
  @State private selectedIndexes: number[] = [0];
  @State private options: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '适合宽度' }, { text: '适合高度' }] as ItemRestriction<SegmentButtonTextItem>,
    fontColor: $r('sys.color.font_secondary'),
    selectedFontColor: $r('sys.color.font_primary'),
    fontSize: 14,
    selectedFontSize: 14,
    fontWeight: FontWeight.Regular,
    selectedFontWeight: FontWeight.Medium,
    backgroundColor: Color.Transparent,
    selectedBackgroundColor: $r('sys.color.ohos_id_color_component_normal'),
    borderRadiusMode: BorderRadiusMode.CUSTOM,
    backgroundBorderRadius: LengthMetrics.vp(20),
    itemBorderRadius: LengthMetrics.vp(17),
    buttonPadding: 2,
    textPadding: { left: 8, right: 8, top: 8, bottom: 8 }
  });

  aboutToAppear(): void { this.syncSelection(); }

  private syncSelection(): void {
    this.selectedIndexes = [this.fitMode === PdfFitMode.HEIGHT ? 1 : 0];
  }

  private selectMode(index: number): void {
    if (index < 0 || index > 1) { return; }
    const mode: PdfFitMode = index === 1 ? PdfFitMode.HEIGHT : PdfFitMode.WIDTH;
    this.selectedIndexes = [index];
    if (mode !== this.fitMode) { this.onChange(mode); }
  }

  build() {
    Column({ space: 9 }) {
      Text('页面适配')
        .width('100%').fontSize(13).fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
      SegmentButton({
        options: this.options,
        selectedIndexes: this.selectedIndexes,
        onItemClicked: (index: number) => this.selectMode(index)
      })
        .id('pdf-fit-mode-selector')
        .width('100%').height(44)
      Text(this.fitMode === PdfFitMode.HEIGHT ?
        '页面高度适合阅读区域，宽度按比例缩放。' : '页面宽度适合阅读区域，高度按比例缩放。')
        .width('100%').fontSize(12).lineHeight(18)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
