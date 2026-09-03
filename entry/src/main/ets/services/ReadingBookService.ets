import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

export class ReadingBookService {
  static materialize(context: common.Context, readingId: string): string {
    const safeId: string = readingId.replace(/[^A-Za-z0-9_-]/g, '_');
    const bookDirectory: string = `${context.filesDir}/reader/${safeId}`;
    const bookPath: string = `${bookDirectory}/${safeId}.epub`;
    try {
      fileIo.mkdirSync(bookDirectory, true);
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(`reader/${safeId}.epub`);
      const bookFile: fileIo.File = fileIo.openSync(bookPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
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
      fileIo.mkdirSync(bookDirectory, true);
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(relativePath);
      const copy: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset,
        bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
      const bookFile: fileIo.File = fileIo.openSync(bookPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(bookFile.fd, copy);
      } finally {
        fileIo.closeSync(bookFile);
      }
      return bookPath;
    } catch (error) {
      throw new Error(`Unable to prepare reader PDF: ${safeId}`);
    }
  }
}
