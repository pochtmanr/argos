# Electron Browser Shell Prompt

Generated path: `/Users/roman/Developer/iosbrowser/prompts/desktop/electron-browser-shell.md`

Work only inside `apps/desktop` and directly required shared packages. Build a production Electron browser shell with `contextIsolation`, `sandbox`, disabled `nodeIntegration`, typed preload APIs, validated IPC payloads, and no privileged renderer code.

Required surfaces:

- Main window lifecycle.
- BrowserView or WebContentsView tab hosting.
- Per-profile session partitions.
- Address bar navigation.
- Back, forward, reload, stop, and new tab actions.
- AI sidebar state bridge.
- Profile proxy application through main-process code only.
