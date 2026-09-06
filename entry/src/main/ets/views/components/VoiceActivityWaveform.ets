import { AnimatorResult } from '@kit.ArkUI';

/** An output activity indicator, independent of microphone input or volume. */
@Component
export struct VoiceActivityWaveform {
  @Prop @Watch('syncAnimation') active: boolean = false;
  @State private phase: number = 0;
  private readonly bars: number[] = [0, 1, 2, 3, 4];
  private driver?: AnimatorResult;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.syncAnimation();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.stopAnimation();
  }

  private syncAnimation(): void {
    if (!this.mounted || !this.active) {
      this.stopAnimation();
      return;
    }
    if (this.driver !== undefined) { return; }
    const driver: AnimatorResult = this.getUIContext().createAnimator({
      duration: 960,
      easing: 'linear',
      delay: 0,
      fill: 'none',
      direction: 'normal',
      iterations: -1,
      begin: 0,
      end: Math.PI * 2
    });
    this.driver = driver;
    driver.onFrame = (phase: number) => {
      // Ignore any queued frame from a popup that has closed or been recreated.
      if (this.mounted && this.active && this.driver === driver) { this.phase = phase; }
    };
    driver.setExpectedFrameRateRange({ min: 30, max: 30, expected: 30 });
    driver.play();
  }

  private stopAnimation(): void {
    const driver: AnimatorResult | undefined = this.driver;
    this.driver = undefined;
    driver?.cancel();
    this.phase = 0;
  }

  private barScale(index: number): number {
    return 0.25 + (Math.sin(this.phase + index * 1.1) + 1) * 0.375;
  }

  build() {
    Row({ space: 2 }) {
      ForEach(this.bars, (index: number) => {
        Rect().width(2).height(18).radius(1)
          .fill($r('sys.color.icon_primary'))
          // Transform fixed-size bars without changing the popup or button layout.
          .scale({ y: this.barScale(index) })
      }, (index: number) => index.toString())
    }
    .width(18).height(18)
    .alignItems(VerticalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no-hide-descendants')
  }
}
