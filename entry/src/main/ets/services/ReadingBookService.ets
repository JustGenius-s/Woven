import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { ReadingWork } from '../model/ContentModels';
import { ReadingCloudStore } from './ReadingCloudStore';

export interface ReadingBookFiles {
  pdfPath: string;
  audioPath: string;
  coverPath: string;
}

export interface ReadingLibraryStats {
  total: number;
  ready: number;
  pending: number;
  pendingBytes: number;
}

export interface ReadingDownloadResult {
  downloaded: number;
  skipped: number;
  failed: number;
}

export class ReadingBookService {
  static materialize(context: common.Context, readingId: string): string {
    const safeId: string = ReadingBookService.safeId(readingId);
    const bookDirectory: string = ReadingBookService.bookDirectory(context, safeId);
    const bookPath: string = `${bookDirectory}/${safeId}.epub`;
    try {
      ReadingBookService.ensureDirectory(bookDirectory);
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(`reader/${safeId}.epub`);
      ReadingBookService.writeBytes(bookPath, bytes);
      return bookPath;
    } catch (error) {
      throw new Error(`Unable to prepare reader book: ${safeId}`);
    }
  }

  static materializeCover(context: common.Context, readingId: string, relativePath: string): string {
    return ReadingBookService.materializePdf(context, readingId, relativePath);
  }

  static async materializeCoverAsync(context: common.Context, readingId: string,
    relativePath: string): Promise<string> {
    const safeId: string = ReadingBookService.safeId(readingId);
    const bookDirectory: string = ReadingBookService.bookDirectory(context, safeId);
    const slash: number = relativePath.lastIndexOf('/');
    const fileName: string = slash >= 0 ? relativePath.substring(slash + 1) : relativePath;
    const bookPath: string = `${bookDirectory}/${fileName.length > 0 ? fileName : 'book.pdf'}`;
    try {
      if (await ReadingBookService.fileReadyAsync(bookPath, 0)) {
        return bookPath;
      }
      await ReadingBookService.ensureDirectoryAsync(bookDirectory);
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(relativePath);
      if (bytes.byteLength === 0) {
        throw new Error(`empty rawfile: ${relativePath}`);
      }
      const copy: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset,
        bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      await ReadingBookService.writeBufferAsync(bookPath, copy);
      if ((await fileIo.stat(bookPath)).size <= 0) {
        throw new Error(`empty sandbox file: ${bookPath}`);
      }
      return bookPath;
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : `${error}`;
      throw new Error(`Unable to prepare reader PDF: ${safeId} (${detail})`);
    }
  }

  static materializePdf(context: common.Context, readingId: string, relativePath: string): string {
    const safeId: string = ReadingBookService.safeId(readingId);
    const bookDirectory: string = ReadingBookService.bookDirectory(context, safeId);
    const slash: number = relativePath.lastIndexOf('/');
    const fileName: string = slash >= 0 ? relativePath.substring(slash + 1) : relativePath;
    const bookPath: string = `${bookDirectory}/${fileName.length > 0 ? fileName : 'book.pdf'}`;
    try {
      ReadingBookService.ensureDirectory(bookDirectory);
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(relativePath);
      if (bytes.byteLength === 0) {
        throw new Error(`empty rawfile: ${relativePath}`);
      }
      ReadingBookService.writeBytes(bookPath, bytes);
      const stat: fileIo.Stat = fileIo.statSync(bookPath);
      if (stat.size <= 0) {
        throw new Error(`empty sandbox file: ${bookPath}`);
      }
      return bookPath;
    } catch (error) {
      const detail: string = error instanceof Error ? error.message : `${error}`;
      throw new Error(`Unable to prepare reader PDF: ${safeId} (${detail})`);
    }
  }

  static bookDirectory(context: common.Context, readingId: string): string {
    return `${context.filesDir}/reader/${ReadingBookService.safeId(readingId)}`;
  }

