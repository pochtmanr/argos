# Testing Architecture

Generated path: `/Users/roman/Developer/iosbrowser/docs/testing-architecture.md`

- Shared packages: deterministic unit tests for contracts, policy decisions, vault encryption, proxy rules, and sync clocks.
- Backend: route tests with Fastify injection, Supabase test project, Redis test container, and RLS migration checks.
- Desktop: Playwright/Electron smoke tests for profile switching, partition IDs, IPC validation, and proxy rule application.
- iOS: XCTest for stores and API clients, UI tests for profile switching and navigation, manual WebKit storage behavior checks per iOS release.
- Security: dependency review, CodeQL, secret scanning, migration review, and AI action approval-path tests.
