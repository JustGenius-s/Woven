import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import {
  SUPABASE_ANON_KEY,
  SUPABASE_GRAMMAR_BUCKET,
  SUPABASE_URL
} from '../common/SupabaseConfig';
import { GrammarAudioTrack, GrammarWork } from '../model/GrammarModels';

interface CloudTrack {
  id?: string;
  title?: string;
  key?: string;
  bytes?: number | string | null;
  duration_ms?: number | string | null;
}

interface CloudLessonRow {
  id: string;
  level: string;
  cefr?: string;
  lesson_no?: number | string | null;
  title: string;
  title_ja?: string;
  topic?: string;
  summary?: string;
  source_name?: string;
  source_url?: string;
  rights?: string;
  cover_key?: string | null;
  cover_bytes?: number | string | null;
  cover_ratio?: number | string | null;
  pdf_key?: string | null;
  pdf_bytes?: number | string | null;
  page_count?: number | string | null;
  workbook_key?: string | null;
  workbook_bytes?: number | string | null;
  answer_key?: string | null;
  answer_bytes?: number | string | null;
  audio_tracks?: CloudTrack[] | null;
  audio_bytes?: number | string | null;
  sort_order?: number | string | null;
}

const LIST_COLUMNS: string = 'id,level,cefr,lesson_no,title,title_ja,topic,summary,' +
  'source_name,source_url,rights,cover_key,cover_bytes,cover_ratio,' +
  'pdf_key,pdf_bytes,page_count,workbook_key,workbook_bytes,answer_key,answer_bytes,' +
  'audio_tracks,audio_bytes,sort_order';

export class GrammarCloudStore {
  private static memory: GrammarWork[] = [];
  private static inflight: Promise<GrammarWork[]> | undefined = undefined;

  static cached(context: common.Context): GrammarWork[] {
    if (GrammarCloudStore.memory.length > 0) {
      return GrammarCloudStore.memory;
    }
    return GrammarCloudStore.readDiskCache(context);
  }

  static async refresh(context: common.Context): Promise<GrammarWork[]> {
    if (GrammarCloudStore.inflight !== undefined) {
      return GrammarCloudStore.inflight;
    }
    GrammarCloudStore.inflight = GrammarCloudStore.fetchCatalog(context);
    try {
      return await GrammarCloudStore.inflight;
    } finally {
      GrammarCloudStore.inflight = undefined;
    }
  }

  static async downloadObject(storageKey: string): Promise<ArrayBuffer> {
    const url: string =
      `${SUPABASE_URL}/storage/v1/object/${SUPABASE_GRAMMAR_BUCKET}/${storageKey}`;
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
      return GrammarCloudStore.toArrayBuffer(response.result);
    } finally {
      request.destroy();
    }
  }

  private static async fetchCatalog(context: common.Context): Promise<GrammarWork[]> {
    const url: string = `${SUPABASE_URL}/rest/v1/grammar_lessons` +
      `?select=${LIST_COLUMNS}&published=eq.true&order=sort_order.asc`;
    const rows: CloudLessonRow[] = await GrammarCloudStore.getJson(url);
    const works: GrammarWork[] = [];
    for (let index: number = 0; index < rows.length; index++) {
      works.push(GrammarCloudStore.toWork(rows[index]));
    }
    GrammarCloudStore.memory = works;
    GrammarCloudStore.writeDiskCache(context, works);
    return works;
  }

  private static async getJson(url: string): Promise<CloudLessonRow[]> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
          'apikey': SUPABASE_ANON_KEY,
          'Accept': 'application/json',
          'Range': '0-199'
        },
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: 15000,
        readTimeout: 45000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`文法课表加载失败 ${response.responseCode}`);
      }
      return GrammarCloudStore.parseRows(response.result);
    } finally {
      request.destroy();
    }
  }

  private static parseRows(raw: Object): CloudLessonRow[] {
    if (typeof raw === 'string') {
      const text: string = raw as string;
      if (text.length === 0) {
        return [];
      }
      return JSON.parse(text) as CloudLessonRow[];
    }
    if (Array.isArray(raw)) {
      return raw as CloudLessonRow[];
    }
    throw new Error('文法课表格式无法识别');
  }

  private static toWork(row: CloudLessonRow): GrammarWork {
    const tracks: GrammarAudioTrack[] = [];
    const rawTracks: CloudTrack[] = row.audio_tracks ?? [];
    for (let index: number = 0; index < rawTracks.length; index++) {
      const track: CloudTrack = rawTracks[index];
      const key: string | undefined = GrammarCloudStore.present(track.key);
      if (key === undefined) {
        continue;
      }
      tracks.push({
        id: track.id ?? `track-${index}`,
        title: track.title ?? `${index + 1}`,
        key: key,
        bytes: GrammarCloudStore.optionalNumber(track.bytes) ?? 0,
        durationMs: GrammarCloudStore.optionalNumber(track.duration_ms) ?? 0
      });
    }
    return {
      id: row.id,
      level: row.level,
      cefr: row.cefr ?? '',
      lessonNo: GrammarCloudStore.optionalNumber(row.lesson_no) ?? 0,
      title: row.title,
      titleJa: row.title_ja ?? '',
      topic: row.topic ?? '',
      summary: row.summary ?? '',
      sourceName: row.source_name ?? '',
      sourceUrl: row.source_url ?? '',
      rights: row.rights ?? '',
      coverKey: GrammarCloudStore.present(row.cover_key),
      coverBytes: GrammarCloudStore.optionalNumber(row.cover_bytes),
      coverRatio: GrammarCloudStore.optionalNumber(row.cover_ratio),
      pdfKey: GrammarCloudStore.present(row.pdf_key) ?? '',
      pdfBytes: GrammarCloudStore.optionalNumber(row.pdf_bytes),
      pageCount: GrammarCloudStore.optionalNumber(row.page_count) ?? 0,
      workbookKey: GrammarCloudStore.present(row.workbook_key),
      workbookBytes: GrammarCloudStore.optionalNumber(row.workbook_bytes),
      answerKey: GrammarCloudStore.present(row.answer_key),
      answerBytes: GrammarCloudStore.optionalNumber(row.answer_bytes),
      audioTracks: tracks,
      audioBytes: GrammarCloudStore.optionalNumber(row.audio_bytes),
      sortOrder: GrammarCloudStore.optionalNumber(row.sort_order) ?? 0
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
    return `${context.filesDir}/grammar/catalog.json`;
  }

  private static readDiskCache(context: common.Context): GrammarWork[] {
    const path: string = GrammarCloudStore.cachePath(context);
    try {
      if (!fileIo.accessSync(path)) {
        return [];
      }
      const works: GrammarWork[] = JSON.parse(fileIo.readTextSync(path)) as GrammarWork[];
      GrammarCloudStore.memory = works;
      return works;
    } catch (error) {
      return [];
    }
  }

  private static writeDiskCache(context: common.Context, works: GrammarWork[]): void {
    const directory: string = `${context.filesDir}/grammar`;
    try {
      if (!fileIo.accessSync(directory)) {
        fileIo.mkdirSync(directory, true);
      }
    } catch (error) {
      try {
        if (!fileIo.statSync(directory).isDirectory()) {
          return;
        }
      } catch (_statError) {
        return;
      }
    }
    const path: string = GrammarCloudStore.cachePath(context);
    let exists: boolean = false;
    try {
      exists = fileIo.accessSync(path);
    } catch (_error) {
      exists = false;
    }
    const file: fileIo.File = exists ?
      fileIo.openSync(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC) :
      fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, JSON.stringify(works));
    } finally {
      fileIo.closeSync(file);
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
