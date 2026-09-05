import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { GrammarAudioTrack, GrammarWork } from '../model/GrammarModels';
import { GrammarCloudStore } from './GrammarCloudStore';

export interface GrammarLessonFiles {
  pdfPath: string;
  coverPath: string;
}

export interface GrammarLibraryStats {
  total: number;
  ready: number;
  pending: number;
  pendingBytes: number;
}

export interface GrammarDownloadResult {
  downloaded: number;
  skipped: number;
  failed: number;
}

export class GrammarBookService {
  static lessonDirectory(context: common.Context, lessonId: string): string {
    return `${context.filesDir}/grammar/${GrammarBookService.safeId(lessonId)}`;
  }

  static localPdfPath(context: common.Context, lessonId: string): string {
    return `${GrammarBookService.lessonDirectory(context, lessonId)}/book.pdf`;
  }

  static localCoverPath(context: common.Context, work: GrammarWork): string {
    const key: string = work.coverKey ?? '';
    const name: string = key.endsWith('.png') ? 'cover.png' : 'cover.jpg';
    return `${GrammarBookService.lessonDirectory(context, work.id)}/${name}`;
  }

  static localTrackPath(context: common.Context, work: GrammarWork, track: GrammarAudioTrack): string {
    return `${GrammarBookService.lessonDirectory(context, work.id)}/audio/${GrammarBookService.safeId(track.id)}.mp3`;
  }

  static imageUri(path: string): string {
    if (path.length === 0) {
      return '';
    }
    if (path.indexOf('file://') === 0 || path.indexOf('http') === 0) {
      return path;
    }
    return fileUri.getUriFromPath(path);
  }

  static isLessonReady(context: common.Context, work: GrammarWork): boolean {
    if (work.pdfKey.length === 0) {
      return false;
    }
    if (!GrammarBookService.fileReady(GrammarBookService.localPdfPath(context, work.id),
      work.pdfBytes ?? 0)) {
      return false;
    }
    for (let index: number = 0; index < work.audioTracks.length; index++) {
      const track: GrammarAudioTrack = work.audioTracks[index];
      if (!GrammarBookService.fileReady(GrammarBookService.localTrackPath(context, work, track),
        track.bytes)) {
        return false;
      }
    }
    return true;
  }

  static async isLessonReadyAsync(context: common.Context, work: GrammarWork): Promise<boolean> {
    if (work.pdfKey.length === 0) {
      return false;
    }
    if (!await GrammarBookService.fileReadyAsync(GrammarBookService.localPdfPath(context, work.id),
      work.pdfBytes ?? 0)) {
      return false;
    }
    for (let index: number = 0; index < work.audioTracks.length; index++) {
      const track: GrammarAudioTrack = work.audioTracks[index];
      if (!await GrammarBookService.fileReadyAsync(GrammarBookService.localTrackPath(context, work, track),
        track.bytes)) {
        return false;
      }
    }
    return true;
  }

  static coverReady(context: common.Context, work: GrammarWork): string {
    if (work.coverKey === undefined || work.coverKey.length === 0) {
      return '';
    }
    const path: string = GrammarBookService.localCoverPath(context, work);
    return GrammarBookService.coverFileReady(path, work) ? path : '';
  }

  static async coverReadyAsync(context: common.Context, work: GrammarWork): Promise<string> {
    if (work.coverKey === undefined || work.coverKey.length === 0) {
      return '';
    }
    const path: string = GrammarBookService.localCoverPath(context, work);
    return await GrammarBookService.coverFileReadyAsync(path, work) ? path : '';
  }

  static async ensureCover(context: common.Context, work: GrammarWork): Promise<string> {
    if (work.coverKey === undefined || work.coverKey.length === 0) {
      return '';
    }
    const path: string = GrammarBookService.localCoverPath(context, work);
    if (await GrammarBookService.coverFileReadyAsync(path, work)) {
      return path;
    }
    await GrammarBookService.ensureDirectoryAsync(GrammarBookService.lessonDirectory(context, work.id));
    const bytes: ArrayBuffer = await GrammarCloudStore.downloadObject(work.coverKey);
    if (!GrammarBookService.isImageBuffer(bytes)) {
      throw new Error('封面不是图片');
    }
    await GrammarBookService.writeBufferAsync(path, bytes);
    return path;
  }

