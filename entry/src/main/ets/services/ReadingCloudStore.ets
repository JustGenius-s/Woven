import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import {
  SUPABASE_ANON_KEY,
  SUPABASE_READING_BUCKET,
  SUPABASE_URL
} from '../common/SupabaseConfig';
import {
  ReadingAudioCue,
  ReadingPassage,
  ReadingWork
} from '../model/ContentModels';

interface CloudPage {
  title?: string;
  text?: string;
}

interface CloudBookRow {
  id: string;
  title: string;
  title_reading?: string;
  author: string;
  level: string;
  genre: string;
  summary?: string;
  source_name?: string;
  source_url?: string;
  rights?: string;
  cover_ratio?: number | string | null;
  audio_duration_ms?: number | null;
  cover_key?: string | null;
  pdf_key?: string | null;
  audio_key?: string | null;
  pdf_bytes?: number | null;
  audio_bytes?: number | null;
  cover_bytes?: number | null;
  page_count?: number | null;
  pages?: CloudPage[] | null;
  cues?: ReadingAudioCue[] | null;
  sort_order?: number | null;
}

const LIST_COLUMNS: string = 'id,title,title_reading,author,level,genre,summary,' +
  'source_name,source_url,rights,page_count,cover_ratio,audio_duration_ms,' +
  'cover_key,pdf_key,audio_key,pdf_bytes,audio_bytes,cover_bytes,sort_order';

export class ReadingCloudStore {
  private static memory: ReadingWork[] = [];
  private static inflight: Promise<ReadingWork[]> | undefined = undefined;

  static cached(context: common.Context): ReadingWork[] {
    if (ReadingCloudStore.memory.length > 0) {
      return ReadingCloudStore.memory;
    }
    return ReadingCloudStore.readDiskCache(context);
  }

  static async cachedAsync(context: common.Context): Promise<ReadingWork[]> {
    if (ReadingCloudStore.memory.length > 0) {
      return ReadingCloudStore.memory;
    }
    return await ReadingCloudStore.readDiskCacheAsync(context);
  }

  static async refresh(context: common.Context): Promise<ReadingWork[]> {
    if (ReadingCloudStore.inflight !== undefined) {
      return ReadingCloudStore.inflight;
    }
    ReadingCloudStore.inflight = ReadingCloudStore.fetchCatalog(context);
    try {
      return await ReadingCloudStore.inflight;
    } finally {
      ReadingCloudStore.inflight = undefined;
    }
  }

  static async hydrate(work: ReadingWork): Promise<ReadingWork> {
    const url: string = `${SUPABASE_URL}/rest/v1/reading_books` +
      `?id=eq.${encodeURIComponent(work.id)}&select=pages,cues,audio_duration_ms`;
    const rows: CloudBookRow[] = await ReadingCloudStore.getJson(url);
    if (rows.length === 0) {
      return work;
    }
    const row: CloudBookRow = rows[0];
    const pages: CloudPage[] = row.pages ?? [];
    if (pages.length > 0) {
      const passages: ReadingPassage[] = [];
      for (let index: number = 0; index < pages.length; index++) {
        passages.push({
          title: pages[index].title ?? `${index + 1}`,
          text: pages[index].text ?? '',
          note: ''
        });
      }
      work.passages = passages;
    }
    work.audioCues = row.cues ?? [];
    const duration: number | undefined =
      ReadingCloudStore.optionalNumber(row.audio_duration_ms);
    if (duration !== undefined) {
      work.audioDurationMs = duration;
    }
    return work;
  }

