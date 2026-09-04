import { window } from '@kit.ArkUI';

let readerPaperActive: boolean = false;
let mainWindow: window.Window | undefined = undefined;
let restSurfaceColor: string = '#F2F4F7';

export function bindMainWindow(win: window.Window): void {
  mainWindow = win;
}

export function rememberSurfaceColor(color: string): void {
  restSurfaceColor = color;
}

export function isReaderPaperActive(): boolean {
  return readerPaperActive;
}

export function applyReaderPaper(active: boolean): void {
  readerPaperActive = active;
  if (mainWindow === undefined) {
    return;
  }
  try {
    mainWindow.setWindowBackgroundColor(active ? '#FFFFFF' : restSurfaceColor);
  } catch {
  }
}

export const APP_HORIZONTAL_PADDING: number = 24;
export const FLOATING_TAB_BAR_BOTTOM_MARGIN: number = 12;
// Bottom breathing room for scroll content so the floating tab bar (and the
// mini player stacked above it) never covers the last row.
export const FLOATING_TAB_CONTENT_INSET: number = 170;
// Height of the tab bar's gradient mask. HdsTabs defaults it to the floating
// bar height (56vp) plus 16vp; a taller mask fades more content but also sits
// over more of the bar's material layer and visibly dilutes the effect.
export const FLOATING_TAB_MASK_HEIGHT: number = 72;
export const CONTENT_MAX_WIDTH: number = 840;
export const MOTION_DURATION: number = 320;

export function systemGestureInset(avoidAreas: window.UIEnvWindowAvoidAreaInfoVP): number {
  return Math.max(avoidAreas.navigationIndicator.bottomRect.height, avoidAreas.cutout.bottomRect.height,
    avoidAreas.statusBar.bottomRect.height);
}

export function statusBarInset(avoidAreas: window.UIEnvWindowAvoidAreaInfoVP): number {
  return Math.max(avoidAreas.statusBar.topRect.height, avoidAreas.cutout.topRect.height);
}

export function levelAccent(level: string): ResourceColor {
  if (level === 'N5' || level === '入门') {
    return $r('app.color.accent');
  }
  return $r('app.color.ink_muted');
}

export function compactDate(value?: string): string {
  if (value === undefined || value.length < 10) {
    return '时间未知';
  }
  return `${value.slice(5, 7)}.${value.slice(8, 10)}`;
}
