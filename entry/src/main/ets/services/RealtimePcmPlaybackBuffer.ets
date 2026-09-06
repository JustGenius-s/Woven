import { RealtimePcmQueue } from './RealtimePcmQueue';

/** Mono PCM16 at 24 kHz. Absorb packet jitter before feeding the native renderer. */
export class RealtimePcmPlaybackBuffer {
  private queue = new RealtimePcmQueue(480000);
  private playing: boolean = false;
  private finished: boolean = false;
  private fadeInRemaining: number = 0;
  private readyAt: number = 0;
  private readonly prefillMs: number = 80;
  private readonly prefillBytes: number = 3840; // 80 ms of audio for startup/rebuffer.
  private readonly fadeSamples: number = 120; // 5 ms at stream boundaries only.

  get length(): number { return this.queue.length; }

  append(bytes: Uint8Array): void {
    if (bytes.length === 0) { return; }
    if (!this.playing && this.queue.length === 0) { this.readyAt = Date.now() + this.prefillMs; }
    this.queue.append(bytes);
    this.finished = false;
  }

  finish(): void { this.finished = true; }

  read(target: Uint8Array): number {
    target.fill(0);
    // Never split a PCM16 sample, even if a native buffer has an odd capacity.
    const capacity: number = target.length - target.length % 2;
    if (capacity === 0 || this.queue.length === 0) { return 0; }
    if (!this.playing) {
      // Also wait in time: a large first packet can otherwise be exhausted
      // before the next network packet arrives, despite passing the byte threshold.
      if (!this.finished && (Date.now() < this.readyAt ||
        this.queue.length < Math.max(this.prefillBytes, capacity + this.fadeSamples * 2))) {
        return 0;
      }
      this.playing = true;
      this.fadeInRemaining = this.fadeSamples;
    }

    // Keep a short tail while streaming, so an underrun can end smoothly.
    // A completed response drains immediately, including one shorter than the prefill.
    const ending: boolean = this.finished ? this.queue.length <= capacity :
      this.queue.length < capacity + this.fadeSamples * 2;
    const written: number = this.queue.read(target.subarray(0, capacity));
    const samples: number = written / 2;
    const view = new DataView(target.buffer, target.byteOffset, written);
    const fadeOutSamples: number = ending ? Math.min(samples, this.fadeSamples) : 0;
    for (let i: number = 0; i < samples; i++) {
      let gain: number = 1;
      if (this.fadeInRemaining > 0) {
        gain *= (this.fadeSamples - this.fadeInRemaining) / (this.fadeSamples - 1);
        this.fadeInRemaining--;
      }
      if (fadeOutSamples > 0 && i >= samples - fadeOutSamples) {
        gain *= fadeOutSamples > 1 ? (samples - 1 - i) / (fadeOutSamples - 1) : 0;
      }
      if (gain < 1) { view.setInt16(i * 2, Math.round(view.getInt16(i * 2, true) * gain), true); }
    }
    if (ending) { this.playing = false; this.readyAt = Date.now() + this.prefillMs; }
    return written;
  }

  clear(): void {
    this.queue.clear();
    this.playing = false;
    this.finished = false;
    this.fadeInRemaining = 0;
    this.readyAt = 0;
  }
}
