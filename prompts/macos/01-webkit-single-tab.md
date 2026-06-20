# Prompt 01 — WebKit Single Tab

## Context
The macOS app (`apps/macos`, target `MacBrowser`) opens a blank window and links the `BrowserCore`
Swift package (Prompt 00). Now we make it actually render the web. This is the **engine layer** — it
lives in `BrowserCore` and is written to be reusable by iOS later, so keep it free of macOS-only chrome.

## Goal
Render one real webpage in the window via `WKWebView`, with observable loading state (progress, title,
URL, can-go-back/forward). Introduce the two core engine types: a `WebView` representable and a
`WebTab` that owns the `WKWebView` and its delegates.

## Architecture / constraints
- All code in **`packages/BrowserCore`**. The app just hosts the view.
- `WebView` is **platform-conditional**: `NSViewRepresentable` under `#if os(macOS)`,
  `UIViewRepresentable` under `#if os(iOS)` (iOS path can be stubbed/minimal now, but compile it).
- `WebTab` is an **`@Observable`** class owning one `WKWebView`, configured with a `WKWebViewConfiguration`.
  It is the single source of truth for: `url`, `title`, `estimatedProgress`, `isLoading`,
  `canGoBack`, `canGoForward`.
- Drive observable properties from **KVO** on the `WKWebView` (`estimatedProgress`, `title`, `url`,
  `canGoBack`, `canGoForward`) and/or `WKNavigationDelegate` callbacks. Clean up observers in `deinit`.
- One `WKWebView` per `WebTab`. Default `WKWebsiteDataStore` (profiles deferred).

## Tasks
1. In `BrowserCore`, add `WebTab` (`@Observable`, `@MainActor`): builds a `WKWebView`, exposes the
   observable nav state, and methods `load(_ url: URL)`, `goBack()`, `goForward()`, `reload()`,
   `stop()`. Implement a private `WKNavigationDelegate` to track load start/finish/fail.
2. Add `WebView` representable that takes a `WebTab` and returns its `WKWebView` (do not recreate the
   web view in `updateNSView`; reuse the tab's instance).
3. In `apps/macos`, hold a single `WebTab` in `ContentView`, render `WebView(tab:)` filling the
   window, and load a hardcoded URL (e.g. `https://www.apple.com`) on appear.
4. Add a thin top strip (temporary) showing the live `title` and a progress bar bound to
   `estimatedProgress` — just to prove the observable wiring (this gets replaced in Prompt 02).
5. Verify KVO observers are removed in `WebTab.deinit` (no crashes on teardown).
6. Commit: `feat(core): WKWebView WebTab + WebView representable rendering one page`.

## Acceptance criteria
- [ ] Launching the app renders a real webpage.
- [ ] The temporary strip shows the page title and a progress bar that animates during load.
- [ ] `goBack/goForward/reload/stop` exist and work when called (wire a temp button or test in a preview).
- [ ] No KVO/observer crash when the window/tab is closed.
- [ ] `WebView`/`WebTab` compile for both `os(macOS)` and `os(iOS)` conditionals.

## Out of scope
No address bar, no multiple tabs. The temp strip is throwaway. URL is hardcoded for now.
