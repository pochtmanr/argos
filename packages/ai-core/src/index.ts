// /Users/roman/Developer/iosbrowser/packages/ai-core/src/index.ts
import type { AiActionRequest } from "@browser/api-contracts";

export type AiProviderName = "openai" | "anthropic" | "local";

export type AiMessage = {
  role: "system" | "user" | "assistant" | "tool";
  content: string;
};

export type AiCompletionRequest = {
  provider: AiProviderName;
  model: string;
  messages: AiMessage[];
  temperature?: number;
};

export type AiCompletionResponse = {
  provider: AiProviderName;
  model: string;
  content: string;
  inputTokens?: number;
  outputTokens?: number;
};

export interface AiProvider {
  readonly name: AiProviderName;
  complete(request: AiCompletionRequest): Promise<AiCompletionResponse>;
}

export class AiGateway {
  private readonly providers = new Map<AiProviderName, AiProvider>();

  register(provider: AiProvider): void {
    this.providers.set(provider.name, provider);
  }

  async complete(request: AiCompletionRequest): Promise<AiCompletionResponse> {
    const provider = this.providers.get(request.provider);
    if (!provider) throw new Error(`AI provider not registered: ${request.provider}`);
    return provider.complete(request);
  }
}

export function buildPageSummaryPrompt(title: string, url: string, text: string): AiMessage[] {
  return [
    { role: "system", content: "Summarize browser pages precisely. Preserve security-sensitive uncertainty." },
    { role: "user", content: `Title: ${title}\nURL: ${url}\n\nPage text:\n${text.slice(0, 60000)}` }
  ];
}

export function describeActionForAudit(action: AiActionRequest): string {
  return `${action.permissions.join(",")} on ${action.origin} for tab ${action.tabId}`;
}
