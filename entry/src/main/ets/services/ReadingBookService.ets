import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

export class ReadingBookService {
  static materialize(context: common.Context, readingId: string): string {
    const safeId: string = readingId.replace(/[^A-Za-z0-9_-]/g, '_');
    const bookDirectory: string = `${context.filesDir}/reader/${safeId}`;
    const bookPath: string = `${bookDirectory}/${safeId}.epub`;
    try {
      ReadingBookService.ensureDirectory(bookDirectory);
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(`reader/${safeId}.epub`);
      const bookFile: fileIo.File = ReadingBookService.openForRewrite(bookPath);
      try {
        fileIo.writeSync(bookFile.fd, bytes.buffer as ArrayBuffer);
      } finally {
        fileIo.closeSync(bookFile);
      }
      return bookPath;
    } catch (error) {
      throw new Error(`Unable to prepare reader book: ${safeId}`);
    }
  }

  static materializePdf(context: common.Context, readingId: string, relativePath: string): string {
    const safeId: string = readingId.replace(/[^A-Za-z0-9_-]/g, '_');
    const bookDirectory: string = `${context.filesDir}/reader/${safeId}`;
    const slash: number = relativePath.lastIndexOf('/');
    const fileName: string = slash >= 0 ? relativePath.substring(slash + 1) : relativePath;
    const bookPath: string = `${bookDirectory}/${fileName.length > 0 ? fileName : 'book.pdf'}`;
    try {
      ReadingBookService.ensureDirectory(bookDirectory);
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(relativePath);
      if (bytes.byteLength === 0) {
        throw new Error(`empty rawfile: ${relativePath}`);
      }
      // Copy only the typed-array window — bytes.buffer may be a larger shared slab.
      const copy: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset,
        bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      const bookFile: fileIo.File = ReadingBookService.openForRewrite(bookPath);
      try {
        const written: number = fileIo.writeSync(bookFile.fd, copy);
        if (written !== copy.byteLength) {
          throw new Error(`short write ${written}/${copy.byteLength}`);
        }
      } finally {
        fileIo.closeSync(bookFile);
      }
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
