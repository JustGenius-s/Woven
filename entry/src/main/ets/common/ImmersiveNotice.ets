import {
  BlurStrategy,
  HdsSnackBar,
  SnackBarOperationType
} from '@kit.UIDesignKit';

/** Show transient feedback through the HDS immersive SnackBar surface. */
export function showImmersiveNotice(uiContext: UIContext, title: string, message: string): void {
  try {
    const snackBar: HdsSnackBar = new HdsSnackBar(uiContext);
    snackBar.show(
      {},
      { title: title, content: message },
      { operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY },
      {
        duration: 6000,
        backgroundBlurStyle: BlurStyle.COMPONENT_REGULAR,
        blurStrategy: BlurStrategy.ADAPTIVE,
        isHeightAdaptive: true
      }
    );
  } catch {
    // The caller keeps its local state, so feedback remains recoverable even
    // when an older device cannot create the HDS overlay.
  }
}