  static async downloadObject(storageKey: string): Promise<ArrayBuffer> {
    const url: string =
      `${SUPABASE_URL}/storage/v1/object/${SUPABASE_READING_BUCKET}/${storageKey}`;
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
          'apikey': SUPABASE_ANON_KEY
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: 15000,
        readTimeout: 180000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`下载失败 ${response.responseCode}`);
      }
      return ReadingCloudStore.toArrayBuffer(response.result);
    } finally {
      request.destroy();
    }
  }

  private static async fetchCatalog(context: common.Context): Promise<ReadingWork[]> {
    const url: string = `${SUPABASE_URL}/rest/v1/reading_books` +
      `?select=${LIST_COLUMNS}&published=eq.true&order=sort_order.asc`;
    const rows: CloudBookRow[] = await ReadingCloudStore.getJson(url);
    const works: ReadingWork[] = [];
    for (let index: number = 0; index < rows.length; index++) {
      works.push(ReadingCloudStore.toWork(rows[index]));
    }
    ReadingCloudStore.memory = works;
    await ReadingCloudStore.writeDiskCacheAsync(context, works);
    return works;
  }

  private static async getJson(url: string): Promise<CloudBookRow[]> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
          'apikey': SUPABASE_ANON_KEY,
          'Accept': 'application/json',
          'Range': '0-999'
        },
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: 15000,
        readTimeout: 45000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`书目加载失败 ${response.responseCode}`);
      }
      return ReadingCloudStore.parseRows(response.result);
    } finally {
      request.destroy();
    }
  }

  private static parseRows(raw: Object): CloudBookRow[] {
    if (typeof raw === 'string') {
      const text: string = raw as string;
      if (text.length === 0) {
        return [];
      }
      return JSON.parse(text) as CloudBookRow[];
    }
    if (Array.isArray(raw)) {
      return raw as CloudBookRow[];
    }
    throw new Error('书目格式无法识别');
  }

  private static toWork(row: CloudBookRow): ReadingWork {
    const pageCount: number = ReadingCloudStore.optionalNumber(row.page_count) ?? 0;
    const passages: ReadingPassage[] = [];
    for (let index: number = 0; index < pageCount; index++) {
      passages.push({
        title: `${index + 1}`,
        text: '',
        note: ''
      });
    }
    return {
      id: row.id,
      title: row.title,
      titleReading: row.title_reading ?? '',
      author: row.author,
      level: row.level,
      genre: row.genre,
      category: row.level,
      summary: row.summary ?? '',
      sourceName: row.source_name ?? '',
      sourceUrl: row.source_url ?? '',
      rights: row.rights ?? '',
      complete: true,
      format: 'pdf',
      coverRatio: ReadingCloudStore.optionalNumber(row.cover_ratio),
      audioDurationMs: ReadingCloudStore.optionalNumber(row.audio_duration_ms),
      audioCues: [],
      pdfKey: ReadingCloudStore.present(row.pdf_key),
      audioKey: ReadingCloudStore.present(row.audio_key),
      coverKey: ReadingCloudStore.present(row.cover_key),
      pdfBytes: ReadingCloudStore.optionalNumber(row.pdf_bytes),
      audioBytes: ReadingCloudStore.optionalNumber(row.audio_bytes),
      coverBytes: ReadingCloudStore.optionalNumber(row.cover_bytes),
      passages: passages
    };
  }

  private static present(value?: string | null): string | undefined {
    if (value === undefined || value === null || value.length === 0) {
      return undefined;
    }
    return value;
  }

  private static optionalNumber(value?: number | string | null): number | undefined {
    if (value === undefined || value === null || `${value}`.length === 0) {
      return undefined;
    }
    const parsed: number = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  private static cachePath(context: common.Context): string {
    return `${context.filesDir}/reader/catalog.json`;
  }

  private static readDiskCache(context: common.Context): ReadingWork[] {
    const path: string = ReadingCloudStore.cachePath(context);
    try {
      if (!fileIo.accessSync(path)) {
        return [];
      }
      const works: ReadingWork[] = JSON.parse(fileIo.readTextSync(path)) as ReadingWork[];
      ReadingCloudStore.memory = works;
      return works;
    } catch (error) {
      return [];
    }
  }

  private static async readDiskCacheAsync(context: common.Context): Promise<ReadingWork[]> {
    const path: string = ReadingCloudStore.cachePath(context);
    try {
      if (!await fileIo.access(path)) {
        return [];
      }
      const works: ReadingWork[] = JSON.parse(await fileIo.readText(path)) as ReadingWork[];
      if (ReadingCloudStore.memory.length > 0) {
        return ReadingCloudStore.memory;
      }
      ReadingCloudStore.memory = works;
      return works;
    } catch (error) {
      return [];
    }
  }

  private static async writeDiskCacheAsync(context: common.Context, works: ReadingWork[]): Promise<void> {
    const directory: string = `${context.filesDir}/reader`;
    try {
      if (!await fileIo.access(directory)) {
        await fileIo.mkdir(directory, true);
      }
    } catch (error) {
      try {
        if (!(await fileIo.stat(directory)).isDirectory()) {
          return;
        }
      } catch (_statError) {
        return;
      }
    }
    const path: string = ReadingCloudStore.cachePath(context);
    let exists: boolean = false;
    try {
      exists = await fileIo.access(path);
    } catch (_error) {
      exists = false;
    }
    const file: fileIo.File = exists ?
      await fileIo.open(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC) :
      await fileIo.open(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      await fileIo.write(file.fd, JSON.stringify(works));
    } finally {
      await fileIo.close(file);
    }
  }

  private static toArrayBuffer(raw: Object): ArrayBuffer {
    if (raw instanceof ArrayBuffer) {
      return raw as ArrayBuffer;
    }
    if (typeof raw === 'string') {
      throw new Error('下载内容不是文件');
    }
    const bytes: Uint8Array = raw as Uint8Array;
    if (bytes.buffer !== undefined && bytes.byteLength !== undefined) {
      return bytes.buffer.slice(bytes.byteOffset,
        bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
    }
    throw new Error('下载内容不是文件');
  }
}
