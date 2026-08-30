const NEWS_SOURCE_URL = 'https://news.web.nhk/n-data/conf/na/rss/cat0.xml'
const NEWS_HOME_URL = 'https://news.web.nhk/'
const FETCH_TIMEOUT_MS = 8_000
const CACHE_MS = 10 * 60 * 1000
const MAX_FEED_CHARS = 1_000_000
const MAX_ARTICLE_CHARS = 2_000_000

export interface NewsItem {
  id: string
  title: string
  summary: string
  url: string
  publishedAt?: string
}

export interface NewsSnapshot {
  source: string
  sourceUrl: string
  fetchedAt: string
  stale: boolean
  items: NewsItem[]
}

export interface NewsArticle {
  url: string
  title: string
  body: string
  imageUrl?: string
  publishedAt?: string
  complete: boolean
}

let cachedFeed: { at: number; value: NewsSnapshot } | undefined
const articleCache = new Map<string, { at: number; value: NewsArticle }>()

export async function loadNews(): Promise<NewsSnapshot> {
  const now = Date.now()
  if (cachedFeed !== undefined && now - cachedFeed.at < CACHE_MS) return cachedFeed.value
  try {
    const xml = await fetchText(NEWS_SOURCE_URL, 'application/rss+xml, application/xml;q=0.9', MAX_FEED_CHARS)
    const items = parseRss(xml).slice(0, 16)
    if (items.length === 0) throw new Error('新闻源没有返回可读取条目')
    const value: NewsSnapshot = {
      source: 'NHK ONE ニュース',
      sourceUrl: NEWS_HOME_URL,
      fetchedAt: new Date(now).toISOString(),
      stale: false,
      items,
    }
    cachedFeed = { at: now, value }
    return value
  } catch (error) {
    if (cachedFeed !== undefined) return { ...cachedFeed.value, stale: true }
    throw error
  }
}

export async function loadNewsArticle(url: string): Promise<NewsArticle> {
  const safeUrl = safeNhkArticleUrl(url)
  if (safeUrl === undefined) throw new Error('不支持的新闻地址')
  const now = Date.now()
  const cached = articleCache.get(safeUrl)
  if (cached !== undefined && now - cached.at < CACHE_MS) return cached.value
  const fallback = cachedFeed?.value.items.find((item) => item.url === safeUrl)
  const html = await fetchText(safeUrl, 'text/html,application/xhtml+xml;q=0.9', MAX_ARTICLE_CHARS)
  const article = extractNhkArticle(html, {
    url: safeUrl,
    title: fallback?.title ?? '',
    summary: fallback?.summary ?? '',
    ...(fallback?.publishedAt === undefined ? {} : { publishedAt: fallback.publishedAt }),
  })
  if (article.body.length === 0) throw new Error('新闻页没有可读取的正文')
  articleCache.set(safeUrl, { at: now, value: article })
  return article
}

export function parseRss(xml: string): NewsItem[] {
  const blocks = xml.match(/<item\b[\s\S]*?<\/item>/gi) ?? []
  const seen = new Set<string>()
  const items: NewsItem[] = []
  for (const block of blocks) {
    const title = cleanText(readTag(block, 'title'))
    const summary = cleanText(readTag(block, 'description'))
    const url = safeNhkArticleUrl(cleanText(readTag(block, 'link')))
    if (title.length === 0 || url === undefined || seen.has(url)) continue
    seen.add(url)
    const date = new Date(cleanText(readTag(block, 'pubDate')))
    items.push({
      id: stableId(url),
      title,
      summary,
      url,
      ...(Number.isFinite(date.getTime()) ? { publishedAt: date.toISOString() } : {}),
    })
  }
  return items
}

