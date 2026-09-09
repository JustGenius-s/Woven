import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { REFLOW_BYTES, REFLOW_CHAPTER_TITLES, REFLOW_CLASSROOM_INDEX, REFLOW_REVISION,
  REFLOW_SOURCE_PAGES } from './NativeReaderContent';
import { SAMPLE_BYTES, SAMPLE_CHAPTER_TITLES, SAMPLE_CLASSROOM_INDEX, SAMPLE_REVISION,
  SAMPLE_SOURCE_PAGES } from './NativeReaderSampleContent';
import { READERKIT_TRIAL_ID, READERKIT_TRIAL_BYTES, READERKIT_TRIAL_REVISION, READERKIT_TRIAL_CACHE,
  READERKIT_TRIAL_TITLES, READERKIT_TRIAL_SOURCE_PAGES } from './ReaderKitTrialContent';
import { READERKIT_ID, READERKIT_BYTES, READERKIT_REVISION, READERKIT_CACHE, READERKIT_TITLES,
  READERKIT_SOURCE_PAGES, READERKIT_CLASSROOM_INDEX } from './ReaderKitContent';

export interface NativeReaderEdition {
  id: string;
  label: string;
  fileBytes: number;
  classroomIndex: number;
  reflow: boolean;
  revision: number;
}

export interface NativeReaderParams {
  editionId: string;
}

export const NATIVE_READER_EDITIONS: NativeReaderEdition[] = [
  { id: READERKIT_ID, label: '可重排版 · Reader Kit', fileBytes: READERKIT_BYTES,
    classroomIndex: READERKIT_CLASSROOM_INDEX, reflow: true, revision: READERKIT_REVISION },
  { id: 'yaramaika-reflow', label: '可重排版', fileBytes: REFLOW_BYTES,
    classroomIndex: REFLOW_CLASSROOM_INDEX, reflow: true, revision: REFLOW_REVISION },
  { id: 'yaramaika-reflow-sample', label: '重排样本', fileBytes: SAMPLE_BYTES,
    classroomIndex: SAMPLE_CLASSROOM_INDEX, reflow: true, revision: SAMPLE_REVISION },
  { id: READERKIT_TRIAL_ID, label: 'Reader Kit · 11、17 页', fileBytes: READERKIT_TRIAL_BYTES,
    classroomIndex: 0, reflow: true, revision: READERKIT_TRIAL_REVISION },
  { id: 'yaramaika-fixed', label: '原版布局', fileBytes: 12080087, classroomIndex: 5, reflow: false, revision: 1 }
];

// Keep this module free of Reader Kit imports. The routed reader page is loaded
// only after the capability check, because unsupported systems lack kitview.hsp.
export class NativeReaderTrial {
  static chapterTitle(edition: NativeReaderEdition, index: number): string {
    if (edition.id === READERKIT_ID) {
      return READERKIT_TITLES[index] ?? edition.label;
    }
    if (edition.id === READERKIT_TRIAL_ID) {
      return READERKIT_TRIAL_TITLES[index] ?? edition.label;
    }
    const titles: string[] = edition.id === 'yaramaika-reflow-sample' ? SAMPLE_CHAPTER_TITLES : REFLOW_CHAPTER_TITLES;
    return edition.reflow ? (titles[index] ?? edition.label) : edition.label;
  }

  static sourcePageIndex(edition: NativeReaderEdition, index: number): number {
    if (edition.id === READERKIT_ID) {
      return READERKIT_SOURCE_PAGES[index] ?? 0;
    }
    if (edition.id === READERKIT_TRIAL_ID) {
      return READERKIT_TRIAL_SOURCE_PAGES[index] ?? READERKIT_TRIAL_SOURCE_PAGES[0];
    }
    // Reflow resources are real chapters, so this points to the chapter's first
    // original page, not an estimate of the visible screen's original page.
    const pages: number[] = edition.id === 'yaramaika-reflow-sample' ? SAMPLE_SOURCE_PAGES : REFLOW_SOURCE_PAGES;
    return edition.reflow ? (pages[index] ?? 0) : index;
  }

  static progressId(edition: NativeReaderEdition): string {
    if (edition.id === READERKIT_ID) {
      return `${edition.id}-${READERKIT_CACHE}`;
    }
    if (edition.id === READERKIT_TRIAL_ID) {
      return `${edition.id}-${READERKIT_TRIAL_CACHE}`;
    }
    // Rebuilt spines and DOM positions cannot reuse the Calibre conversion's
    // saved offsets. Preserve the fixed edition's existing original-page index.
    return edition.reflow ? `${edition.id}-v${edition.revision}` : edition.id;
  }

  static edition(id: string): NativeReaderEdition {
    return NATIVE_READER_EDITIONS.find((edition: NativeReaderEdition) => edition.id === id) ??
      NATIVE_READER_EDITIONS[0];
  }

  static unavailableReason(): string {
    const model: string = `${deviceInfo.productModel} ${deviceInfo.brand}`.toLowerCase();
    if (model.includes('emulator') || model.includes('simulator') || model.includes('avd')) {
      return 'Reader Kit 暂不支持模拟器，请在鸿蒙真机上体验。';
    }
    if (!canIUse('SystemCapability.Reader.ReaderService.BookParser') ||
      !canIUse('SystemCapability.Reader.ReaderService.ReaderCore')) {
      return '当前设备未提供 Reader Kit 阅读服务，请使用支持该服务的鸿蒙真机。';
    }
    return '';
  }

  static async materialize(context: common.Context, edition: NativeReaderEdition): Promise<string> {
    // A distinct, versioned directory per EPUB is required by BookParser.
    const version: string = edition.id === READERKIT_ID ? READERKIT_CACHE :
      (edition.id === READERKIT_TRIAL_ID ? READERKIT_TRIAL_CACHE : `v${edition.revision}`);
    const directory: string = `${context.filesDir}/reader-trial/${version}/${edition.id}`;
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
      throw new Error('教材文件不完整，请重新安装试用包');
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
