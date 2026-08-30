import {
  Dialogue,
  DialogueLine,
  KanaCell,
  VocabularyEntry
} from '../model/ContentModels';
import { AiInquiryContext } from '../model/DeepSeekModels';

export class AiInquiryFactory {
  static kana(cell: KanaCell, cue: string = ''): AiInquiryContext {
    const cueLine: string = cue.length > 0 ? `\n学习提示：${cue}` : '';
    return {
      id: `kana-${cell.key}-${Date.now()}`,
      kind: '假名',
      title: `${cell.hira}・${cell.kata}`,
      subtitle: cell.romaji,
      content: `平假名：${cell.hira}\n片假名：${cell.kata}\n罗马音：${cell.romaji}${cueLine}`,
      suggestions: ['怎么发音？', '给我几个常用词', '容易和哪个假名混淆？']
    };
  }

  static word(item: VocabularyEntry): AiInquiryContext {
    const example: string = item.example === undefined ? '' :
      `\n例句：${item.example.japanese}\n例句释义：${item.example.english}`;
    return {
      id: `word-${item.id}-${Date.now()}`,
      kind: '单词',
      title: item.word,
      subtitle: `${item.reading} · ${item.meanings.slice(0, 2).join('；')}`,
      content: `单词：${item.word}\n读音：${item.reading}\n释义：${item.meanings.join('；')}${example}`,
      suggestions: ['怎么记这个词？', '给我两个自然例句', '和近义词有什么区别？']
    };
  }

  static example(japanese: string, meaning: string, source: string): AiInquiryContext {
    return {
      id: `example-${Date.now()}`,
      kind: '例句',
      title: AiInquiryFactory.compact(japanese),
      subtitle: meaning,
      content: `来源：${source}\n日语例句：${japanese}\n释义：${meaning}`,
      suggestions: ['拆解这句话', '这里的语气自然吗？', '换一种自然说法']
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
      suggestions: ['这句在什么场合用？', '为什么这样说？', '给我一个接话示例']
    };
  }

  static grammar(text: string, source: string): AiInquiryContext {
    return {
      id: `grammar-${Date.now()}`,
      kind: '句子',
      title: AiInquiryFactory.compact(text),
      subtitle: source,
      content: `来源：${source}\n选中的日语内容：${text}`,
      suggestions: ['拆解语法和助词', '翻译并说明语气', '给我两个相似例句']
    };
  }

  private static compact(text: string): string {
    const normalized: string = text.replace(/\n/g, ' ').trim();
    return normalized.length > 42 ? `${normalized.slice(0, 42)}…` : normalized;
  }
}
