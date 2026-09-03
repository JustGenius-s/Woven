import { readdir, readFile, stat } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const rawfileRoot = resolve(scriptDir, '../entry/src/main/resources/rawfile')
const manifest = JSON.parse(await readFile(resolve(rawfileRoot, 'manifest.json'), 'utf8'))
const grammarIndex = JSON.parse(await readFile(resolve(rawfileRoot, 'grammar/index.json'), 'utf8'))
const lessonFiles = (await readdir(resolve(rawfileRoot, 'grammar')))
  .filter((name) => name.endsWith('.json') && name !== 'index.json')

if (grammarIndex.length !== manifest.grammar.totalLessons || lessonFiles.length !== manifest.grammar.totalLessons) {
  throw new Error('Grammar manifest, index and lesson files disagree.')
}

let vocabularyCount = 0
let pitchCoverage = 0
const vocabularyIdsByLevel = new Map()
for (const level of ['n1', 'n2', 'n3', 'n4', 'n5']) {
  const entries = JSON.parse(await readFile(resolve(rawfileRoot, `vocabulary/${level}.json`), 'utf8'))
  vocabularyCount += entries.length
  vocabularyIdsByLevel.set(level.toUpperCase(), new Set(entries.map((entry) => entry.id)))
  for (const entry of entries) {
    if (!Array.isArray(entry.pitches)) {
      throw new Error(`Vocabulary ${entry.id} is missing pitches.`)
    }
    for (const pitch of entry.pitches) {
      if (!Number.isInteger(pitch.accent) || pitch.accent < 0 ||
        !Array.isArray(pitch.morae) || pitch.morae.length === 0 || !pitch.source) {
        throw new Error(`Vocabulary ${entry.id} has an invalid pitch entry.`)
      }
    }
    if (entry.pitches.length > 0) {
      pitchCoverage += 1
    }
  }
}
if (vocabularyCount !== manifest.vocabulary.total) {
  throw new Error(`Vocabulary count mismatch: ${vocabularyCount} != ${manifest.vocabulary.total}`)
}
if (pitchCoverage !== (manifest.vocabulary.pitchCoverage ?? pitchCoverage)) {
  throw new Error(`Pitch coverage mismatch: ${pitchCoverage} != ${manifest.vocabulary.pitchCoverage}`)
}
if (pitchCoverage < Math.floor(vocabularyCount * 0.9)) {
  throw new Error(`Pitch coverage too low: ${pitchCoverage}/${vocabularyCount}`)
}

const lexiconFiles = [
  ['日常', 'extra-daily.json'],
  ['一般', 'extra-general.json'],
  ['补遗', 'extra-supplement.json']
]
const extraIds = new Set()
let extraPitchCoverage = 0
let extraEntries = 0
const examIds = new Set([...vocabularyIdsByLevel.values()].flatMap((ids) => [...ids]))
for (const [level, filename] of lexiconFiles) {
  const entries = JSON.parse(await readFile(resolve(rawfileRoot, `vocabulary/${filename}`), 'utf8'))
  extraEntries += entries.length
  if (entries.length !== (manifest.vocabulary.levels?.[level] ?? entries.length)) {
    throw new Error(`Lexicon ${level} count mismatch: ${entries.length} != ${manifest.vocabulary.levels?.[level]}`)
  }
  for (const entry of entries) {
    if (entry.level !== level || !entry.id || !entry.word || !entry.reading) {
      throw new Error(`Lexicon extra entry ${entry.id || '<unknown>'} is incomplete.`)
    }
    if (!Array.isArray(entry.pitches)) {
      throw new Error(`Vocabulary ${entry.id} is missing pitches.`)
    }
    for (const pitch of entry.pitches) {
      if (!Number.isInteger(pitch.accent) || pitch.accent < 0 ||
        !Array.isArray(pitch.morae) || pitch.morae.length === 0 || !pitch.source) {
        throw new Error(`Vocabulary ${entry.id} has an invalid pitch entry.`)
      }
    }
    if (examIds.has(entry.id) || extraIds.has(entry.id)) {
      throw new Error(`Vocabulary id ${entry.id} is duplicated across levels.`)
    }
    extraIds.add(entry.id)
    if (entry.pitches.length > 0) {
      extraPitchCoverage += 1
    }
  }
}
if (extraEntries !== (manifest.vocabulary.extraTotal ?? extraEntries)) {
  throw new Error(`Extra vocabulary count mismatch: ${extraEntries} != ${manifest.vocabulary.extraTotal}`)
}
if (extraPitchCoverage !== (manifest.vocabulary.extraPitchCoverage ?? extraPitchCoverage)) {
  throw new Error(`Extra pitch coverage mismatch: ${extraPitchCoverage} != ${manifest.vocabulary.extraPitchCoverage}`)
}
if (extraEntries < 10000) {
  throw new Error(`Lexicon extras are too small: ${extraEntries}`)
}

const catalog = JSON.parse(await readFile(resolve(rawfileRoot, 'catalog.json'), 'utf8'))
if (!catalog.kanaGroups?.basic?.length || !catalog.dialogues?.length || !catalog.practiceScenarios?.length) {
  throw new Error('Bundled learning catalog is incomplete.')
}

