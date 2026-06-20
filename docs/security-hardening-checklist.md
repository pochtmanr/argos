# Security Hardening Checklist

Generated path: `/Users/roman/Developer/iosbrowser/docs/security-hardening-checklist.md`

- Enforce Supabase RLS for every table that contains user, workspace, profile, sync, proxy, or vault metadata.
- Keep service-role keys server-only; desktop and iOS use anon keys or backend-issued short-lived tokens.
- Store local secrets only through platform keychain/keytar-backed vault implementations.
- Require explicit user approval for AI actions that submit forms, send messages, purchase items, export data, or modify credentials.
- Audit all AI actions with prompt hash, model provider, requested permission, tab origin, result status, and actor.
- Disable Electron `nodeIntegration`, enable `contextIsolation`, validate every IPC payload with Zod.
- Use per-profile Electron partitions and never share profile partition IDs between accounts.
- On iOS, use separate `WKWebsiteDataStore` strategy and never claim complete fingerprint spoofing.
- Validate proxy URLs, block loopback/private destinations unless the user enables local-network routing.
- Encrypt vault payloads with AES-256-GCM and rotate data keys per workspace.
- Apply dependency review and CodeQL in CI.
- Run migrations through reviewed PRs only; prohibit direct production schema edits.
