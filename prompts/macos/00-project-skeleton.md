# Prompt 00 — Project Skeleton

## Context
We are pivoting `/Users/roman/Developer/iosbrowser` to a **native macOS browser** (Swift + SwiftUI +
WebKit), Arc-style. The repo currently holds a pnpm monorepo with an Electron desktop app
(`apps/desktop`) and an iOS skeleton (`apps/ios`) from a previous direction. We are **not** building
on the Electron app — it stays in place but unmaintained. The repo has **no git history yet**.

This first prompt creates the foundation: version control, a new macOS app target, and an empty
shared Swift package. No browser behavior yet — just a window that opens.

## Goal
Stand up a buildable, runnable native macOS app at `apps/macos` plus an empty `BrowserCore` Swift
package at `packages/BrowserCore`, so every later phase has a home. The app launches to a blank
window. Snapshot the inherited repo in git first.

## Architecture / constraints
- **Swift + SwiftUI, macOS 14 (Sonoma) minimum.** SwiftUI `App` lifecycle (no AppKit `@NSApplicationMain`).
- Two new locations: `apps/macos` (the app) and `packages/BrowserCore` (the shared Swift package).
- `apps/macos` depends on the local `BrowserCore` package via SPM.
- Do not modify `apps/desktop`, `apps/ios`, `packages/*` (the TS packages), `infra/`, or `backend`.
- Use Xcode-compatible project generation. Prefer **XcodeGen** (`project.yml`) or a hand-written
  `.xcodeproj`; if neither is clean, create the project structure so it can be opened in Xcode and
  built with `xcodebuild`. Document the exact open/build commands in `apps/macos/README.md`.

## Tasks
1. **Initialize git** at the repo root (`git init`), add a Swift/Xcode-aware `.gitignore` entries if
   missing (`DerivedData/`, `*.xcuserstate`, `.build/`), and make an initial commit snapshotting the
   current inherited state with message `chore: snapshot inherited monorepo before macOS pivot`.
2. Create the **`BrowserCore` Swift package** at `packages/BrowserCore` (`swift package init --type library`
   or equivalent), platforms `[.macOS(.v14), .iOS(.v17)]`, product `BrowserCore`. Add one placeholder
   `public struct BrowserCoreInfo { public static let version = "0.0.1" }` so it compiles.
3. Create the **`apps/macos` app**: a SwiftUI app target `MacBrowser` (bundle id e.g.
   `com.iosbrowser.macos`), deployment target macOS 14, that depends on the local `BrowserCore`
   package. `App` → single `WindowGroup` → a `ContentView` showing a placeholder (`Text("Browser")`).
4. Wire the SPM dependency so `import BrowserCore` works from the app (reference
   `BrowserCoreInfo.version` somewhere harmless to prove the link).
5. Write `apps/macos/README.md` with the exact commands to open in Xcode and to build/run from CLI
   (`xcodebuild -scheme MacBrowser -destination 'platform=macOS' build`, plus how to launch).
6. Commit: `feat(macos): scaffold native SwiftUI app + BrowserCore package`.

## Acceptance criteria
- [ ] `git log` shows the snapshot commit then the scaffold commit.
- [ ] `BrowserCore` builds on its own (`swift build` in `packages/BrowserCore`).
- [ ] The macOS app builds with no warnings and launches to a window (blank/placeholder is fine).
- [ ] `import BrowserCore` resolves in the app target.
- [ ] `apps/macos/README.md` documents open + build + run commands.

## Out of scope
No WebKit, no tabs, no real UI yet — that starts in Prompt 01. Do not touch the Electron or iOS apps.
