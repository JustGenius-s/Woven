/** Bounded FIFO for PCM bytes. Partial native buffers retain their exact sample order. */
export class RealtimePcmQueue {
  private chunks: Uint8Array[] = [];
  private offset: number = 0;
  length: number = 0;
  private limit: number;

  constructor(limit: number) { this.limit = limit; }

  append(bytes: Uint8Array): void {
    if (this.length + bytes.length > this.limit) { throw new Error('实时音频积压，请重新连接'); }
    if (bytes.length === 0) { return; }
    this.chunks.push(bytes.slice());
    this.length += bytes.length;
  }

  read(target: Uint8Array): number {
    target.fill(0);
    let written: number = 0;
    while (written < target.length && this.chunks.length > 0) {
      const first: Uint8Array = this.chunks[0];
      const count: number = Math.min(target.length - written, first.length - this.offset);
      target.set(first.subarray(this.offset, this.offset + count), written);
      this.offset += count;
      written += count;
      this.length -= count;
      if (this.offset === first.length) { this.chunks.shift(); this.offset = 0; }
    }
    return written;
  }

  clear(): void { this.chunks = []; this.offset = 0; this.length = 0; }
}
