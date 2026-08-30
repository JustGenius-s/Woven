import assert from 'node:assert/strict'
import test from 'node:test'
import { extractNhkArticle, parseRss } from '../src/news.js'

test('parses supported NHK RSS items and ignores external links', () => {
  const xml = `<rss><channel>
    <item><title><![CDATA[ニュースです]]></title><description>要約です</description><link>https://news.web.nhk/articles/abc.html</link><pubDate>Sat, 29 Aug 2026 10:00:00 GMT</pubDate></item>
    <item><title>外部</title><link>https://example.com/story</link></item>
  </channel></rss>`
  const items = parseRss(xml)
  assert.equal(items.length, 1)
  assert.equal(items[0]?.title, 'ニュースです')
})

test('extracts complete article paragraphs', () => {
  const html = `<html><head><meta property="og:title" content="見出し | NHK"><meta property="og:description" content="短い要約"></head>
    <body><h1>見出し</h1><p>これは十分な長さを持つニュース本文の第一段落です。内容を正しく表示します。</p>
    <p>これはニュース本文の第二段落です。追加の詳しい情報を提供しています。</p><div>関連ニュース</div></body></html>`
  const article = extractNhkArticle(html, {
    url: 'https://news.web.nhk/articles/abc.html',
    title: '見出し',
    summary: '短い要約',
  })
  assert.match(article.body, /第一段落/)
  assert.match(article.body, /第二段落/)
  assert.equal(article.complete, true)
})

