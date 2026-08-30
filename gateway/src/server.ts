import { createServer, type IncomingMessage, type ServerResponse } from 'node:http'
import { timingSafeEqual } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import { createOpenAI } from '@ai-sdk/openai'
import { generateText, streamText, type LanguageModelUsage } from 'ai'
import { loadNews, loadNewsArticle } from './news.js'
import {
  errorEnvelope,
  makeResponseIds,
  type OpenAIProviderMetadata,
  parseResponsesRequest,
  responseObject,
  type ResponseIds,
  type ResponsesRequest,
  sse,
  toModelMessages,
} from './responses-protocol.js'

const MAX_BODY_BYTES = 128 * 1024
const RATE_WINDOW_MS = 60_000
const RATE_LIMIT = 60
const requestBuckets = new Map<string, { startedAt: number; count: number }>()

const host = process.env.HOST?.trim() || '127.0.0.1'
const port = parsePort(process.env.PORT)
const defaultModel = process.env.OPENAI_MODEL?.trim() || 'gpt-5.6-luna'
const appToken = process.env.KOTOBA_APP_TOKEN?.trim() || ''
const apiKey = process.env.OPENAI_API_KEY?.trim() || ''
const baseURL = process.env.OPENAI_BASE_URL?.trim()

const openai = createOpenAI({
  apiKey,
  ...(baseURL === undefined || baseURL.length === 0 ? {} : { baseURL }),
})

const server = createServer(async (request, response) => {
  setCommonHeaders(response)
  if (request.method === 'OPTIONS') {
    response.writeHead(204)
    response.end()
    return
  }
  if (!authorized(request)) {
    sendJson(response, 401, errorEnvelope('invalid application token', 'authentication_error'))
    return
  }
  if (!withinRateLimit(request)) {
    sendJson(response, 429, errorEnvelope('rate limit exceeded', 'rate_limit_error'))
    return
  }
  const url = new URL(request.url ?? '/', 'http://gateway.local')
  try {
    if (request.method === 'GET' && url.pathname === '/health') {
      sendJson(response, 200, { ok: true, service: 'kotoba-ai-gateway', responses: true })
      return
    }
    if (request.method === 'GET' && url.pathname === '/api/news') {
      sendJson(response, 200, { ok: true, value: await loadNews() })
      return
    }
    if (request.method === 'GET' && url.pathname === '/api/news/article') {
      sendJson(response, 200, { ok: true, value: await loadNewsArticle(url.searchParams.get('url') ?? '') })
      return
    }
    if (request.method === 'POST' && url.pathname === '/v1/responses') {
      if (apiKey.length === 0) {
        sendJson(response, 503, errorEnvelope('OPENAI_API_KEY is not configured', 'server_error'))
        return
      }
      const body = parseResponsesRequest(await readJsonBody(request), defaultModel)
      if (body.stream) await streamResponse(body, response)
      else await completeResponse(body, response)
      return
    }
    sendJson(response, 404, errorEnvelope('route not found'))
  } catch (error) {
    const message = describeError(error)
    if (!response.headersSent) sendJson(response, 400, errorEnvelope(message))
    else response.end()
  }
})

async function streamResponse(body: ResponsesRequest, response: ServerResponse): Promise<void> {
  const localIds = makeResponseIds()
  response.writeHead(200, {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache, no-transform',
    connection: 'keep-alive',
    'x-accel-buffering': 'no',
  })
  let sequence = 0
  let outputText = ''
  response.write(sse('response.created', {
    type: 'response.created',
    sequence_number: sequence++,
    response: responseObject(body, localIds, '', 'in_progress', undefined, undefined),
  }))
  response.write(sse('response.output_item.added', {
    type: 'response.output_item.added',
    sequence_number: sequence++,
    output_index: 0,
    item: {
      id: localIds.messageId,
      type: 'message',
      status: 'in_progress',
      role: 'assistant',
      content: [],
    },
  }))
  response.write(sse('response.content_part.added', {
    type: 'response.content_part.added',
    sequence_number: sequence++,
    item_id: localIds.messageId,
    output_index: 0,
    content_index: 0,
    part: { type: 'output_text', annotations: [], logprobs: [], text: '' },
  }))

  try {
    const result = streamText({
      model: openai.responses(body.model),
      messages: toModelMessages(body.input),
      maxOutputTokens: body.max_output_tokens,
      providerOptions: {
        openai: {
          store: body.store,
          instructions: body.instructions,
          ...(body.previous_response_id === undefined ? {} : { previousResponseId: body.previous_response_id }),
        },
      },
    })
    for await (const delta of result.textStream) {
      outputText += delta
      response.write(sse('response.output_text.delta', {
        type: 'response.output_text.delta',
        sequence_number: sequence++,
        item_id: localIds.messageId,
        output_index: 0,
        content_index: 0,
        delta,
        logprobs: [],
      }))
    }
    const [metadata, usage] = await Promise.all([result.providerMetadata, result.usage])
    const provider = metadata?.openai as OpenAIProviderMetadata | undefined
    const ids: ResponseIds = {
      responseId: provider?.responseId || localIds.responseId,
      messageId: localIds.messageId,
    }
    response.write(sse('response.output_text.done', {
      type: 'response.output_text.done',
      sequence_number: sequence++,
      item_id: ids.messageId,
      output_index: 0,
      content_index: 0,
      text: outputText,
      logprobs: [],
    }))
    response.write(sse('response.content_part.done', {
      type: 'response.content_part.done',
      sequence_number: sequence++,
      item_id: ids.messageId,
      output_index: 0,
      content_index: 0,
      part: { type: 'output_text', annotations: [], logprobs: [], text: outputText },
    }))
    response.write(sse('response.output_item.done', {
      type: 'response.output_item.done',
      sequence_number: sequence++,
      output_index: 0,
      item: responseObject(body, ids, outputText, 'completed', usage, undefined).output[0],
    }))
    response.write(sse('response.completed', {
      type: 'response.completed',
      sequence_number: sequence++,
      response: responseObject(body, ids, outputText, 'completed', usage, undefined),
    }))
    response.end()
  } catch (error) {
    const message = describeError(error)
    response.write(sse('response.failed', {
      type: 'response.failed',
      sequence_number: sequence++,
      response: responseObject(body, localIds, outputText, 'failed', undefined, message),
      error: { message, type: 'server_error', code: null },
    }))
    response.end()
  }
}

