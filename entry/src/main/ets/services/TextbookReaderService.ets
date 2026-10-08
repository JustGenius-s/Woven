import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { READERKIT_ID, READERKIT_BYTES, READERKIT_CACHE, READERKIT_TITLES,
  READERKIT_CLASSROOM_INDEX } from './ReaderKitContent';

import { IRODORI_STARTER_EDITIONS } from './IrodoriStarterContent';
import { IRODORI_ELEMENTARY_EDITIONS } from './IrodoriElementaryContent';
import { IRODORI_PREINTERMEDIATE_EDITIONS } from './IrodoriPreIntermediateContent';
import { IRODORI_SAMPLE_ID, IRODORI_SAMPLE_BYTES, IRODORI_SAMPLE_CACHE,
  IRODORI_SAMPLE_TITLES } from './IrodoriSampleContent';

export interface NativeReaderEdition {
  id: string;
  label: string;
  title: string;
  titles: string[];
  cache: string;
  fileBytes: number;
  classroomIndex: number;
}

export const NATIVE_READER_EDITION: NativeReaderEdition = {
  id: READERKIT_ID, label: '新装二版', fileBytes: READERKIT_BYTES,
  title: 'やらまいか日本語', titles: READERKIT_TITLES, cache: READERKIT_CACHE,
  classroomIndex: READERKIT_CLASSROOM_INDEX
};

const IRODORI_SAMPLE_EDITION: NativeReaderEdition = {
  id: IRODORI_SAMPLE_ID, label: '第 1 课 · 完整重排版（18 页）', title: 'いろどり 入门',
  titles: IRODORI_SAMPLE_TITLES, cache: IRODORI_SAMPLE_CACHE,
  fileBytes: IRODORI_SAMPLE_BYTES, classroomIndex: -1
};

// Keep this module free of Reader Kit imports. The routed reader page is loaded
// only after the capability check, because unsupported systems lack kitview.hsp.
export class TextbookReaderService {
  static chapterTitle(edition: NativeReaderEdition, index: number): string {
    return edition.titles[index] ?? edition.label;
  }

  static progressId(edition: NativeReaderEdition): string {
    return `${edition.id}-${edition.cache}`;
  }

  static edition(id?: string): NativeReaderEdition {
    if (id === IRODORI_SAMPLE_ID) { return IRODORI_SAMPLE_EDITION; }
    const starter = IRODORI_STARTER_EDITIONS.find(book => book.id === id);
    if (starter !== undefined) {
      const lessonNo: number = Number.parseInt(starter.lessonId.slice(-2));
      return {
        id: starter.id, title: 'いろどり 入门',
        label: `${lessonNo === 0 ? '教室用语' : `第 ${lessonNo} 课`} · 完整重排版（${starter.titles.length} 页）`,
        titles: starter.titles, cache: starter.cache, fileBytes: starter.fileBytes, classroomIndex: -1
      };
    }
    const elementary = IRODORI_ELEMENTARY_EDITIONS.find(book => book.id === id);
    if (elementary !== undefined) {
      const lessonNo: number = Number.parseInt(elementary.lessonId.slice(-2));
      return {
        id: elementary.id, title: `いろどり ${elementary.level}`,
        label: `第 ${lessonNo} 课 · 重排版（${elementary.titles.length} 页）`,
        titles: elementary.titles, cache: elementary.cache,
        fileBytes: elementary.fileBytes, classroomIndex: -1
      };
    }
    const preintermediate = IRODORI_PREINTERMEDIATE_EDITIONS.find(book => book.id === id);
    if (preintermediate !== undefined) {
      const lessonNo: number = Number.parseInt(preintermediate.lessonId.slice(-2));
      return {
        id: preintermediate.id, title: `いろどり ${preintermediate.level}`,
        label: `第 ${lessonNo} 课 · 重排版（${preintermediate.titles.length} 页）`,
        titles: preintermediate.titles, cache: preintermediate.cache,
        fileBytes: preintermediate.fileBytes, classroomIndex: -1
      };
    }
    return NATIVE_READER_EDITION;
  }

  static editionIdForLesson(lessonId: string): string {
    if (lessonId === 'irodori-a1-l01') { return IRODORI_SAMPLE_ID; }
    return IRODORI_STARTER_EDITIONS.find(book => book.lessonId === lessonId)?.id ??
      IRODORI_ELEMENTARY_EDITIONS.find(book => book.lessonId === lessonId)?.id ??
      IRODORI_PREINTERMEDIATE_EDITIONS.find(book => book.lessonId === lessonId)?.id ?? '';
  }

  static unavailableReason(): string {
    const model: string = `${deviceInfo.productModel} ${deviceInfo.brand}`.toLowerCase();
    if (model.includes('emulator') || model.includes('simulator') || model.includes('avd')) {
      return '此教材暂不支持模拟器，请在鸿蒙手机或平板上阅读。';
    }
    if (!canIUse('SystemCapability.Reader.ReaderService.BookParser') ||
      !canIUse('SystemCapability.Reader.ReaderService.ReaderCore')) {
      return '当前设备暂不支持此教材的阅读服务，请在支持的鸿蒙手机或平板上打开。';
    }
    return '';
  }

  static async materialize(context: common.Context, edition: NativeReaderEdition): Promise<string> {
    // Keep the existing sandbox directory and progress keys when moving the
    // book into Grammar. A versioned directory per EPUB is required by BookParser.
    const directory: string = `${context.filesDir}/reader-trial/${edition.cache}/${edition.id}`;
    const path: string = `${directory}/book.epub`;
    try {
      if ((await fileIo.stat(path)).size === edition.fileBytes) {
        return path;
      }
    } catch (_error) {
      // The bundled book has not been copied into this application's sandbox yet.
    }
    if (!await fileIo.access(directory)) {
      await fileIo.mkdir(directory, true);
    }
    const bytes: Uint8Array = await context.resourceManager.getRawFileContent(`reader/${edition.id}.epub`);
    if (bytes.byteLength !== edition.fileBytes) {
      throw new Error('教材文件不完整，请重新安装应用');
    }
    const buffer: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    const temporary: string = `${path}.tmp`;
    const file: fileIo.File = await fileIo.open(temporary,
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      let offset: number = 0;
      while (offset < buffer.byteLength) {
        const count: number = await fileIo.write(file.fd, buffer.slice(offset));
        if (count <= 0) {
          throw new Error('教材写入失败');
        }
        offset += count;
      }
    } finally {
      await fileIo.close(file);
    }
    await fileIo.rename(temporary, path);
    return path;
  }
}
