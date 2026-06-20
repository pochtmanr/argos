# High-Level Architecture

Generated path: `/Users/roman/Developer/iosbrowser/docs/architecture.md`

The platform is split into isolated apps, shared packages, and independently deployable infrastructure.

## Core domains

- Identity and subscription: Supabase Auth, provider login, account membership, subscription entitlement checks.
- Workspace: shared containers for profiles, permissions, AI policies, sync scopes, and billing ownership.
- Profiles: isolated browser containers with cookies, local storage, cache, extension policy, vault bindings, and proxy policy.
- Proxy: per-profile network route policy for HTTP, HTTPS, SOCKS5, and SSH tunnel descriptors.
- AI agent layer: provider-agnostic model gateway, permissioned browser actions, page summarization, tab context, audit logs.
- Sync: event-sourced mutation log with device cursors, conflict rules, and encrypted payload support.
- Security: local vault encryption, RLS policies, action approval gates, structured audit logging.

## App boundaries

Desktop owns Chromium-specific runtime behavior through Electron sessions. iOS owns a native shell using `WKWebView`; it shares contracts and server APIs but does not claim Chromium parity where Apple does not allow it.

Backend exposes REST and websocket APIs for profiles, sync, AI, billing, and audit events. Supabase remains the system of record for auth and Postgres data; Redis supports websocket fan-out and short-lived coordination.
