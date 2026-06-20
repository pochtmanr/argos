# Parallel Development Task Map

Generated path: `/Users/roman/Developer/iosbrowser/docs/parallel-development-task-map.md`

## Independent streams

1. Desktop runtime: Electron session isolation, React shell, IPC validation, profile switcher.
2. macOS desktop platform: packaging, signing, notarization, Keychain vault, app menus.
3. iOS runtime: SwiftUI shell, WKWebView navigation, profile data store strategy, API client.
4. Backend API: Fastify routes, Supabase auth, Redis websocket fan-out, billing webhooks.
5. Database: migrations, RLS policies, seed data, query tests.
6. AI layer: provider adapters, action schemas, prompt registry, permission engine.
7. Security: vault implementation, key rotation, audit event taxonomy, threat model.
8. Sync: mutation log, device cursors, conflict rules, websocket events.
9. DevOps: Docker, CI, environments, observability, release gates.

## Dependencies

- Desktop is the first app integration target; shared contracts should be proven there before iOS parity work.
- Apps depend on shared API contracts before deep feature work.
- Backend and database must agree on migration names and RLS policies before auth integration.
- AI browser actions depend on security permissions and audit event schemas.
- Sync depends on stable profile, workspace, and device identifiers.
- Billing depends on workspace membership and entitlement APIs.
