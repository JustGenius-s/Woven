export interface ResponseInputContent {
  type: string;
  text: string;
}

export interface ResponseInputMessage {
  role: string;
  content: ResponseInputContent[];
}

export interface ResponsesCreateRequest {
  model: string;
  instructions: string;
  input: ResponseInputMessage[];
  stream: boolean;
  store: boolean;
  previous_response_id?: string;
}

export interface ResponsesStreamEvent {
  type?: string;
  delta?: string;
  response?: ResponsesCompletedResponse;
  error?: ResponsesErrorDetail;
}

export interface ResponsesCompletedResponse {
  id?: string;
  status?: string;
}

export interface ResponsesErrorDetail {
  message?: string;
}

export interface ResponsesStreamCallbacks {
  onDelta: (delta: string) => void;
  onCompleted: (responseId: string) => void;
  onError: (message: string) => void;
}

export interface PracticeMessage {
  id: string;
  role: string;
  text: string;
}

