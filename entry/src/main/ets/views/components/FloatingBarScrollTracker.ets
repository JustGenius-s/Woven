const LAST_OFFSETS: Map<string, number> = new Map<string, number>();

export class FloatingBarScrollTracker {
  private key: string;

  constructor(key: string) {
    this.key = key;
  }

  update(scroller: Scroller, onCompactChange: (compact: boolean) => void): void {
    const currentOffset: number = Math.max(0, scroller.currentOffset().yOffset);
    const previousOffset: number = LAST_OFFSETS.get(this.key) ?? 0;
    const delta: number = currentOffset - previousOffset;
    LAST_OFFSETS.set(this.key, currentOffset);

    // Ignore zero-delta updates. Tab switches remount or remeasure at the
    // saved offset and would otherwise snap a horizontal bar back to vertical.
    if (Math.abs(delta) < 0.5) {
      return;
    }
    if (currentOffset <= 0.5) {
      onCompactChange(false);
    } else {
      onCompactChange(delta > 0);
    }
  }
}
