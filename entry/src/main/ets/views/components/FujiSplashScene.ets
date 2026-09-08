import { RailPlacement, SplashRailway } from './SplashRailway';

// Independent painted layers reveal the live app as the train passes the viewer.
export const SPLASH_REVEAL_START: number = 2120;
export const SPLASH_REVEAL_DURATION: number = 980;
export const SPLASH_DURATION: number = SPLASH_REVEAL_START + SPLASH_REVEAL_DURATION;
export const SPLASH_WHISTLE_AT: number = 920;
export const SPLASH_TITLE_HIDE_AT: number = 1780;

export interface SplashMotion {
  trainDistance: number;
  trainOpacity: number;
  landscapeOpacity: number;
  curtainProgress: number;
  curtainOpacity: number;
}

export class FujiSplashScene {
  private railway: SplashRailway = new SplashRailway();
  motionAt(elapsed: number): SplashMotion {
    return {
      trainDistance: this.railway.distanceAt(elapsed),
      trainOpacity: this.ease(elapsed / 260) * (1 - this.ease((elapsed - 2080) / 520)),
      landscapeOpacity: 1 - this.ease((elapsed - SPLASH_REVEAL_START) / 740),
      curtainProgress: this.ease((elapsed - 2180) / 920),
      curtainOpacity: 1 - this.ease((elapsed - 2440) / 660)
    };
  }

  private clamp(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private ease(value: number): number {
    const t: number = this.clamp(value);
    return t * t * (3 - 2 * t);
  }

  private placement(width: number, height: number): RailPlacement {
    const scale: number = Math.max(width / 859, height / 1831);
    const artWidth: number = 859 * scale;
    const artHeight: number = 1831 * scale;
    return { x: (width - artWidth) / 2, y: (height - artHeight) * 0.45, width: artWidth, height: artHeight };
  }

  paintBackdrop(ctx: CanvasRenderer, landscape: ImageBitmap, width: number, height: number): void {
    const art: RailPlacement = this.placement(width, height);
    ctx.drawImage(landscape, art.x, art.y, art.width, art.height);
    this.railway.paintTrack(ctx, art);
    // A restrained native scrim keeps the brand legible over detailed artwork.
    const shade: CanvasGradient = ctx.createLinearGradient(0, height * 0.68, 0, height);
    shade.addColorStop(0, 'rgba(13,37,80,0)');
    shade.addColorStop(1, 'rgba(13,37,80,0.3)');
    ctx.fillStyle = shade;
    ctx.fillRect(0, height * 0.68, width, height * 0.32);
  }

  paintCurtainLayer(ctx: CanvasRenderer, frame: ImageBitmap, width: number, height: number): void {
    ctx.save();
    ctx.clearRect(0, 0, width, height);
    ctx.drawImage(frame, 0, 0, width, height);
    // Feather the painted border into a transparent central opening. This is
    // cached once; only the two finished border halves move during playback.
    const edges: CanvasGradient = ctx.createLinearGradient(0, 0, width, 0);
    edges.addColorStop(0, '#000000');
    edges.addColorStop(0.09, '#000000');
    edges.addColorStop(0.25, 'rgba(0,0,0,0.7)');
    edges.addColorStop(0.39, 'rgba(0,0,0,0)');
    edges.addColorStop(0.61, 'rgba(0,0,0,0)');
    edges.addColorStop(0.80, 'rgba(0,0,0,0.65)');
    edges.addColorStop(0.92, '#000000');
    edges.addColorStop(1, '#000000');
    ctx.globalCompositeOperation = 'destination-in';
    ctx.fillStyle = edges;
    ctx.fillRect(0, 0, width, height);
    // The border painting's former horizontal railway must never appear over
    // the new perspective track or move sideways with the foreground branches.
    const trackGap: CanvasGradient = ctx.createLinearGradient(0, height * 0.55, 0, height * 0.76);
    trackGap.addColorStop(0, 'rgba(0,0,0,0)');
    trackGap.addColorStop(0.24, '#000000');
    trackGap.addColorStop(0.72, '#000000');
    trackGap.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = trackGap;
    ctx.fillRect(0, height * 0.55, width, height * 0.21);
    ctx.restore();
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

  private atmosphere(ctx: CanvasRenderer, elapsed: number, art: RailPlacement): void {
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

  private water(ctx: CanvasRenderer, elapsed: number, art: RailPlacement): void {
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

  private petals(ctx: CanvasRenderer, elapsed: number, art: RailPlacement, foreground: boolean,
    opening: number = 0): void {
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
      const originX: number = this.seed(seed, 1) * 1000 - 80;
      const outward: number = (originX < 429 ? -1 : 1) * opening * (foreground ? 420 : 180);
      const x: number = originX + t * 32 + breeze + wake + outward;
      const size: number = foreground ? 8 + this.seed(seed, 4) * 8 : 3 + this.seed(seed, 4) * 4;
      ctx.save();
      ctx.globalAlpha = ctx.globalAlpha * (foreground ? 0.88 : 0.56);
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

  private cherryCurtains(ctx: CanvasRenderer, trees: ImageBitmap, elapsed: number,
    art: RailPlacement, motion: SplashMotion): void {
    if (motion.curtainOpacity <= 0) {
      return;
    }
    for (let side: number = 0; side < 2; side++) {
      const direction: number = side === 0 ? -1 : 1;
      const open: number = motion.curtainProgress;
      const breeze: number = Math.sin(elapsed / 1300 + side * 1.7) * 0.002;
      ctx.save();
      ctx.globalAlpha = motion.curtainOpacity;
      ctx.translate(art.x + side * art.width + direction * open * art.width * 0.54,
        art.y + art.height * 0.54 + open * art.height * 0.012);
      ctx.rotate(breeze + direction * open * 0.018);
      ctx.scale(1 + open * 0.025, 1 + open * 0.025);
      // The sprite has an empty central gutter: splitting it cannot sever a
      // branch or carry an opaque piece of mountain into the opening curtains.
      ctx.drawImage(trees, side * trees.width / 2, 0, trees.width / 2, trees.height,
        side === 0 ? 0 : -art.width / 2, -art.height * 0.54, art.width / 2, art.height);
      ctx.restore();
    }
  }

  paintFrame(ctx: CanvasRenderer, backdrop: ImageBitmap, train: ImageBitmap, front: ImageBitmap, trees: ImageBitmap,
    width: number, height: number, elapsed: number): void {
    // The first browser frame can predate the playback request slightly.
    // Clamp before calculating particle ages or fractional opacity powers.
    elapsed = Math.max(0, elapsed);
    ctx.clearRect(0, 0, width, height);
    if (elapsed >= SPLASH_DURATION) {
      return;
    }
    const art: RailPlacement = this.placement(width, height);
    const motion: SplashMotion = this.motionAt(elapsed);
    ctx.save();
    ctx.globalAlpha = motion.landscapeOpacity;
    ctx.drawImage(backdrop, 0, 0, width, height);
    this.atmosphere(ctx, elapsed, art);
    this.water(ctx, elapsed, art);
    this.petals(ctx, elapsed, art, false);
    ctx.restore();
    this.railway.paintTrain(ctx, train, front, elapsed, motion.trainOpacity, art);
    this.cherryCurtains(ctx, trees, elapsed, art, motion);
    ctx.save();
    ctx.globalAlpha = motion.curtainOpacity;
    this.petals(ctx, elapsed, art, true, motion.curtainProgress);
    ctx.restore();
  }
}
