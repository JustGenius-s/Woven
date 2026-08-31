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
}
