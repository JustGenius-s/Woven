import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x4b4f;
const TAG: string = 'KotobaMusic';

/**
 * Official AVPlayer states. Kept as a local union so the state machine can be
 * reasoned about on its own, without reaching back into the media namespace.
 */
export type PlayerState = media.AVPlayerState;

const STATE_TIMEOUT_MS: number = 5000;

interface PendingWaiter {
  target: PlayerState;
  resolve: (reached: boolean) => void;
  timer: number;
}

/**
 * Tracks AVPlayer's state machine and exposes awaitable transitions.
 *
 * AVPlayer only allows certain operations per state, and several of those
 * transitions are asynchronous and reported through the `stateChange` event:
 *
 * - `url` / `fdSrc` / `dataSrc` may only be set in **idle**.
 * - `audioRendererInfo` may only be set in **initialized**, before `prepare()`.
 * - `prepare()` must only be called **after** `stateChange` has reported
 *   `initialized`; calling it earlier fails with 5400102 (Operate Not Permit).
 * - `reset()` is only valid from initialized/prepared/playing/paused/
 *   completed/stopped/error.
 *
 * Calling `prepare()` right after assigning `fdSrc` is therefore a race: the
 * state has not reached `initialized` yet. This class removes that race by
 * making callers await the transition instead of assuming it happened.
 */
export class PlayerStateMachine {
  private current: PlayerState = 'idle';
  private waiters: PendingWaiter[] = [];

  /** Current known state, as reported by the `stateChange` event. */
  get state(): PlayerState {
    return this.current;
  }

  /**
   * Records a transition reported by AVPlayer and wakes anyone waiting for it.
   */
  onStateChange(state: PlayerState): void {
    if (this.current !== state) {
      hilog.info(DOMAIN, TAG, 'state: %{public}s -> %{public}s', this.current, state);
    }
    this.current = state;
    const settled: PendingWaiter[] = [];
    for (let index: number = this.waiters.length - 1; index >= 0; index--) {
      const waiter: PendingWaiter = this.waiters[index];
      if (waiter.target === state || state === 'error' || state === 'released') {
        settled.push(waiter);
        this.waiters.splice(index, 1);
      }
    }
    for (let index: number = 0; index < settled.length; index++) {
      clearTimeout(settled[index].timer);
      // Only an exact match counts as success; error/released abort the wait.
      settled[index].resolve(settled[index].target === state);
    }
  }

  /**
   * Resolves true once AVPlayer reports `target`, or false on timeout, error,
   * release, or when `isCancelled` becomes true. Never rejects, so callers can
   * keep control flow linear.
   */
  waitFor(target: PlayerState, isCancelled: () => boolean): Promise<boolean> {
    if (isCancelled()) {
      hilog.info(DOMAIN, TAG, 'wait %{public}s: cancelled before start', target);
      return Promise.resolve(false);
    }
    if (this.current === target) {
      return Promise.resolve(true);
    }
    if (this.current === 'error' || this.current === 'released') {
      hilog.info(DOMAIN, TAG, 'wait %{public}s: aborted, state=%{public}s', target, this.current);
      return Promise.resolve(false);
    }
    return new Promise<boolean>((resolve: (reached: boolean) => void) => {
      const waiter: PendingWaiter = {
        target: target,
        resolve: resolve,
        timer: 0
      };
      waiter.timer = setTimeout(() => {
        this.remove(waiter);
        hilog.warn(DOMAIN, TAG, 'wait %{public}s: TIMEOUT, state=%{public}s', target, this.current);
        resolve(false);
      }, STATE_TIMEOUT_MS);
      hilog.info(DOMAIN, TAG, 'wait %{public}s: awaiting from %{public}s', target, this.current);
      this.waiters.push(waiter);
    });
  }

  /**
   * Brings the player back to `idle` so a new source can be assigned.
   * `reset()` is invalid from `idle` and `released`, and a freshly created
   * player is already idle, so both are no-ops here.
   */
  async resetIfNeeded(player: media.AVPlayer): Promise<boolean> {
    if (this.current === 'idle') {
      return true;
    }
    try {
      await player.reset();
    } catch (error) {
      return false;
    }
    // reset() lands in idle, but the transition is event-driven.
    return this.waitFor('idle', () => false);
  }

  /**
   * Drops every pending waiter. Used when the owning service is torn down or
   * supersedes an in-flight load, so stale promises cannot resolve later.
   */
  cancelAll(): void {
    const settled: PendingWaiter[] = this.waiters.slice();
    this.waiters.length = 0;
    for (let index: number = 0; index < settled.length; index++) {
      clearTimeout(settled[index].timer);
      settled[index].resolve(false);
    }
  }

  private remove(waiter: PendingWaiter): void {
    const index: number = this.waiters.indexOf(waiter);
    if (index >= 0) {
      this.waiters.splice(index, 1);
    }
  }
}

/**
 * Audio usage shared by every track. Assigned in `initialized`, before the
 * first `prepare()`, which is the only point where AVPlayer accepts it.
 */
export function musicRendererInfo(): audio.AudioRendererInfo {
  return {
    usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
    rendererFlags: 0
  };
}