  static libraryStats(context: common.Context, works: GrammarWork[]): GrammarLibraryStats {
    let ready: number = 0;
    let pending: number = 0;
    let pendingBytes: number = 0;
    for (let index: number = 0; index < works.length; index++) {
      const work: GrammarWork = works[index];
      if (GrammarBookService.isLessonReady(context, work)) {
        ready += 1;
      } else {
        pending += 1;
        pendingBytes += work.pdfBytes ?? 0;
        pendingBytes += work.audioBytes ?? 0;
      }
    }
    return {
      total: ready + pending,
      ready: ready,
      pending: pending,
      pendingBytes: pendingBytes
    };
  }

  static async downloadAll(context: common.Context, works: GrammarWork[],
    onProgress: (done: number, total: number, title: string) => void,
    shouldContinue: () => boolean): Promise<GrammarDownloadResult> {
    let downloaded: number = 0;
    let skipped: number = 0;
    let failed: number = 0;
    for (let index: number = 0; index < works.length; index++) {
      if (!shouldContinue()) {
        break;
      }
      const work: GrammarWork = works[index];
      onProgress(index + 1, works.length, work.titleJa.length > 0 ? work.titleJa : work.title);
      if (GrammarBookService.isLessonReady(context, work)) {
        skipped += 1;
        continue;
      }
      try {
        await GrammarBookService.ensureLesson(context, work, (_label: string) => {});
        downloaded += 1;
      } catch (error) {
        failed += 1;
      }
    }
    return {
      downloaded: downloaded,
      skipped: skipped,
      failed: failed
    };
  }

  static async ensureLesson(context: common.Context, work: GrammarWork,
    onStatus: (label: string) => void): Promise<GrammarLessonFiles> {
    if (work.pdfKey.length === 0) {
      throw new Error('这一课没有教材');
    }
    GrammarBookService.ensureDirectory(GrammarBookService.lessonDirectory(context, work.id));
    const pdfPath: string = GrammarBookService.localPdfPath(context, work.id);
    if (!GrammarBookService.fileReady(pdfPath, work.pdfBytes ?? 0)) {
      onStatus('正在下载教材…');
      const bytes: ArrayBuffer = await GrammarCloudStore.downloadObject(work.pdfKey);
      GrammarBookService.writeBuffer(pdfPath, bytes);
    }
    GrammarBookService.ensureDirectory(`${GrammarBookService.lessonDirectory(context, work.id)}/audio`);
    for (let index: number = 0; index < work.audioTracks.length; index++) {
      const track: GrammarAudioTrack = work.audioTracks[index];
      const path: string = GrammarBookService.localTrackPath(context, work, track);
      if (GrammarBookService.fileReady(path, track.bytes)) {
        continue;
      }
      onStatus(`正在下载音频 ${index + 1}/${work.audioTracks.length}…`);
      const bytes: ArrayBuffer = await GrammarCloudStore.downloadObject(track.key);
      GrammarBookService.writeBuffer(path, bytes);
    }
    let coverPath: string = '';
    if (work.coverKey !== undefined && work.coverKey.length > 0) {
      coverPath = await GrammarBookService.ensureCover(context, work);
    }
    return {
      pdfPath: pdfPath,
      coverPath: coverPath
    };
  }

  private static coverFileReady(path: string, work: GrammarWork): boolean {
    if (!GrammarBookService.fileReady(path, work.coverBytes ?? 0)) {
      return false;
    }
    if (work.coverBytes !== undefined && work.coverBytes > 0) {
      return true;
    }
    try {
      return fileIo.statSync(path).size >= 40000;
    } catch (_error) {
      return false;
    }
  }

