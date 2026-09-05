// Native splash painter using the generated landscape and train assets.
export const SPLASH_REVEAL_START: number = 2320;
export const SPLASH_REVEAL_DURATION: number = 700;
export const SPLASH_DURATION: number = SPLASH_REVEAL_START + SPLASH_REVEAL_DURATION;
export const SPLASH_WHISTLE_AT: number = 720;

interface ScenePlacement {
  x: number;
  y: number;
  width: number;
  height: number;
}

export class FujiSplashScene {
  private wheelCenters: number[] = [138, 249, 509, 616, 773, 881, 1175, 1279, 1444, 1553, 1810, 1935];

  private clamp(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private ease(value: number): number {
    const t: number = this.clamp(value);
    return t * t * (3 - 2 * t);
  }

  private placement(width: number, height: number): ScenePlacement {
    const scale: number = Math.max(width / 859, height / 1831);
    const artWidth: number = 859 * scale;
    const artHeight: number = 1831 * scale;
    return { x: (width - artWidth) / 2, y: (height - artHeight) * 0.45, width: artWidth, height: artHeight };
  }

  paintBackdrop(ctx: CanvasRenderer, landscape: ImageBitmap, width: number, height: number): void {
    const art: ScenePlacement = this.placement(width, height);
    ctx.drawImage(landscape, art.x, art.y, art.width, art.height);
    // A restrained native scrim keeps the brand legible over detailed artwork.
    const shade: CanvasGradient = ctx.createLinearGradient(0, height * 0.68, 0, height);
    shade.addColorStop(0, 'rgba(13,37,80,0)');
    shade.addColorStop(1, 'rgba(13,37,80,0.3)');
    ctx.fillStyle = shade;
    ctx.fillRect(0, height * 0.68, width, height * 0.32);
  }

  private train(ctx: CanvasRenderer, sprite: ImageBitmap, elapsed: number, width: number, height: number): void {
    const art: ScenePlacement = this.placement(width, height);
    const trainWidth: number = art.width * 1.12;
    // Sample the painted train, excluding the source image's transparent margin.
    // Fractions also work with ImageBitmap's density-adjusted native dimensions.
    const sourceX: number = sprite.width * 10 / 2172;
    const sourceY: number = sprite.height * 180 / 724;
    const sourceWidth: number = sprite.width * 2152 / 2172;
    const sourceHeight: number = sprite.height * 364 / 724;
    const trainHeight: number = trainWidth * 364 / 2152;
    const travel: number = this.clamp((elapsed - 100) / 2210);
    const x: number = -trainWidth - 12 + (width + trainWidth + 24) * travel;
    const railY: number = art.y + art.height * 1152 / 1831;
    const suspension: number = Math.sin(elapsed * 0.032) * art.width / 1700;
    ctx.drawImage(sprite, sourceX, sourceY, sourceWidth, sourceHeight,
      x, railY - trainHeight + suspension, trainWidth, trainHeight);
    const paintScale: number = trainWidth / 2152;
    const distance: number = (width + trainWidth + 24) * travel;
    // Rotate the painted wheel hubs themselves, retaining the original texture
    // and fixed undercarriage. Angular velocity follows distance / wheel radius.
    for (let i: number = 0; i < this.wheelCenters.length; i++) {
      const wheelX: number = this.wheelCenters[i];
      ctx.save();
      ctx.translate(x + (wheelX - 10) * paintScale, railY - 42 * paintScale);
      ctx.scale(paintScale, paintScale);
      ctx.rotate(distance / (36 * paintScale));
      ctx.beginPath();
      ctx.arc(0, 0, 27, 0, Math.PI * 2);
      ctx.clip();
      ctx.drawImage(sprite, (wheelX - 27) / 2172 * sprite.width, 475 / 724 * sprite.height,
        54 / 2172 * sprite.width, 54 / 724 * sprite.height, -27, -27, 54, 54);
      ctx.strokeStyle = 'rgba(219,231,249,0.72)';
      ctx.lineWidth = 2.8;
      for (let spoke: number = 0; spoke < 3; spoke++) {
        ctx.rotate(Math.PI * 2 / 3);
        ctx.beginPath();
        ctx.moveTo(9, 0);
        ctx.lineTo(23, 0);
        ctx.stroke();
      }
      ctx.restore();
    }
    // A warm running light and two fading sound-wave pulses accompany the horn.
    const headX: number = x + trainWidth * 0.965;
    const headY: number = railY - trainHeight * 0.41;
    this.glow(ctx, headX, headY, art.width * 0.036, 0.48, true);
    for (let pulse: number = 0; pulse < 2; pulse++) {
      const phase: number = (elapsed - SPLASH_WHISTLE_AT - 20 - pulse * 500) / 420;
      if (phase > 0 && phase < 1) {
        ctx.save();
        ctx.strokeStyle = `rgba(255,241,210,${0.6 * Math.sin(phase * Math.PI)})`;
        ctx.lineWidth = 1.2 * width / 390;
        for (let ring: number = 0; ring < 3; ring++) {
          ctx.beginPath();
          ctx.arc(headX + 5, headY, (8 + ring * 8 + phase * 17) * width / 390, -0.75, 0.5);
          ctx.stroke();
        }
        ctx.restore();
      }
    }
  }

  private seed(index: number, salt: number): number {
    const value: number = Math.sin(index * 127.1 + salt * 311.7) * 43758.5453;
    return value - Math.floor(value);
  }

  private glow(ctx: CanvasRenderer, x: number, y: number, radius: number, opacity: number,
    warm: boolean = false): void {
    const light: CanvasGradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
    const color: string = warm ? '255,235,196' : '238,244,255';
    light.addColorStop(0, `rgba(${color},${opacity})`);
    light.addColorStop(0.4, `rgba(${color},${opacity * 0.55})`);
    light.addColorStop(1, `rgba(${color},0)`);
    ctx.fillStyle = light;
    ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  private atmosphere(ctx: CanvasRenderer, elapsed: number, art: ScenePlacement): void {
    const t: number = elapsed / 1000;
    ctx.save();
    ctx.translate(art.x, art.y);
    ctx.scale(art.width / 859, art.height / 1831);
    // Existing sunrise, with a slowly breathing halo and moving cloud wisps.
    this.glow(ctx, 82, 758, 106, 0.21 + Math.sin(t * 1.6) * 0.035, true);
    for (let cloud: number = 0; cloud < 3; cloud++) {
      const cx: number = 80 + cloud * 290 + t * (10 + cloud * 4);
      const cy: number = 215 + cloud * 78;
      ctx.save();
      ctx.translate(cx, cy);
      ctx.scale(2.6, 0.43);
      for (let puff: number = 0; puff < 3; puff++) {
        this.glow(ctx, puff * 22, Math.sin(puff * 1.7 + t * 0.3) * 6, 43, 0.19);
      }
      ctx.restore();
    }
    // A continuous, wind-bent plume rises from the painted summit. Each puff
    // fades at both ends of its lifetime, so recycling cannot cause a jump.
    for (let puff: number = 0; puff < 18; puff++) {
      const age: number = (puff / 18 + t * 0.36) % 1;
      const x: number = 514 + 94 * age + Math.sin(age * 8 - t * 0.8) * 25 * age;
      const y: number = 569 - 238 * age;
      const radius: number = 9 + age * 42;
      const alpha: number = Math.pow(Math.sin(age * Math.PI), 0.8) * 0.34;
      const smoke: CanvasGradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
      smoke.addColorStop(0, `rgba(217,223,227,${alpha})`);
      smoke.addColorStop(0.5, `rgba(175,192,210,${alpha * 0.55})`);
      smoke.addColorStop(1, 'rgba(175,192,210,0)');
      ctx.fillStyle = smoke;
      ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
    }
    // Distant birds flap independently instead of sliding as a rigid group.
    for (let bird: number = 0; bird < 5; bird++) {
      const x: number = 196 + bird * 57 + t * (19 + bird * 2);
      const y: number = 402 - bird * 22 + Math.sin(t * 1.3 + bird) * 7;
      const span: number = 10 + bird % 3 * 3;
      const flap: number = Math.sin(t * 7 + bird * 1.8) * 9;
      ctx.strokeStyle = `rgba(56,96,137,${0.48 + bird % 2 * 0.12})`;
      ctx.lineWidth = 1.8;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(x - span, y - flap);
      ctx.quadraticCurveTo(x - 5, y - 4, x, y);
      ctx.quadraticCurveTo(x + 5, y - 4, x + span, y - flap);
      ctx.stroke();
    }
    ctx.restore();
  }

  private water(ctx: CanvasRenderer, elapsed: number, art: ScenePlacement): void {
    const t: number = elapsed / 1000;
    ctx.save();
    ctx.translate(art.x, art.y);
    ctx.scale(art.width / 859, art.height / 1831);
    for (let wave: number = 0; wave < 26; wave++) {
      const phase: number = t * (1.9 + wave % 3 * 0.22) + wave * 1.7;
      const x: number = 30 + this.seed(wave, 8) * 780 + Math.sin(phase * 0.6) * 10;
      const y: number = 928 + this.seed(wave, 9) * 191;
      const length: number = 20 + this.seed(wave, 10) * 85;
      ctx.strokeStyle = `rgba(255,242,212,${0.10 + (Math.sin(phase) + 1) * 0.15})`;
      ctx.lineWidth = 1.3 + this.seed(wave, 4) * 1.3;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.bezierCurveTo(x + length * 0.3, y - 2, x + length * 0.7, y + 2, x + length, y);
      ctx.stroke();
    }
    // Sunlight catches the lake in a loose, changing column of highlights.
    for (let fleck: number = 0; fleck < 12; fleck++) {
      const phase: number = t * 3 + fleck * 1.9;
      this.glow(ctx, 82 + Math.sin(fleck * 3.7) * (8 + fleck * 2), 935 + fleck * 14,
        5 + fleck % 3 * 2, 0.24 + Math.sin(phase) * 0.15, true);
    }
    // Two small ripples expand, then disappear into the painted water.
    for (let ripple: number = 0; ripple < 2; ripple++) {
      const age: number = (t * 0.5 + ripple * 0.47) % 1;
      ctx.strokeStyle = `rgba(229,244,255,${Math.sin(age * Math.PI) * 0.25})`;
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.ellipse(365 + ripple * 225, 995 + ripple * 82, 4 + age * 45, 1 + age * 9,
        0, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  private petals(ctx: CanvasRenderer, elapsed: number, art: ScenePlacement, foreground: boolean): void {
    const t: number = elapsed / 1000;
    const count: number = foreground ? 32 : 24;
    ctx.save();
    ctx.translate(art.x, art.y);
    ctx.scale(art.width / 859, art.height / 1831);
    for (let i: number = 0; i < count; i++) {
      const seed: number = i + (foreground ? 50 : 0);
      const fallSpeed: number = foreground ? 125 + this.seed(seed, 2) * 105 : 55 + this.seed(seed, 2) * 50;
      const startY: number = this.seed(seed, 3) * 1840 - 280;
      const y: number = startY + t * fallSpeed;
      const breeze: number = Math.sin(t * 1.8 + seed) * (foreground ? 31 : 14);
      const wake: number = this.ease((t - 0.5) / 0.9) * Math.exp(-Math.pow((startY - 1020) / 200, 2)) * 90;
      const x: number = this.seed(seed, 1) * 1000 - 80 + t * 32 + breeze + wake;
      const size: number = foreground ? 8 + this.seed(seed, 4) * 8 : 3 + this.seed(seed, 4) * 4;
      ctx.save();
      ctx.globalAlpha = foreground ? 0.88 : 0.56;
      ctx.translate(x, y);
      ctx.rotate(seed * 1.4 + t * (0.9 + this.seed(seed, 5) * 1.6));
      ctx.scale(size / 10 * Math.cos(t * 2.3 + seed), size / 10);
      const pink: CanvasGradient = ctx.createLinearGradient(-7, -9, 7, 11);
      pink.addColorStop(0, '#FFF0DB');
      pink.addColorStop(0.45, '#F6BDB7');
      pink.addColorStop(1, '#ED8E9F');
      ctx.fillStyle = pink;
      ctx.fill(new Path2D('M0-9 C-7-10-10-3-7 4 Q-4 9 0 11 Q8 7 8 0 Q7-8 2-9 L0-6Z'));
      ctx.strokeStyle = 'rgba(255,242,222,0.5)';
      ctx.lineWidth = 0.65;
      ctx.beginPath();
      ctx.moveTo(0, 7);
      ctx.quadraticCurveTo(-2, 1, 0, -5);
      ctx.stroke();
      ctx.restore();
    }
    ctx.restore();
  }

  private spiral(ctx: CanvasRenderer, width: number, height: number, progress: number): void {
    if (progress <= 0) {
      return;
    }
    const p: number = this.ease(progress);
    const radius: number = Math.sqrt(width * width + height * height) * 0.76 * p;
    const cx: number = width * 0.51;
    const cy: number = height * 0.47;
    const turn: number = -0.8 + p * 1.5;
    // Two broad curved ribbons unfurl from the same center; the landscape
    // stays level. Translucent erasure softens the aperture's edges.
    for (let arm: number = 0; arm < 2; arm++) {
      ctx.beginPath();
      for (let step: number = 0; step <= 72; step++) {
        const u: number = step / 72;
        const angle: number = turn + arm * Math.PI + u * 3.8;
        const r: number = radius * u;
        const x: number = cx + Math.cos(angle) * r;
        const y: number = cy + Math.sin(angle) * r;
        if (step === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.globalCompositeOperation = 'destination-out';
      for (let edge: number = 4; edge >= 0; edge--) {
        ctx.lineWidth = Math.max(0.1, radius * (0.22 + p * 0.75) + edge * 3);
        ctx.strokeStyle = edge === 0 ? '#000000' : 'rgba(0,0,0,0.094)';
        ctx.stroke();
      }
    }
    // Fade the final corners to transparency before the component unmounts.
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = `rgba(0,0,0,${this.ease((progress - 0.56) / 0.44)})`;
    ctx.fillRect(0, 0, width, height);
    ctx.globalCompositeOperation = 'source-over';
  }

  paintFrame(ctx: CanvasRenderer, backdrop: ImageBitmap, train: ImageBitmap,
    width: number, height: number, elapsed: number): void {
    ctx.clearRect(0, 0, width, height);
    if (elapsed >= SPLASH_DURATION) {
      return;
    }
    ctx.drawImage(backdrop, 0, 0, width, height);
    const art: ScenePlacement = this.placement(width, height);
    this.atmosphere(ctx, elapsed, art);
    this.water(ctx, elapsed, art);
    this.petals(ctx, elapsed, art, false);
    this.train(ctx, train, elapsed, width, height);
    this.petals(ctx, elapsed, art, true);
    const reveal: number = this.clamp((elapsed - SPLASH_REVEAL_START) / SPLASH_REVEAL_DURATION);
    this.spiral(ctx, width, height, reveal);
  }
}
