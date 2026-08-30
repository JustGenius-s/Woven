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
for (const level of ['n1', 'n2', 'n3', 'n4', 'n5']) {
  const entries = JSON.parse(await readFile(resolve(contentRoot, `vocabulary/${level}.json`), 'utf8'))
  vocabularyCount += entries.length
}
if (vocabularyCount !== manifest.vocabulary.total) {
  throw new Error(`Vocabulary count mismatch: ${vocabularyCount} != ${manifest.vocabulary.total}`)
}

const catalog = JSON.parse(await readFile(resolve(contentRoot, 'catalog.json'), 'utf8'))
if (!catalog.kanaGroups?.basic?.length || !catalog.dialogues?.length || !catalog.practiceScenarios?.length) {
  throw new Error('Bundled learning catalog is incomplete.')
}

console.log(`Content OK: ${lessonFiles.length} lessons, ${vocabularyCount} words, ${catalog.dialogues.length} dialogues.`)

