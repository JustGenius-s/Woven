export const APP_HORIZONTAL_PADDING: number = 24;
export const FLOATING_TAB_BAR_HEIGHT: number = 64;
export const FLOATING_TAB_BAR_BOTTOM_MARGIN: number = 12;
export const FLOATING_TAB_CONTENT_INSET: number = 120;
export const CONTENT_MAX_WIDTH: number = 760;
export const MOTION_DURATION: number = 260;

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
