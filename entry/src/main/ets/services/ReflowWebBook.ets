import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { NativeReaderTrial } from './NativeReaderTrial';
import { WEB_REFLOW_BASE_BYTES, WEB_REFLOW_CACHE, WEB_REFLOW_CHAPTERS,
  WEB_REFLOW_PATCH_BYTES } from './WebReflowContent';

export class ReflowWebBook {
  static async prepare(context: common.Context): Promise<string> {
    const directory: string = `${context.filesDir}/reader-web/${WEB_REFLOW_CACHE}`;
    const marker: string = `${directory}/ready`;
    if (await fileIo.access(marker)) {
      return directory;
    }
    await fileIo.mkdir(directory, true);
    const archive: string = `${directory}/base.zip`;
    // Full semantic books contain all assets. The optional base supports the
    // earlier two-page trial without extracting an unused EPUB for full books.
    if (WEB_REFLOW_BASE_BYTES > 0) {
      const edition = NativeReaderTrial.edition('yaramaika-reflow');
      if (edition.fileBytes !== WEB_REFLOW_BASE_BYTES) {
        throw new Error('教材内容与排版资源版本不一致，请更新应用。');
      }
      const epub: string = await NativeReaderTrial.materialize(context, edition);
      await fileIo.copyFile(epub, archive);
      await zlib.decompressFile(archive, directory);
    }
    const patch: Uint8Array = await context.resourceManager.getRawFileContent('reader/yaramaika-semantic.zip');
    if (patch.byteLength !== WEB_REFLOW_PATCH_BYTES) {
      throw new Error('教材排版资源不完整，请更新应用。');
    }
    const patchPath: string = `${directory}/semantic.zip`;
    await ReflowWebBook.write(patchPath, patch.buffer.slice(patch.byteOffset, patch.byteOffset + patch.byteLength));
    await zlib.decompressFile(patchPath, directory);
    for (const chapter of WEB_REFLOW_CHAPTERS) {
      if (!await fileIo.access(`${directory}/${chapter}.html`)) {
        throw new Error('教材章节解包未完成，请返回后重试。');
      }
    }
    if (WEB_REFLOW_BASE_BYTES > 0) {
      await fileIo.unlink(archive);
    }
    await fileIo.unlink(patchPath);
    await ReflowWebBook.write(marker, WEB_REFLOW_CACHE);
    return directory;
  }

  private static async write(filename: string, value: string | ArrayBuffer): Promise<void> {
    const file: fileIo.File = await fileIo.open(filename,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      if (typeof value === 'string') {
        await fileIo.write(file.fd, value);
      } else {
        let offset: number = 0;
        while (offset < value.byteLength) {
          const written: number = await fileIo.write(file.fd, value.slice(offset));
          if (written <= 0) {
            throw new Error('教材资源写入失败');
          }
          offset += written;
        }
      }
    } finally {
      await fileIo.close(file);
    }
  }
}
