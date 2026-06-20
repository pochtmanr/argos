# Desktop-First Execution Prompt

Generated path: `/Users/roman/Developer/iosbrowser/prompts/desktop/desktop-first-execution.md`

Build the desktop app first. Treat `apps/desktop` as the primary product surface until browser profile isolation, tabs, proxy routing, vault integration, AI sidebar, and sync hooks work end to end on Electron.

Execution order:

1. Stabilize Electron main/preload/renderer build.
2. Implement typed IPC for profile activation, tab lifecycle, proxy policy, AI sidebar context, and vault references.
3. Add profile-scoped Chromium sessions using Electron partitions.
4. Add browser workspace UI: profile switcher, tabs, address bar, page surface, AI sidebar, and sync state.
5. Add desktop smoke tests for IPC validation, profile partition isolation, and navigation.

Do not start iOS feature parity work until shared contracts used by the desktop runtime are stable.