  static localPdfPath(context: common.Context, readingId: string): string {
    return `${ReadingBookService.bookDirectory(context, readingId)}/book.pdf`;
  }

  static localAudioPath(context: common.Context, readingId: string): string {
    return `${ReadingBookService.bookDirectory(context, readingId)}/audio.mp3`;
  }

  static localCoverPath(context: common.Context, work: ReadingWork): string {
    const key: string = work.coverKey ?? '';
    const name: string = key.endsWith('.png') ? 'cover.png' : 'cover.jpg';
    return `${ReadingBookService.bookDirectory(context, work.id)}/${name}`;
  }

  static isCloudBook(work: ReadingWork): boolean {
    return work.pdfKey !== undefined && work.pdfKey.length > 0;
  }

  static isBookReady(context: common.Context, work: ReadingWork): boolean {
    if (!ReadingBookService.isCloudBook(work)) {
      return true;
    }
    if (!ReadingBookService.fileReady(ReadingBookService.localPdfPath(context, work.id),
      work.pdfBytes ?? 0)) {
      return false;
    }
    if (work.audioKey !== undefined && work.audioKey.length > 0) {
      return ReadingBookService.fileReady(ReadingBookService.localAudioPath(context, work.id),
        work.audioBytes ?? 0);
    }
    return true;
  }

