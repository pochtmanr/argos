# macOS Electron Platform Prompt

Generated path: `/Users/roman/Developer/iosbrowser/prompts/macos/macos-electron-platform.md`

This platform uses Electron/Chromium for the macOS desktop app. Do not introduce a separate native macOS SwiftUI app unless the architecture is explicitly changed.

Focus areas:

- macOS packaging, signing, notarization, auto-update, and hardened runtime.
- Keychain-backed local vault integration.
- macOS menu commands for tabs, profiles, navigation, and AI sidebar.
- Native file dialogs only through main-process handlers.
- Crash reporting and structured logs with profile IDs redacted where needed.
