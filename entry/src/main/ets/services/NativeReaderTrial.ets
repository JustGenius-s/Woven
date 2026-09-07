import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';

export interface NativeReaderEdition {
  id: string;
  label: string;
  fileBytes: number;
  classroomIndex: number;
  reflow: boolean;
}

export interface NativeReaderParams {
  editionId: string;
}

export const NATIVE_READER_EDITIONS: NativeReaderEdition[] = [
  { id: 'yaramaika-reflow', label: '可重排版', fileBytes: 11615186, classroomIndex: 2, reflow: true },
  { id: 'yaramaika-fixed', label: '原版布局', fileBytes: 12080087, classroomIndex: 5, reflow: false }
];

// Keep this module free of Reader Kit imports. The routed reader page is loaded
// only after the capability check, because unsupported systems lack kitview.hsp.
export class NativeReaderTrial {
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
    const directory: string = `${context.filesDir}/reader-trial/v1/${edition.id}`;
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