  static async isBookReadyAsync(context: common.Context, work: ReadingWork): Promise<boolean> {
    if (!ReadingBookService.isCloudBook(work)) {
      return true;
    }
    if (!await ReadingBookService.fileReadyAsync(ReadingBookService.localPdfPath(context, work.id),
      work.pdfBytes ?? 0)) {
      return false;
    }
    if (work.audioKey !== undefined && work.audioKey.length > 0) {
      return await ReadingBookService.fileReadyAsync(ReadingBookService.localAudioPath(context, work.id),
        work.audioBytes ?? 0);
    }
    return true;
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

  static coverReady(context: common.Context, work: ReadingWork): string {
    if (work.coverKey === undefined || work.coverKey.length === 0) {
      return '';
    }
    const path: string = ReadingBookService.localCoverPath(context, work);
    return ReadingBookService.coverFileReady(path, work) ? path : '';
  }

  static async coverReadyAsync(context: common.Context, work: ReadingWork): Promise<string> {
    if (work.coverKey === undefined || work.coverKey.length === 0) {
      return '';
    }
    const path: string = ReadingBookService.localCoverPath(context, work);
    return await ReadingBookService.coverFileReadyAsync(path, work) ? path : '';
  }

  static async ensureCover(context: common.Context, work: ReadingWork): Promise<string> {
    if (work.coverKey === undefined || work.coverKey.length === 0) {
      return '';
    }
    const path: string = ReadingBookService.localCoverPath(context, work);
    if (await ReadingBookService.coverFileReadyAsync(path, work)) {
      return path;
    }
    await ReadingBookService.ensureDirectoryAsync(ReadingBookService.bookDirectory(context, work.id));
    const bytes: ArrayBuffer = await ReadingCloudStore.downloadObject(work.coverKey);
    if (!ReadingBookService.isImageBuffer(bytes)) {
      throw new Error('封面不是图片');
    }
    await ReadingBookService.writeBufferAsync(path, bytes);
    return path;
  }

  static libraryStats(context: common.Context, works: ReadingWork[]): ReadingLibraryStats {
    let ready: number = 0;
    let pending: number = 0;
    let pendingBytes: number = 0;
    for (let index: number = 0; index < works.length; index++) {
      const work: ReadingWork = works[index];
      if (!ReadingBookService.isCloudBook(work)) {
        continue;
      }
      if (ReadingBookService.isBookReady(context, work)) {
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

  static async downloadAll(context: common.Context, works: ReadingWork[],
    onProgress: (done: number, total: number, title: string) => void,
    shouldContinue: () => boolean): Promise<ReadingDownloadResult> {
    let downloaded: number = 0;
    let skipped: number = 0;
    let failed: number = 0;
    const cloud: ReadingWork[] = [];
    for (let index: number = 0; index < works.length; index++) {
      if (ReadingBookService.isCloudBook(works[index])) {
        cloud.push(works[index]);
      }
    }
    for (let index: number = 0; index < cloud.length; index++) {
      if (!shouldContinue()) {
        break;
      }
      const work: ReadingWork = cloud[index];
      onProgress(index + 1, cloud.length, work.title);
      if (ReadingBookService.isBookReady(context, work)) {
        skipped += 1;
        continue;
      }
      try {
        await ReadingBookService.ensureBook(context, work, (_label: string) => {});
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

  static async ensureBook(context: common.Context, work: ReadingWork,
    onStatus: (label: string) => void): Promise<ReadingBookFiles> {
    if (!ReadingBookService.isCloudBook(work) || work.pdfKey === undefined) {
      throw new Error('这本书没有云端电子书');
    }
    ReadingBookService.ensureDirectory(ReadingBookService.bookDirectory(context, work.id));
    const pdfPath: string = ReadingBookService.localPdfPath(context, work.id);
    if (!ReadingBookService.fileReady(pdfPath, work.pdfBytes ?? 0)) {
      onStatus('正在下载电子书…');
      const bytes: ArrayBuffer = await ReadingCloudStore.downloadObject(work.pdfKey);
      ReadingBookService.writeBuffer(pdfPath, bytes);
    }
    let audioPath: string = '';
    if (work.audioKey !== undefined && work.audioKey.length > 0) {
      audioPath = ReadingBookService.localAudioPath(context, work.id);
      if (!ReadingBookService.fileReady(audioPath, work.audioBytes ?? 0)) {
        onStatus('正在下载朗读…');
        const bytes: ArrayBuffer = await ReadingCloudStore.downloadObject(work.audioKey);
        ReadingBookService.writeBuffer(audioPath, bytes);
      }
    }
    let coverPath: string = '';
    if (work.coverKey !== undefined && work.coverKey.length > 0) {
      coverPath = await ReadingBookService.ensureCover(context, work);
    }
    return {
      pdfPath: pdfPath,
      audioPath: audioPath,
      coverPath: coverPath
    };
  }

  private static coverFileReady(path: string, work: ReadingWork): boolean {
    if (!ReadingBookService.fileReady(path, work.coverBytes ?? 0)) {
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

  private static async coverFileReadyAsync(path: string, work: ReadingWork): Promise<boolean> {
    const expectedBytes: number = work.coverBytes ?? 0;
    return await ReadingBookService.fileReadyAsync(path, expectedBytes, expectedBytes > 0 ? 1 : 40000);
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

  private static writeBytes(path: string, bytes: Uint8Array): void {
    const copy: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset,
      bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
    ReadingBookService.writeBuffer(path, copy);
  }

  private static writeBuffer(path: string, buffer: ArrayBuffer): void {
    if (buffer.byteLength === 0) {
      throw new Error(`empty download: ${path}`);
    }
    const bookFile: fileIo.File = ReadingBookService.openForRewrite(path);
    try {
      const written: number = fileIo.writeSync(bookFile.fd, buffer);
      if (written !== buffer.byteLength) {
        throw new Error(`short write ${written}/${buffer.byteLength}`);
      }
    } finally {
      fileIo.closeSync(bookFile);
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

  private static safeId(readingId: string): string {
    return readingId.replace(/[^A-Za-z0-9_-]/g, '_');
  }

  /** HarmonyOS mkdirSync throws "File exists" even with recursion when the dir is already there. */
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

  /**
   * OpenMode.CREATE fails with "File exists" when the sandbox copy is already there.
   * Prefer truncate-in-place; only CREATE when the file is missing.
   * accessSync returns a boolean (false = missing) and does not throw.
   */
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