const musicTracks = JSON.parse(await readFile(resolve(rawfileRoot, 'music.json'), 'utf8'))
if (musicTracks.length < 3 || musicTracks.some((track) => !track.id || !track.title ||
  !track.audioSource || !track.artworkName || track.durationMs <= 0 || track.lines?.length < 3)) {
  throw new Error('Bundled music learning content is incomplete.')
}
for (const track of musicTracks) {
  const audioFile = await stat(resolve(rawfileRoot, track.audioSource))
  if (!audioFile.isFile() || audioFile.size < 1000) {
    throw new Error(`Music source ${track.audioSource} is missing or incomplete.`)
  }
  let previousStart = -1
  for (const line of track.lines) {
    if (!Number.isInteger(line.startMs) || line.startMs <= previousStart || line.startMs >= track.durationMs) {
      throw new Error(`Music timeline ${track.id} is not strictly ordered.`)
    }
    previousStart = line.startMs
  }
}

const readingWorks = JSON.parse(await readFile(resolve(rawfileRoot, 'reading.json'), 'utf8'))
const readingIds = new Set(readingWorks.map((work) => work.id))
const isPdfBook = (work) => work.format === 'pdf'
if (readingWorks.length < 5 || readingIds.size !== readingWorks.length ||
  readingWorks.some((work) => !work.title || !work.author || !work.sourceUrl ||
    work.passages?.length < 3)) {
  throw new Error('Bundled open reading content is incomplete.')
}
for (const work of readingWorks) {
  if (isPdfBook(work)) {
    const storyLength = work.passages.reduce((total, passage) =>
      total + String(passage.text ?? '').replace(/\s/g, '').length, 0)
    if (!work.complete || storyLength < 20) {
      throw new Error(`PDF book ${work.id} is missing official story text.`)
    }
    if (!work.pdfFile) {
      throw new Error(`PDF book ${work.id} is missing pdfFile.`)
    }
    const pdfBook = await stat(resolve(rawfileRoot, work.pdfFile))
    if (!pdfBook.isFile() || pdfBook.size < 1000) {
      throw new Error(`PDF book ${work.pdfFile} is missing or incomplete.`)
    }
    for (const passage of work.passages) {
      if (passage.note) {
        throw new Error(`PDF book ${work.id} must not add study notes.`)
      }
      if (passage.lines || passage.image) {
        throw new Error(`PDF book ${work.id} still has reconstructed page data.`)
      }
    }
    if (work.audioFile) {
      const audioFile = await stat(resolve(rawfileRoot, work.audioFile))
      if (!audioFile.isFile() || audioFile.size < 1000) {
        throw new Error(`PDF book ${work.audioFile} is missing or incomplete.`)
      }
      const cues = work.audioCues ?? []
      const duration = Number(work.audioDurationMs ?? 0)
      if (cues.length < 8 || duration < 1000) {
        throw new Error(`PDF book ${work.id} is missing a narration timeline.`)
      }
      let previousStart = -1
      for (const cue of cues) {
        if (!Number.isInteger(cue.page) || cue.page < 0 || cue.page >= work.passages.length) {
          throw new Error(`PDF book ${work.id} has a cue on an invalid page.`)
        }
        if (!Number.isInteger(cue.startMs) || cue.startMs <= previousStart ||
          !Number.isInteger(cue.endMs) || cue.endMs <= cue.startMs || cue.endMs > duration) {
          throw new Error(`PDF book ${work.id} has an unordered narration timeline.`)
        }
        previousStart = cue.startMs
      }
    }
    continue
  }
  if (work.complete) {
    const fullTextLength = work.passages.reduce((total, passage) =>
      total + passage.text.replace(/\s/g, '').length, 0)
    if (fullTextLength < 2500 || work.passages.some((passage) => !passage.title)) {
      throw new Error(`Complete reading ${work.id} is missing full text or page titles.`)
    }
  }
  const readerBook = await stat(resolve(rawfileRoot, `reader/${work.id}.epub`))
  if (!readerBook.isFile() || readerBook.size < 1000) {
    throw new Error(`Reader book ${work.id}.epub is missing or incomplete.`)
  }
}
if (!readingWorks.some((work) => work.complete)) {
  throw new Error('At least one complete reading work must be bundled.')
}

const openSources = JSON.parse(await readFile(resolve(rawfileRoot, 'open-sources.json'), 'utf8'))
const aozoraWorks = readingWorks.filter((work) => !isPdfBook(work))
const tadokuWorks = readingWorks.filter((work) => isPdfBook(work))
const aozora = openSources.sources?.find((source) => source.id === 'aozora-bunko')
const aozoraBundledIds = new Set(aozora?.bundledIds ?? [])
if (!aozora || aozora.integrationStatus !== 'bundled' || aozoraBundledIds.size !== aozoraWorks.length ||
  aozoraWorks.some((work) => !aozoraBundledIds.has(work.id))) {
  throw new Error('Open-source manifest does not cover every bundled Aozora reading.')
}
const tadoku = openSources.sources?.find((source) => source.id === 'tadoku-free-books')
const tadokuBundledIds = new Set(tadoku?.bundledIds ?? [])
if (tadokuWorks.length > 0 && (!tadoku || tadoku.integrationStatus !== 'bundled' ||
  tadokuBundledIds.size !== tadokuWorks.length ||
  tadokuWorks.some((work) => !tadokuBundledIds.has(work.id)))) {
  throw new Error('Open-source manifest does not cover every bundled Tadoku reading.')
}

const journeys = JSON.parse(await readFile(resolve(rawfileRoot, 'journeys.json'), 'utf8'))
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

console.log(`Content OK: ${lessonFiles.length} lessons, ${vocabularyCount} exam words (${pitchCoverage} with pitch), ${extraEntries} lexicon extras (${extraPitchCoverage} with pitch), ${musicTracks.length} music tracks, ${readingWorks.length} open readings, ${catalog.dialogues.length} journey dialogues, ${catalog.practiceScenarios.length} scenarios.`)
