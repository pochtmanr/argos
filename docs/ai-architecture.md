# AI Architecture

Generated path: `/Users/roman/Developer/iosbrowser/docs/ai-architecture.md`

AI is provider-agnostic through `@browser/ai-core`. Providers include OpenAI, Anthropic, and local model endpoints. Browser actions are never raw model side effects; they are permissioned action requests containing workspace, profile, tab, origin, permissions, instruction, and approval requirement.

Low-risk page summarization can be auto-approved by policy. Navigation, form filling, form submission, downloads, clipboard writes, and vault reads require explicit policy grants and may require user approval.
