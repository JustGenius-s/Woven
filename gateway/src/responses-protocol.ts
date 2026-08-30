import { randomUUID } from 'node:crypto'
import type { LanguageModelUsage, ModelMessage } from 'ai'

export interface ResponsesInputContent {
  type: string
  text: string
}

export interface ResponsesInputMessage {
  role: string
  content: ResponsesInputContent[]
}

export interface ResponsesRequest {
  model: string
  instructions: string
  input: string | ResponsesInputMessage[]
  stream: boolean
  store: boolean
  previous_response_id?: string
  max_output_tokens: number
}

export interface OpenAIProviderMetadata {
  responseId?: string | null
}

interface OutputTextContent {
  type: 'output_text'
  annotations: never[]
  logprobs: never[]
  text: string
}

interface OutputMessage {
  id: string
  type: 'message'
  status: 'in_progress' | 'completed'
  role: 'assistant'
  content: OutputTextContent[]
}

export interface ResponseObject {
  id: string
  object: 'response'
  created_at: number
  status: 'in_progress' | 'completed' | 'failed'
  error: null | { message: string; type: string; code: string | null }
  instructions: string
  model: string
  output: OutputMessage[]
  parallel_tool_calls: boolean
  previous_response_id: string | null
  store: boolean
  temperature: null
  text: { format: { type: 'text' }; verbosity: 'low' }
  tool_choice: 'auto'
  tools: never[]
  top_p: null
  usage: null | {
    input_tokens: number
    input_tokens_details: { cached_tokens: number }
    output_tokens: number
    output_tokens_details: { reasoning_tokens: number }
    total_tokens: number
  }
}

export interface ResponseIds {
  responseId: string
  messageId: string
}

export function parseResponsesRequest(value: unknown, defaultModel: string): ResponsesRequest {
  if (!isRecord(value)) {
    throw new Error('request body must be a JSON object')
  }
  const model = readOptionalString(value.model) || defaultModel
  if (model.length === 0) {
    throw new Error('model is required')
  }
  const instructions = readOptionalString(value.instructions)
  const input = parseInput(value.input)
  const stream = value.stream === undefined ? false : value.stream === true
  const store = value.store === undefined ? true : value.store === true
  const previousResponseId = readOptionalString(value.previous_response_id)
  const requestedLimit = typeof value.max_output_tokens === 'number' ? Math.trunc(value.max_output_tokens) : 1200
  const maxOutputTokens = Math.max(64, Math.min(requestedLimit, 4000))
  const request: ResponsesRequest = {
    model,
    instructions,
    input,
    stream,
    store,
    max_output_tokens: maxOutputTokens,
  }
  if (previousResponseId.length > 0) {
    request.previous_response_id = previousResponseId
  }
  return request
}

export function toModelMessages(input: string | ResponsesInputMessage[]): ModelMessage[] {
  if (typeof input === 'string') {
    return [{ role: 'user', content: input }]
  }
  const messages: ModelMessage[] = []
  for (const item of input) {
    const text = item.content.map((part) => part.text).join('\n')
    if (item.role === 'assistant') {
      messages.push({ role: 'assistant', content: text })
    } else if (item.role === 'system' || item.role === 'developer') {
      messages.push({ role: 'system', content: text })
    } else {
      messages.push({ role: 'user', content: text })
    }
  }
  return messages
}

export function makeResponseIds(): ResponseIds {
  const suffix = randomUUID().replaceAll('-', '')
  return {
    responseId: `resp_${suffix}`,
    messageId: `msg_${suffix}`,
  }
}

export function responseObject(
  request: ResponsesRequest,
  ids: ResponseIds,
  text: string,
  status: 'in_progress' | 'completed' | 'failed',
  usage: LanguageModelUsage | undefined,
  errorMessage: string | undefined,
): ResponseObject {
  const content: OutputTextContent[] = [{ type: 'output_text', annotations: [], logprobs: [], text }]
  return {
    id: ids.responseId,
    object: 'response',
    created_at: Math.floor(Date.now() / 1000),
    status,
    error: errorMessage === undefined ? null : {
      message: errorMessage,
      type: 'server_error',
      code: null,
    },
    instructions: request.instructions,
    model: request.model,
    output: [{
      id: ids.messageId,
      type: 'message',
      status: status === 'in_progress' ? 'in_progress' : 'completed',
      role: 'assistant',
      content,
    }],
    parallel_tool_calls: true,
    previous_response_id: request.previous_response_id ?? null,
    store: request.store,
    temperature: null,
    text: { format: { type: 'text' }, verbosity: 'low' },
    tool_choice: 'auto',
    tools: [],
    top_p: null,
    usage: usage === undefined ? null : {
      input_tokens: usage.inputTokens ?? 0,
      input_tokens_details: { cached_tokens: usage.inputTokenDetails.cacheReadTokens ?? 0 },
      output_tokens: usage.outputTokens ?? 0,
      output_tokens_details: { reasoning_tokens: usage.outputTokenDetails.reasoningTokens ?? 0 },
      total_tokens: usage.totalTokens ?? 0,
    },
  }
}

export function sse(event: string, data: object): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
}

export function errorEnvelope(message: string, type = 'invalid_request_error'): object {
  return {
    error: {
      message,
      type,
      param: null,
      code: null,
    },
  }
}

function parseInput(value: unknown): string | ResponsesInputMessage[] {
  if (typeof value === 'string') {
    if (value.trim().length === 0) throw new Error('input must not be empty')
    return value
  }
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error('input must be a string or a non-empty message array')
  }
  const messages: ResponsesInputMessage[] = []
  for (const item of value) {
    if (!isRecord(item)) throw new Error('input message must be an object')
    const role = readOptionalString(item.role) || 'user'
    const rawContent = item.content
    if (typeof rawContent === 'string') {
      messages.push({ role, content: [{ type: role === 'assistant' ? 'output_text' : 'input_text', text: rawContent }] })
      continue
    }
    if (!Array.isArray(rawContent) || rawContent.length === 0) {
      throw new Error('input message content must not be empty')
    }
    const content: ResponsesInputContent[] = []
    for (const part of rawContent) {
      if (!isRecord(part) || typeof part.text !== 'string') {
        throw new Error('only text input content is supported')
      }
      content.push({ type: readOptionalString(part.type) || 'input_text', text: part.text })
    }
    messages.push({ role, content })
  }
  return messages
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function readOptionalString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : ''
}
