import assert from 'node:assert/strict'
import test from 'node:test'
import {
  makeResponseIds,
  parseResponsesRequest,
  responseObject,
  sse,
  toModelMessages,
} from '../src/responses-protocol.js'

test('parses the OpenAI Responses subset used by the app', () => {
  const request = parseResponsesRequest({
    model: 'gpt-5.6-luna',
    instructions: 'Stay in role.',
    input: [{ role: 'user', content: [{ type: 'input_text', text: 'こんにちは' }] }],
    stream: true,
    store: true,
    previous_response_id: 'resp_previous',
  }, '')
  assert.equal(request.stream, true)
  assert.equal(request.previous_response_id, 'resp_previous')
  assert.deepEqual(toModelMessages(request.input), [{ role: 'user', content: 'こんにちは' }])
})

test('serializes Responses event data without changing event names', () => {
  const event = sse('response.output_text.delta', {
    type: 'response.output_text.delta',
    delta: '日本語',
  })
  assert.match(event, /^event: response\.output_text\.delta\n/)
  assert.match(event, /"delta":"日本語"/)
})

test('creates a completed response object with output_text content', () => {
  const request = parseResponsesRequest({ input: 'hello', stream: false }, 'gpt-5.6-luna')
  const response = responseObject(request, makeResponseIds(), 'こんにちは', 'completed', {
    inputTokens: 2,
    inputTokenDetails: {
      noCacheTokens: 2,
      cacheReadTokens: 0,
      cacheWriteTokens: 0,
    },
    outputTokens: 3,
    outputTokenDetails: {
      textTokens: 3,
      reasoningTokens: 0,
    },
    totalTokens: 5,
  }, undefined)
  assert.equal(response.object, 'response')
  assert.equal(response.output[0]?.content[0]?.type, 'output_text')
  assert.equal(response.output[0]?.content[0]?.text, 'こんにちは')
  assert.equal(response.usage?.total_tokens, 5)
})
