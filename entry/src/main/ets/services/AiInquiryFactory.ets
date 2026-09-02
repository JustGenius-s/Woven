import {
  Dialogue,
  DialogueLine,
  KanaCell,
  VocabularyEntry
} from '../model/ContentModels';
import { AiInquiryContext } from '../model/DeepSeekModels';
import { PitchNotation } from './PitchNotation';
import {
  DEFAULT_COURSE_ID,
  DEFAULT_SUPPORT_LOCALE,
  DEFAULT_TARGET_LOCALE
} from '../model/SyncModels';

export class AiInquiryFactory {
  static selection(text: string, source: string, surroundingContext: string = ''): AiInquiryContext {
    const selection: string = text.trim();
    const contextLine: string = surroundingContext.trim().length === 0 ? '' :
      `\n相关上下文：\n${surroundingContext.trim()}`;
    return {
      id: `selection-${Date.now()}`,
      kind: '选中内容',
      title: AiInquiryFactory.compact(selection),
      subtitle: source,
      content: `来源：${source}\n用户选中的内容：${selection}${contextLine}`,
      suggestions: ['解释这段内容', '分析读音和语法', '给我两个相似例句'],
      courseId: DEFAULT_COURSE_ID,
      targetLocale: DEFAULT_TARGET_LOCALE,
      supportLocale: DEFAULT_SUPPORT_LOCALE
    };
  }

  static kana(cell: KanaCell, cue: string = ''): AiInquiryContext {
    const cueLine: string = cue.length > 0 ? `\n学习提示：${cue}` : '';
    return {
      id: `kana-${cell.key}-${Date.now()}`,
      kind: '假名',
      title: `${cell.hira}・${cell.kata}`,
      subtitle: cell.romaji,
      content: `平假名：${cell.hira}\n片假名：${cell.kata}\n罗马音：${cell.romaji}${cueLine}`,
      suggestions: ['怎么发音？', '给我几个常用词', '容易和哪个假名混淆？'],
      courseId: DEFAULT_COURSE_ID,
      targetLocale: DEFAULT_TARGET_LOCALE,
      supportLocale: DEFAULT_SUPPORT_LOCALE
    };
  }

  static word(item: VocabularyEntry, learningContext: string = '', initialPrompt: string = ''): AiInquiryContext {
    const example: string = item.example === undefined ? '' :
      `\n例句：${item.example.japanese}\n例句释义：${item.example.english}`;
    const pitch: string = PitchNotation.summary(item);
    const pitchLine: string = pitch.length === 0 ? '' : `\n音调：${pitch}`;
    const progress: string = learningContext.trim().length === 0 ? '' :
      `\n用户的学习进度：\n${learningContext.trim()}`;
    return {
      id: `word-${item.id}-${Date.now()}`,
      kind: '单词对话',
      title: item.word,
      subtitle: `${item.reading} · ${item.meanings.slice(0, 2).join('；')}`,
      content: `单词：${item.word}\n读音：${item.reading}${pitchLine}\n释义：${item.meanings.join('；')}${example}${progress}`,
      suggestions: ['用我学过的内容再造一句', '说明常见搭配', '和相近词比较'],
      conversationKey: `word-${item.id}`,
      initialPrompt: initialPrompt.trim(),
      courseId: DEFAULT_COURSE_ID,
      targetLocale: DEFAULT_TARGET_LOCALE,
      supportLocale: DEFAULT_SUPPORT_LOCALE
    };
  }

  static example(japanese: string, meaning: string, source: string): AiInquiryContext {
    return {
      id: `example-${Date.now()}`,
      kind: '例句',
      title: AiInquiryFactory.compact(japanese),
      subtitle: meaning,
      content: `来源：${source}\n日语例句：${japanese}\n释义：${meaning}`,
      suggestions: ['拆解这句话', '这里的语气自然吗？', '换一种自然说法'],
      courseId: DEFAULT_COURSE_ID,
      targetLocale: DEFAULT_TARGET_LOCALE,
      supportLocale: DEFAULT_SUPPORT_LOCALE
    };
  }

  static dialogue(dialogue: Dialogue, line: DialogueLine): AiInquiryContext {
    return {
      id: `dialogue-${dialogue.id}-${Date.now()}`,
      kind: '对话',
      title: AiInquiryFactory.compact(line.text),
      subtitle: `${line.speaker} · ${line.meaning}`,
      content: `场景：${dialogue.setting}\n对话主题：${dialogue.title}\n说话人：${line.speaker}\n` +
        `原句：${line.text}\n读音：${line.reading}\n释义：${line.meaning}`,
      suggestions: ['这句在什么场合用？', '为什么这样说？', '给我一个接话示例'],
      courseId: DEFAULT_COURSE_ID,
      targetLocale: DEFAULT_TARGET_LOCALE,
      supportLocale: DEFAULT_SUPPORT_LOCALE
    };
  }

  static grammar(text: string, source: string): AiInquiryContext {
    return {
      id: `grammar-${Date.now()}`,
      kind: '句子',
      title: AiInquiryFactory.compact(text),
      subtitle: source,
      content: `来源：${source}\n选中的日语内容：${text}`,
      suggestions: ['拆解语法和助词', '翻译并说明语气', '给我两个相似例句'],
      courseId: DEFAULT_COURSE_ID,
      targetLocale: DEFAULT_TARGET_LOCALE,
      supportLocale: DEFAULT_SUPPORT_LOCALE
    };
  }

  private static compact(text: string): string {
    const normalized: string = text.replace(/\n/g, ' ').trim();
    return normalized.length > 42 ? `${normalized.slice(0, 42)}…` : normalized;
  }
}