async function completeResponse(body: ResponsesRequest, response: ServerResponse): Promise<void> {
  const result = await generateText({
    model: openai.responses(body.model),
    messages: toModelMessages(body.input),
    maxOutputTokens: body.max_output_tokens,
    providerOptions: {
      openai: {
        store: body.store,
        instructions: body.instructions,
        ...(body.previous_response_id === undefined ? {} : { previousResponseId: body.previous_response_id }),
      },
    },
  })
  const provider = result.providerMetadata?.openai as OpenAIProviderMetadata | undefined
  const localIds = makeResponseIds()
  const ids: ResponseIds = {
    responseId: provider?.responseId || localIds.responseId,
    messageId: localIds.messageId,
  }
  sendJson(response, 200, responseObject(body, ids, result.text, 'completed', result.usage, undefined))
}

async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = []
  let total = 0
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
    total += buffer.length
    if (total > MAX_BODY_BYTES) throw new Error('request body exceeds 128 KiB')
    chunks.push(buffer)
  }
  const text = Buffer.concat(chunks).toString('utf8')
  if (text.length === 0) throw new Error('request body is empty')
  return JSON.parse(text) as unknown
}

function sendJson(response: ServerResponse, status: number, value: object): void {
  const body = JSON.stringify(value)
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  })
  response.end(body)
}

function setCommonHeaders(response: ServerResponse): void {
  response.setHeader('access-control-allow-origin', '*')
  response.setHeader('access-control-allow-methods', 'GET,POST,OPTIONS')
  response.setHeader('access-control-allow-headers', 'authorization,content-type')
  response.setHeader('x-content-type-options', 'nosniff')
}

function authorized(request: IncomingMessage): boolean {
  if (appToken.length === 0) return true
  const supplied = request.headers.authorization?.replace(/^Bearer\s+/i, '') ?? ''
  const expectedBuffer = Buffer.from(appToken)
  const suppliedBuffer = Buffer.from(supplied)
  return suppliedBuffer.length === expectedBuffer.length && timingSafeEqual(suppliedBuffer, expectedBuffer)
}

function withinRateLimit(request: IncomingMessage): boolean {
  const key = request.socket.remoteAddress ?? 'unknown'
  const now = Date.now()
  const bucket = requestBuckets.get(key)
  if (bucket === undefined || now - bucket.startedAt >= RATE_WINDOW_MS) {
    requestBuckets.set(key, { startedAt: now, count: 1 })
    return true
  }
  bucket.count += 1
  return bucket.count <= RATE_LIMIT
}

function describeError(error: unknown): string {
  return error instanceof Error && error.message.length > 0 ? error.message : 'unexpected server error'
}

function parsePort(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isInteger(parsed) && parsed > 0 && parsed <= 65535 ? parsed : 8787
}

export function startGateway(): void {
  server.listen(port, host, () => {
    console.log(`Kotoba AI gateway listening on http://${host}:${port}`)
    if (appToken.length === 0) console.warn('KOTOBA_APP_TOKEN is not set; do not expose this gateway publicly.')
  })
}

const entryPath = process.argv[1]
if (entryPath !== undefined && fileURLToPath(import.meta.url) === entryPath) startGateway()

