import { LengthMetrics } from '@kit.ArkUI';
import { OperationType, SubHeader } from '@ohos.arkui.advanced.SubHeader';

export const SHELF_COVER_WIDTH: number = 124;
export const SHELF_COVER_HEIGHT: number = 178;
export const SHELF_LEVEL_WIDTH: number = 132;
export const SHELF_LEVEL_HEIGHT: number = 176;
export const SHELF_VIDEO_WIDTH: number = 168;
export const SHELF_VIDEO_HEIGHT: number = 108;

/**
 * Official SubHeader for a content group. The page owns the horizontal
 * List so ForEach stays in that page's build tree.
 */
@Component
export struct ContentShelf {
  title: string = '';
  meta: string = '';

  build() {
    SubHeader({
      primaryTitle: this.title,
      operationType: OperationType.BUTTON,
      operationItem: this.meta.length > 0 ? [{ value: this.meta }] : undefined,
      contentMargin: {
        start: LengthMetrics.vp(16),
        end: LengthMetrics.vp(16)
      }
    })
  }
}