export function extractNhkArticle(
  html: string,
  fallback: { url: string; title: string; summary: string; publishedAt?: string },
): NewsArticle {
  const withoutNoise = html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript\b[^>]*>[\s\S]*?<\/noscript>/gi, ' ')
  const metaTitle = readMeta(html, 'og:title') || readDocumentTitle(html)
  const title = fallback.title || metaTitle.replace(/\s*[|｜].*$/u, '').trim()
  const description = cleanText(readMeta(html, 'description') || readMeta(html, 'og:description'))
    .replace(/^【NHK】\s*/u, '')
  const titlePosition = title.length === 0 ? -1 : withoutNoise.indexOf(title)
  const articleStart = titlePosition >= 0 ? titlePosition : 0
  const boundaries = ['注目ワード', '関連ニュース', 'ニュース一覧', '<footer']
    .map((marker) => withoutNoise.indexOf(marker, articleStart + Math.max(1, title.length)))
    .filter((position) => position > articleStart)
  const articleEnd = boundaries.length > 0 ? Math.min(...boundaries) : withoutNoise.length
  const blocks = Array.from(withoutNoise.slice(articleStart, articleEnd)
    .matchAll(/<(p|h2|h3)\b[^>]*>([\s\S]*?)<\/\1>/gi))
    .map((match) => cleanText(match[2] ?? ''))
    .filter((text) => isArticleBlock(text, title))
  const uniqueBlocks = [...new Set(blocks)]
  const fallbackBody = fallback.summary || description
  const extractedBody = uniqueBlocks.join('\n\n')
  const body = extractedBody.length >= fallbackBody.length ? extractedBody : fallbackBody
  const imageUrl = safeNhkAssetUrl(readMeta(html, 'og:image'))
  return {
    url: fallback.url,
    title,
    body,
    ...(imageUrl === undefined ? {} : { imageUrl }),
    ...(fallback.publishedAt === undefined ? {} : { publishedAt: fallback.publishedAt }),
    complete: uniqueBlocks.length >= 2 && extractedBody.length > fallbackBody.length + 40,
  }
}

async function fetchText(url: string, accept: string, maxChars: number): Promise<string> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)
  try {
    const response = await fetch(url, {
      headers: { accept, 'user-agent': 'Kotoba-Harmony/1.0 learning reader' },
      signal: controller.signal,
    })
    if (!response.ok) throw new Error(`新闻源返回 HTTP ${response.status}`)
    const text = await response.text()
    if (text.length === 0) throw new Error('新闻源返回了空内容')
    if (text.length > maxChars) throw new Error('新闻内容超过安全上限')
    return text
  } finally {
    clearTimeout(timer)
  }
}

function safeNhkArticleUrl(value: string): string | undefined {
  try {
    const url = new URL(value)
    if (url.protocol !== 'https:' || url.hostname !== 'news.web.nhk') return undefined
    return url.toString()
  } catch {
    return undefined
  }
}

function safeNhkAssetUrl(value: string): string | undefined {
  try {
    const url = new URL(value)
    if (url.protocol !== 'https:' || !url.hostname.endsWith('.nhk')) return undefined
    return url.toString()
  } catch {
    return undefined
  }
}

function readTag(block: string, tag: string): string {
  const match = block.match(new RegExp(`<${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${tag}>`, 'i'))
  return (match?.[1] ?? '').replace(/^\s*<!\[CDATA\[([\s\S]*)\]\]>\s*$/i, '$1')
}

function readMeta(html: string, key: string): string {
  const tags = html.match(/<meta\b[^>]*>/gi) ?? []
  for (const tag of tags) {
    const attributes = new Map<string, string>()
    for (const match of tag.matchAll(/([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g)) {
      const name = match[1]
      if (name !== undefined) attributes.set(name.toLowerCase(), match[2] ?? match[3] ?? match[4] ?? '')
    }
    if ((attributes.get('property') ?? attributes.get('name'))?.toLowerCase() === key.toLowerCase()) {
      return decodeEntities(attributes.get('content') ?? '').trim()
    }
  }
  return ''
}

function readDocumentTitle(html: string): string {
  return cleanText(html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? '')
}

function isArticleBlock(text: string, title: string): boolean {
  if (text.length < 12 || text === title) return false
  return !/^(シェア|注目ワード|関連ニュース|ニュース一覧|動画|SNS)/u.test(text)
}

function cleanText(value: string): string {
  return decodeEntities(value.replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim()
}

function decodeEntities(value: string): string {
  const named: Record<string, string> = { amp: '&', apos: "'", gt: '>', lt: '<', nbsp: ' ', quot: '"' }
  return value.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, entity: string) => {
    if (entity.slice(0, 2).toLowerCase() === '#x') {
      const point = Number.parseInt(entity.slice(2), 16)
      return validCodePoint(point) ? String.fromCodePoint(point) : whole
    }
    if (entity.startsWith('#')) {
      const point = Number.parseInt(entity.slice(1), 10)
      return validCodePoint(point) ? String.fromCodePoint(point) : whole
    }
    return named[entity.toLowerCase()] ?? whole
  })
}

function validCodePoint(value: number): boolean {
  return Number.isInteger(value) && value >= 0 && value <= 0x10ffff && (value < 0xd800 || value > 0xdfff)
}

function stableId(value: string): string {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return `news-${(hash >>> 0).toString(36)}`
}
