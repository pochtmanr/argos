# Chromium Profile Runtime Prompt

Generated path: `/Users/roman/Developer/iosbrowser/prompts/desktop/chromium-profile-runtime.md`

Implement Chromium profile isolation for Electron. Every profile must map to a deterministic `persist:profile-<uuid>` partition, isolated cookies, isolated storage, isolated cache, proxy policy, user-agent policy, permission policy, and vault namespace.

Acceptance checks:

- Switching profiles never reuses the previous profile partition.
- Cookies set in one profile are not visible in another.
- Proxy settings are applied per intended session boundary.
- Permission requests are denied by default and explicitly allowlisted.
- Sensitive profile metadata is logged without secrets.
