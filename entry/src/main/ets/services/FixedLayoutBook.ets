import { common } from '@kit.AbilityKit';
import { zlib } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { NativeReaderTrial } from './NativeReaderTrial';

export const FIXED_BOOK_PAGE_COUNT: number = 72;

export interface FixedLayoutReaderParams {
  pageIndex?: number;
}

// This is the bundled, trusted pdf2htmlEX book, not a general EPUB importer.
export class FixedLayoutBook {
  static async prepare(context: common.Context): Promise<string> {
    const directory: string = `${context.filesDir}/reader-trial/fixed-web-v2`;
    const marker: string = `${directory}/ready`;
    if (!await fileIo.access(marker)) {
      await fileIo.mkdir(directory, true);
      const epub: string = await NativeReaderTrial.materialize(context,
        NativeReaderTrial.edition('yaramaika-fixed'));
      const archive: string = `${directory}/book.zip`;
      await fileIo.copyFile(epub, archive);
      await zlib.decompressFile(archive, directory);
      const scriptBytes: Uint8Array = await context.resourceManager.getRawFileContent('reader/fixed-layout.js');
      await FixedLayoutBook.write(`${directory}/OEBPS/fixed-layout.js`,
        scriptBytes.buffer.slice(scriptBytes.byteOffset, scriptBytes.byteOffset + scriptBytes.byteLength));
      for (let page: number = 0; page < FIXED_BOOK_PAGE_COUNT; page++) {
        const name: string = FixedLayoutBook.pageName(page);
        const source: string = await fileIo.readText(`${directory}/OEBPS/${name}.xhtml`);
        // Use text/html deliberately: a file path returned for a pre-paginated
        // spine must never be passed to Reader Kit as if it were book text.
        // These bundled-book fonts contain romanized readings. In the kana
        // tables, .ffb shares a line with .ff1 Japanese spans; their explicit
        // visibility:visible must still win over inherited hidden visibility.
        // Do not hide descendants wholesale or change any text advances.
        const html: string = source.replace(/<\?xml[^>]*\?>/, '')
          .replace(/<meta name="viewport"[^>]*\/>/,
            '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5"/>')
          .replace('</head>', '<style>html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;}' +
            '#page-container{overflow:hidden;bottom:auto;right:auto;transform-origin:0 0;}' +
            '.ff5,.ffa,.ffb{visibility:hidden!important;}' +
            '</style><script src="fixed-layout.js" defer></script></head>');
        await FixedLayoutBook.write(`${directory}/OEBPS/${name}.html`, html);
      }
      await fileIo.unlink(archive);
      // Mark complete only after every page and all shared resources are ready.
      await FixedLayoutBook.write(marker, '2');
    }
    return `${directory}/OEBPS`;
  }

  static pageName(page: number): string {
    return `mybook${`${page + 1}`.padStart(4, '0')}`;
  }

  private static async write(path: string, content: string | ArrayBuffer): Promise<void> {
    const file: fileIo.File = await fileIo.open(path,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      if (typeof content === 'string') {
        await fileIo.write(file.fd, content);
      } else {
        let offset: number = 0;
        while (offset < content.byteLength) {
          const written: number = await fileIo.write(file.fd, content.slice(offset));
          if (written <= 0) { throw new Error('教材写入失败'); }
          offset += written;
        }
      }
    } finally {
      await fileIo.close(file);
    }
  }
}
