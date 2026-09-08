export interface RailPlacement {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface RailVertex {
  x: number;
  y: number;
  z: number;
  u: number;
  v: number;
}

interface RailPixel {
  x: number;
  y: number;
  depth: number;
}

interface PaintSample {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** All distances are in metres. The rails, axles and painted body share one camera. */
export class SplashRailway {
  private readonly trackX: number = 5;
  private readonly gauge: number = 1.435;
  private readonly wheelRadius: number = 0.42;
  private readonly carLength: number = 12.8;
  private readonly carGap: number = 0.55;
  private readonly yaw: number = 0.32;
  private readonly eyeHeight: number = 3;
  private readonly near: number = 2.4;

  distanceAt(elapsed: number): number {
    return 87 * Math.max(0, Math.min(1, (elapsed - 70) / 2480));
  }

  private vertex(x: number, y: number, z: number, u: number = 0, v: number = 0): RailVertex {
    return { x: x, y: y, z: z, u: u, v: v };
  }

  private depth(p: RailVertex): number {
    return Math.sin(this.yaw) * p.x + Math.cos(this.yaw) * p.z;
  }

  private project(p: RailVertex, art: RailPlacement): RailPixel {
    const depth: number = this.depth(p);
    const focal: number = art.width * 1.25;
    return {
      x: art.x + art.width * 0.5 + focal * (Math.cos(this.yaw) * p.x - Math.sin(this.yaw) * p.z) / depth,
      y: art.y + art.height * 0.56 + focal * (this.eyeHeight - p.y) / depth,
      depth: depth
    };
  }

  private mix(a: RailVertex, b: RailVertex, t: number): RailVertex {
    return this.vertex(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t,
      a.z + (b.z - a.z) * t, a.u + (b.u - a.u) * t, a.v + (b.v - a.v) * t);
  }

  private clipped(vertices: RailVertex[]): RailVertex[] {
    const result: RailVertex[] = [];
    let previous: RailVertex = vertices[vertices.length - 1];
    let previousDepth: number = this.depth(previous);
    for (let i: number = 0; i < vertices.length; i++) {
      const current: RailVertex = vertices[i];
      const currentDepth: number = this.depth(current);
      if ((previousDepth >= this.near) !== (currentDepth >= this.near)) {
        result.push(this.mix(previous, current, (this.near - previousDepth) / (currentDepth - previousDepth)));
      }
      if (currentDepth >= this.near) {
        result.push(current);
      }
      previous = current;
      previousDepth = currentDepth;
    }
    return result;
  }

  private visible(points: RailPixel[], art: RailPlacement): boolean {
    let minX: number = Infinity;
    let maxX: number = -Infinity;
    let minY: number = Infinity;
    let maxY: number = -Infinity;
    for (let i: number = 0; i < points.length; i++) {
      minX = Math.min(minX, points[i].x);
      maxX = Math.max(maxX, points[i].x);
      minY = Math.min(minY, points[i].y);
      maxY = Math.max(maxY, points[i].y);
    }
    return maxX >= art.x && minX <= art.x + art.width && maxY >= art.y && minY <= art.y + art.height;
  }

  private path(ctx: CanvasRenderer, vertices: RailVertex[], art: RailPlacement): boolean {
    const clipped: RailVertex[] = this.clipped(vertices);
    if (clipped.length < 3) {
      return false;
    }
    const points: RailPixel[] = [];
    for (let i: number = 0; i < clipped.length; i++) {
      points.push(this.project(clipped[i], art));
    }
    if (!this.visible(points, art)) {
      return false;
    }
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i: number = 1; i < points.length; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    ctx.closePath();
    return true;
  }

  private fill(ctx: CanvasRenderer, vertices: RailVertex[], art: RailPlacement, color: string): void {
    if (this.path(ctx, vertices, art)) {
      ctx.fillStyle = color;
      ctx.fill();
    }
  }

  private ground(x1: number, x2: number, y: number, z1: number, z2: number): RailVertex[] {
    return [this.vertex(x1, y, z1), this.vertex(x2, y, z1),
      this.vertex(x2, y, z2), this.vertex(x1, y, z2)];
  }

  paintTrack(ctx: CanvasRenderer, art: RailPlacement): void {
    this.fill(ctx, this.ground(this.trackX - 1.65, this.trackX + 1.65, -0.16, 1, 150), art, '#6482A2');
    for (let i: number = 0; i < 1100; i++) {
      const z: number = 2 + (i * 0.718) % 103;
      const x: number = this.trackX + Math.sin(i * 71.37) * 1.55;
      const point: RailPixel = this.project(this.vertex(x, -0.15, z), art);
      if (point.depth < this.near || !this.visible([point], art)) {
        continue;
      }
      const radius: number = art.width * (0.04 + i % 5 * 0.007) / point.depth;
      ctx.fillStyle = i % 3 === 0 ? 'rgba(214,219,215,0.55)' : 'rgba(36,68,101,0.40)';
      ctx.beginPath();
      ctx.ellipse(point.x, point.y, radius, radius * 0.45, i, 0, Math.PI * 2);
      ctx.fill();
    }
    for (let z: number = 110; z >= 2; z -= 0.62) {
      this.fill(ctx, this.ground(this.trackX - 1.13, this.trackX + 1.13, -0.07, z, z + 0.17), art, '#4B6580');
    }
    for (let side: number = -1; side <= 1; side += 2) {
      const x: number = this.trackX + side * this.gauge / 2;
      this.fill(ctx, this.ground(x - 0.055, x + 0.055, -0.025, 1, 150), art, '#274562');
      this.fill(ctx, this.ground(x - 0.033, x + 0.033, 0, 1, 150), art, '#C3CDD0');
      this.fill(ctx, this.ground(x - 0.031, x - 0.008, 0.001, 1, 150), art, '#F0D6BD');
    }
  }

  private triangle(ctx: CanvasRenderer, image: ImageBitmap, source: PaintSample,
    vertices: RailVertex[], pixels: RailPixel[]): void {
    const a: RailVertex = vertices[0];
    const b: RailVertex = vertices[1];
    const c: RailVertex = vertices[2];
    const du1: number = b.u - a.u;
    const dv1: number = b.v - a.v;
    const du2: number = c.u - a.u;
    const dv2: number = c.v - a.v;
    const determinant: number = du1 * dv2 - du2 * dv1;
    if (Math.abs(determinant) < 0.00000001) {
      return;
    }
    const dx1: number = pixels[1].x - pixels[0].x;
    const dy1: number = pixels[1].y - pixels[0].y;
    const dx2: number = pixels[2].x - pixels[0].x;
    const dy2: number = pixels[2].y - pixels[0].y;
    const ma: number = (dx1 * dv2 - dx2 * dv1) / determinant;
    const mb: number = (dy1 * dv2 - dy2 * dv1) / determinant;
    const mc: number = (du1 * dx2 - du2 * dx1) / determinant;
    const md: number = (du1 * dy2 - du2 * dy1) / determinant;
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(pixels[0].x, pixels[0].y);
    ctx.lineTo(pixels[1].x, pixels[1].y);
    ctx.lineTo(pixels[2].x, pixels[2].y);
    ctx.closePath();
    ctx.clip();
    ctx.transform(ma, mb, mc, md, pixels[0].x - ma * a.u - mc * a.v, pixels[0].y - mb * a.u - md * a.v);
    ctx.drawImage(image, source.x, source.y, source.width, source.height, 0, 0, 1, 1);
    ctx.restore();
  }

  private panel(ctx: CanvasRenderer, image: ImageBitmap, source: PaintSample,
    corners: RailVertex[], strips: number, art: RailPlacement): void {
    // Narrow strips approximate projective texture mapping without stretching an
    // entire side-view sprite. Geometry and near-plane clipping remain in 3D.
    for (let i: number = 0; i < strips; i++) {
      const u1: number = i / strips;
      const u2: number = (i + 1) / strips;
      const vertices: RailVertex[] = this.clipped([
        this.mix(corners[0], corners[1], u1), this.mix(corners[0], corners[1], u2),
        this.mix(corners[3], corners[2], u2), this.mix(corners[3], corners[2], u1)
      ]);
      if (vertices.length < 3) {
        continue;
      }
      const pixels: RailPixel[] = [];
      for (let j: number = 0; j < vertices.length; j++) {
        pixels.push(this.project(vertices[j], art));
      }
      if (!this.visible(pixels, art)) {
        continue;
      }
      for (let j: number = 1; j < vertices.length - 1; j++) {
        this.triangle(ctx, image, source, [vertices[0], vertices[j], vertices[j + 1]],
          [pixels[0], pixels[j], pixels[j + 1]]);
      }
    }
  }

  private wheel(ctx: CanvasRenderer, x: number, z: number, distance: number, art: RailPlacement): void {
    const center: RailPixel = this.project(this.vertex(x, this.wheelRadius, z), art);
    if (center.depth < this.near || !this.visible([center], art)) {
      return;
    }
    const rim: RailVertex[] = [];
    for (let i: number = 0; i < 24; i++) {
      const angle: number = i / 24 * Math.PI * 2;
      rim.push(this.vertex(x, this.wheelRadius + Math.cos(angle) * this.wheelRadius,
        z + Math.sin(angle) * this.wheelRadius));
    }
    this.fill(ctx, rim, art, '#21394F');
    ctx.strokeStyle = '#7990A1';
    ctx.lineWidth = Math.max(0.4, art.width * 0.037 / center.depth);
    if (this.path(ctx, rim, art)) {
      ctx.stroke();
    }
    const rotation: number = -distance / this.wheelRadius;
    for (let spoke: number = 0; spoke < 4; spoke++) {
      const angle: number = rotation + spoke * Math.PI / 2;
      const edge: RailPixel = this.project(this.vertex(x,
        this.wheelRadius + Math.cos(angle) * this.wheelRadius * 0.76,
        z + Math.sin(angle) * this.wheelRadius * 0.76), art);
      ctx.beginPath();
      ctx.moveTo(center.x, center.y);
      ctx.lineTo(edge.x, edge.y);
      ctx.stroke();
    }
  }

  private car(ctx: CanvasRenderer, sideImage: ImageBitmap, frontImage: ImageBitmap,
    z: number, leading: boolean, distance: number, art: RailPlacement): void {
    const back: number = z + this.carLength;
    const left: number = this.trackX - 1.45;
    const right: number = this.trackX + 1.45;
    const top: number = 4.30;
    const floor: number = 1.15;
    const cabFloor: number = 0.35;
    if (this.depth(this.vertex(right, 0, back)) < this.near) {
      return;
    }
    const tail: RailPixel = this.project(this.vertex(left, 0, back), art);
    if (tail.depth >= this.near && tail.x > art.x + art.width) {
      return;
    }
    this.fill(ctx, this.ground(left - 0.12, right + 0.12, -0.02, z - 0.1, back + 0.1), art, 'rgba(24,50,80,0.23)');
    const axles: number[] = [2.0, 2.85, this.carLength - 2.85, this.carLength - 2.0];
    for (let i: number = 0; i < axles.length; i++) {
      this.wheel(ctx, this.trackX + this.gauge / 2, z + axles[i], distance, art);
    }
    this.fill(ctx, [this.vertex(left + 0.2, 1.25, z + 0.4), this.vertex(left + 0.2, 1.25, back - 0.4),
      this.vertex(left + 0.2, 0.40, back - 0.4), this.vertex(left + 0.2, 0.40, z + 0.4)], art, '#314D68');
    for (let i: number = 0; i < axles.length; i++) {
      this.wheel(ctx, this.trackX - this.gauge / 2, z + axles[i], distance, art);
    }
    const side: RailVertex[] = [this.vertex(left, top, back, 0, 0), this.vertex(left, top, z, 1, 0),
      this.vertex(left, floor, z, 1, 1), this.vertex(left, floor, back, 0, 1)];
    this.fill(ctx, side, art, '#E4D4BC');
    const sample: PaintSample = { x: sideImage.width * 714 / 2172, y: sideImage.height * 250 / 724,
      width: sideImage.width * 624 / 2172, height: sideImage.height * 217 / 724 };
    const frontDepth: number = Math.max(this.near, this.depth(side[1]));
    const strips: number = Math.max(4, Math.min(24, Math.ceil(190 / frontDepth)));
    this.panel(ctx, sideImage, sample, side, strips, art);
    this.fill(ctx, this.ground(left, right, top, z, back), art, '#CAD5DA');
    this.fill(ctx, this.ground(left + 0.12, right - 0.12, top + 0.035, z + 0.13, back - 0.13), art, '#DEE0D6');
    this.fill(ctx, this.ground(this.trackX - 0.64, this.trackX + 0.64, top + 0.12,
      z + 3.6, z + 5.8), art, '#A2B4C6');
    const face: RailVertex[] = [this.vertex(left, top, z, 0, 0), this.vertex(right, top, z, 1, 0),
      this.vertex(right, cabFloor, z, 1, 1), this.vertex(left, cabFloor, z, 0, 1)];
    if (leading) {
      const silhouette: RailVertex[] = [this.vertex(left + 0.18, top, z), this.vertex(right - 0.18, top, z),
        this.vertex(right, top - 0.18, z), this.vertex(right, cabFloor + 0.13, z),
        this.vertex(right - 0.13, cabFloor, z), this.vertex(left + 0.13, cabFloor, z),
        this.vertex(left, cabFloor + 0.13, z), this.vertex(left, top - 0.18, z)];
      ctx.save();
      if (this.path(ctx, silhouette, art)) {
        ctx.clip();
        this.fill(ctx, face, art, '#D9D5C5');
        // Sample the cab from the user's selected painting, excluding its sky,
        // railway and foreground. The existing ivory/coral side supplies doors.
        const cab: PaintSample = { x: frontImage.width * 515 / 768, y: frontImage.height * 351 / 768,
          width: frontImage.width * 141 / 768, height: frontImage.height * 215 / 768 };
        this.panel(ctx, frontImage, cab, face, 8, art);
      }
      ctx.restore();
    } else {
      this.fill(ctx, face, art, '#586D80');
    }
  }

  paintTrain(ctx: CanvasRenderer, sideImage: ImageBitmap, frontImage: ImageBitmap,
    elapsed: number, opacity: number, art: RailPlacement): void {
    if (opacity <= 0) {
      return;
    }
    const distance: number = this.distanceAt(elapsed);
    const front: number = 46 - distance;
    ctx.save();
    ctx.globalAlpha = ctx.globalAlpha * opacity;
    // Draw the far car first. Each car advances the same distance on the same
    // track; lengths and coupler gaps never scale independently or slide apart.
    for (let car: number = 2; car >= 0; car--) {
      this.car(ctx, sideImage, frontImage, front + car * (this.carLength + this.carGap),
        car === 0, distance, art);
    }
    ctx.restore();
  }
}