  private static async coverFileReadyAsync(path: string, work: GrammarWork): Promise<boolean> {
    const expectedBytes: number = work.coverBytes ?? 0;
    return await GrammarBookService.fileReadyAsync(path, expectedBytes, expectedBytes > 0 ? 1 : 40000);
  }

  private static isImageBuffer(buffer: ArrayBuffer): boolean {
    if (buffer.byteLength < 8) {
      return false;
    }
    const bytes: Uint8Array = new Uint8Array(buffer);
    const jpeg: boolean = bytes[0] === 0xFF && bytes[1] === 0xD8;
    const png: boolean = bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E;
    return jpeg || png;
  }

  private static fileReady(path: string, expectedBytes: number): boolean {
    try {
      if (!fileIo.accessSync(path)) {
        return false;
      }
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (stat.size <= 0) {
        return false;
      }
      if (expectedBytes > 0 && stat.size !== expectedBytes) {
        return false;
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  private static async fileReadyAsync(path: string, expectedBytes: number,
    minimumBytes: number = 1): Promise<boolean> {
    try {
      const stat: fileIo.Stat = await fileIo.stat(path);
      if (stat.size < minimumBytes) {
        return false;
      }
      return expectedBytes <= 0 || stat.size === expectedBytes;
    } catch (error) {
      return false;
    }
  }

  private static async writeBufferAsync(path: string, buffer: ArrayBuffer): Promise<void> {
    if (buffer.byteLength === 0) {
      throw new Error(`empty download: ${path}`);
    }
    const exists: boolean = await fileIo.access(path);
    const mode: number = exists ? fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC :
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC;
    const file: fileIo.File = await fileIo.open(path, mode);
    try {
      const written: number = await fileIo.write(file.fd, buffer);
      if (written !== buffer.byteLength) {
        throw new Error(`short write ${written}/${buffer.byteLength}`);
      }
    } finally {
      await fileIo.close(file);
    }
  }

  private static async ensureDirectoryAsync(path: string): Promise<void> {
    try {
      if ((await fileIo.stat(path)).isDirectory()) {
        return;
      }
    } catch (_error) {
      // Missing — create below.
    }
    try {
      await fileIo.mkdir(path, true);
    } catch (error) {
      try {
        if ((await fileIo.stat(path)).isDirectory()) {
          return;
        }
      } catch (_statError) {
        const detail: string = error instanceof Error ? error.message : `${error}`;
        throw new Error(`mkdir failed: ${path} (${detail})`);
      }
      const detail: string = error instanceof Error ? error.message : `${error}`;
      throw new Error(`mkdir failed: ${path} (${detail})`);
    }
  }

  private static writeBuffer(path: string, buffer: ArrayBuffer): void {
    if (buffer.byteLength === 0) {
      throw new Error(`empty download: ${path}`);
    }
    const file: fileIo.File = GrammarBookService.openForRewrite(path);
    try {
      const written: number = fileIo.writeSync(file.fd, buffer);
      if (written !== buffer.byteLength) {
        throw new Error(`short write ${written}/${buffer.byteLength}`);
      }
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static safeId(value: string): string {
    return value.replace(/[^A-Za-z0-9_-]/g, '_');
  }

  private static ensureDirectory(path: string): void {
    try {
      if (fileIo.statSync(path).isDirectory()) {
        return;
      }
    } catch (_error) {
      // Missing — create below.
    }
    try {
      fileIo.mkdirSync(path, true);
    } catch (error) {
      try {
        if (fileIo.statSync(path).isDirectory()) {
          return;
        }
      } catch (_statError) {
        const detail: string = error instanceof Error ? error.message : `${error}`;
        throw new Error(`mkdir failed: ${path} (${detail})`);
      }
      const detail: string = error instanceof Error ? error.message : `${error}`;
      throw new Error(`mkdir failed: ${path} (${detail})`);
    }
  }

  private static openForRewrite(path: string): fileIo.File {
    let exists: boolean = false;
    try {
      exists = fileIo.accessSync(path);
    } catch (_error) {
      exists = false;
    }
    if (exists) {
      return fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    }
    return fileIo.openSync(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
  }
}
