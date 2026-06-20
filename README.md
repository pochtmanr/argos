# AI-Native Multi-Profile Browser Platform

Generated path: `/Users/roman/Developer/iosbrowser/README.md`

This monorepo is a production-grade foundation for a multi-profile browser platform:

- Desktop: Electron, Chromium, React, TypeScript.
- iOS: SwiftUI with `WKWebView`, respecting Apple's browser engine restrictions.
- Backend: Fastify service layer backed by Supabase/PostgreSQL and Redis.
- Shared packages: API contracts, profile isolation, proxy policy, AI providers, sync, security, vault, observability.
- Infrastructure: Supabase migrations, Docker Compose, GitHub Actions, security and roadmap docs.

The implementation plan is desktop-first. See `/Users/roman/Developer/iosbrowser/docs/desktop-first-plan.md` and `/Users/roman/Developer/iosbrowser/prompts/desktop/desktop-first-execution.md`.

## Architectural decisions

Profile isolation is modeled as a first-class domain boundary. Desktop uses Electron persistent partitions per profile, while iOS uses per-profile `WKWebsiteDataStore` and app-level metadata because iOS cannot run Chromium or reliably spoof engine fingerprints.

AI capabilities are permissioned by workspace, profile, tab, and action type. Browser actions are represented as auditable intents so agents can be denied, previewed, approved, replayed, and synced safely.

Secrets are never synced in plaintext. Local vault entries are envelope-encrypted; sync stores encrypted payloads plus metadata needed for conflict resolution.

## Local workflow

```bash
pnpm install
pnpm build
pnpm dev:backend
pnpm dev
docker compose -f docker/docker-compose.yml up --build
```

Generate the iOS Xcode project with XcodeGen:

```bash
cd apps/ios
xcodegen generate
```
