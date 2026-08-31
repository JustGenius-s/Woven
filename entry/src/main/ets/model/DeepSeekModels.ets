export interface DeepSeekMessage {
  role: string;
  content: string;
}

export interface DeepSeekThinking {
  type: string;
}

export interface DeepSeekChatRequest {
  model: string;
  messages: DeepSeekMessage[];
  thinking: DeepSeekThinking;
  stream: boolean;
  max_tokens: number;
  temperature: number;
}

export interface DeepSeekResponseMessage {
  content?: string;
}

export interface DeepSeekChoice {
  message?: DeepSeekResponseMessage;
  finish_reason?: string;
}

export interface DeepSeekErrorDetail {
  message?: string;
}

export interface DeepSeekChatResponse {
  choices?: DeepSeekChoice[];
  error?: DeepSeekErrorDetail;
}

export interface AiInquiryContext {
  id: string;
  kind: string;
  title: string;
  subtitle: string;
  content: string;
  suggestions: string[];
  conversationKey?: string;
  initialPrompt?: string;
  courseId?: string;
  targetLocale?: string;
  supportLocale?: string;
}

export interface PracticeMessage {
  id: string;
  role: string;
  text: string;
  revision: number;
  languageTag?: string;
  createdAt?: number;
}
