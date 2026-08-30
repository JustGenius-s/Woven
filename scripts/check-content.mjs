import { readdir, readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const contentRoot = resolve(scriptDir, '../entry/src/main/resources/rawfile/content')
const manifest = JSON.parse(await readFile(resolve(contentRoot, 'manifest.json'), 'utf8'))
const grammarIndex = JSON.parse(await readFile(resolve(contentRoot, 'grammar/index.json'), 'utf8'))
const lessonFiles = (await readdir(resolve(contentRoot, 'grammar/lessons'))).filter((name) => name.endsWith('.json'))

if (grammarIndex.length !== manifest.grammar.totalLessons || lessonFiles.length !== manifest.grammar.totalLessons) {
  throw new Error('Grammar manifest, index and lesson files disagree.')
}

let vocabularyCount = 0
const vocabularyIdsByLevel = new Map()
for (const level of ['n1', 'n2', 'n3', 'n4', 'n5']) {
  const entries = JSON.parse(await readFile(resolve(contentRoot, `vocabulary/${level}.json`), 'utf8'))
  vocabularyCount += entries.length
  vocabularyIdsByLevel.set(level.toUpperCase(), new Set(entries.map((entry) => entry.id)))
}
if (vocabularyCount !== manifest.vocabulary.total) {
  throw new Error(`Vocabulary count mismatch: ${vocabularyCount} != ${manifest.vocabulary.total}`)
}

const catalog = JSON.parse(await readFile(resolve(contentRoot, 'catalog.json'), 'utf8'))
if (!catalog.kanaGroups?.basic?.length || !catalog.dialogues?.length || !catalog.practiceScenarios?.length) {
  throw new Error('Bundled learning catalog is incomplete.')
}

const journeys = JSON.parse(await readFile(resolve(contentRoot, 'journeys.json'), 'utf8'))
const grammarIds = new Set(grammarIndex.map((entry) => entry.id))
const dialogueIds = new Set(catalog.dialogues.map((dialogue) => dialogue.id))
const kanaIds = new Set()
for (const rows of Object.values(catalog.kanaGroups)) {
  for (const row of rows) {
    for (const cell of row.cells) kanaIds.add(cell.key)
  }
}
const journeyIds = new Set()
for (const journey of journeys) {
  if (!journey.id || !journey.title || journey.kana?.length < 3 || journey.wordIds?.length < 3) {
    throw new Error(`Journey ${journey.id || '<unknown>'} is incomplete.`)
  }
  if (journeyIds.has(journey.id)) throw new Error(`Journey id ${journey.id} is duplicated.`)
  journeyIds.add(journey.id)
  if (!grammarIds.has(journey.grammarLessonId) || !dialogueIds.has(journey.dialogueId)) {
    throw new Error(`Journey ${journey.id} points to missing grammar or dialogue content.`)
  }
  if (journey.kana.some((focus) => !kanaIds.has(focus.key))) {
    throw new Error(`Journey ${journey.id} points to a missing kana entry.`)
  }
  const vocabularyLevelIds = vocabularyIdsByLevel.get(journey.vocabularyLevel)
  if (!vocabularyLevelIds || journey.wordIds.some((id) => !vocabularyLevelIds.has(id))) {
    throw new Error(`Journey ${journey.id} points to a word outside ${journey.vocabularyLevel}.`)
  }
  if (journey.challenge.answerIndex < 0 || journey.challenge.answerIndex >= journey.challenge.options.length) {
    throw new Error(`Journey ${journey.id} has an invalid challenge answer.`)
  }
}

console.log(`Content OK: ${lessonFiles.length} lessons, ${vocabularyCount} words, ${catalog.dialogues.length} dialogues, ${journeys.length} journeys.`)
