import AppKit
import Combine
import SwiftUI
import BrowserCore

@main
struct MacBrowserApp: App {
  /// Owned here (not in `BrowserWindowView`) so the `.commands` menu and every window share the same
  /// spaces/tabs. `SpaceStore` is the top-level owner; each `Space` owns its own `TabManager`, so a
  /// tab lives in exactly one space. Per-*window* selection (which Space a window shows) lives in
  /// each window's `WindowState`; this store also tracks the exclusive per-window Space claims.
  @State private var store: SpaceStore

  /// Debounced autosave: persists the live `store` to SwiftData on meaningful changes.
  @State private var autosaver: SessionAutosaver

  /// Records browsing history and backs the command bar's history suggestions + the History view.
  /// Shares the persistence container so history lives in the same store file.
  @State private var historyStore: HistoryStore

  /// Per-Space favorites, backing the sidebar strip, the ⌘D toggle, and command-bar suggestions.
  /// Shares the persistence container so favorites live in the same store file.
  @State private var favoritesStore: FavoritesStore

  /// Tracks file downloads and backs the downloads toolbar popover. Shares the persistence container
  /// so the downloads log lives in the same store file. Must stay a single instance — it holds live
  /// `WKDownload` references — so it's app-level and shared across every window.
  @State private var downloadStore: DownloadStore

  /// Auto-archive threshold (Prompt 11), persisted in `UserDefaults`. Injected so the Settings scene
  /// can read/write it and the lifecycle coordinator can read it.
  @State private var archiveSettings: ArchiveSettings

  /// App preferences edited in the Settings scene (Prompt 13): default search engine, home/new-tab URL,
  /// restore-on-launch, sidebar width. Drives address-bar/command-bar search, new tabs/spaces, the
  /// launch restore gate, and the sidebar's default width. Persisted in `UserDefaults`.
  @State private var appSettings: AppSettings

  /// App-level lifecycle side effects (auto-archive tick, foreground archive pass, quit-time autosave
  /// flush). Owned once here — not per window — so they fire exactly once regardless of window count.
  @State private var lifecycle: AppLifecycle

  /// The on-disk session store. Optional so a storage failure never blocks launch — the app just
  /// runs without persistence for that session.
  private let persistence: SessionPersistence?

  init() {
    // Preferences are read first: the home page seeds a fresh session and the restore toggle gates
    // whether the prior session is loaded at all.
    let appSettings = AppSettings()

    // Build the store and honor the dev reset flag before loading, so `BROWSER_RESET_STORE=1` (or the
    // Debug → Reset Store menu item) starts from a clean slate.
    let persistence = try? SessionPersistence()

    // History shares the persistence container; an in-memory store is the fallback when persistence
    // is unavailable (an in-memory SwiftData container effectively never fails to build).
    let historyStore = persistence?.makeHistoryStore() ?? (try! HistoryStore(inMemory: true))

    if ProcessInfo.processInfo.environment["BROWSER_RESET_STORE"] != nil {
      persistence?.reset()
      historyStore.clear(since: nil)
    }

    // Favorites/downloads share the persistence container (in-memory fallback when unavailable),
    // created after the reset above so their caches reflect the post-reset store.
    let favoritesStore = persistence?.makeFavoritesStore() ?? (try! FavoritesStore(inMemory: true))
    let downloadStore = persistence?.makeDownloadStore() ?? (try! DownloadStore(inMemory: true))

    // Restore the previous session when the user has restore-on-launch enabled and one exists;
    // otherwise seed a fresh default space and load the home page into its tab (first-run behavior).
    // Restored tabs are lazy — each window loads its active tab the first time it becomes active.
    let store: SpaceStore
    if appSettings.restoreOnLaunch, let restored = persistence?.load() {
      store = restored
    } else {
      store = SpaceStore()
      store.activeSpace?.tabManager.activeTab?.load(appSettings.homeURL)
    }

    // Record committed navigations into history. Set after restore so every tab (restored or new)
    // reports through the cascade down `SpaceStore → TabManager → WebTab`.
    store.historyRecorder = { [weak historyStore] url, title in
      historyStore?.record(url: url, title: title)
    }

    // Hand each download WebKit surfaces to the download store, via the same cascade as history.
    store.onDownloadStart = { [weak downloadStore] download in
      downloadStore?.start(download)
    }

    let archiveSettings = ArchiveSettings()
    let autosaver = SessionAutosaver(store: store) { [persistence] snapshot in
      persistence?.save(snapshot)
    }

    self.persistence = persistence
    _appSettings = State(initialValue: appSettings)
    _store = State(initialValue: store)
    _historyStore = State(initialValue: historyStore)
    _favoritesStore = State(initialValue: favoritesStore)
    _downloadStore = State(initialValue: downloadStore)
    _archiveSettings = State(initialValue: archiveSettings)
    _autosaver = State(initialValue: autosaver)
    _lifecycle = State(initialValue: AppLifecycle(
      store: store, archiveSettings: archiveSettings, flush: { autosaver.flush() }
    ))
  }

  var body: some Scene {
    // Value-based group: each window is keyed by its `WindowState.ID`. Opening a value that's already
    // shown focuses that window — used to focus the window that owns a Space on a switch collision.
    WindowGroup(for: WindowState.ID.self) { $id in
      BrowserWindowView(windowID: id ?? WindowState.ID())
        .environment(store)
        .environment(historyStore)
        .environment(favoritesStore)
        .environment(downloadStore)
        .environment(archiveSettings)
        .environment(appSettings)
    }
    .commands {
      BrowserCommands(store: store, favoritesStore: favoritesStore, appSettings: appSettings)

      #if DEBUG
      // Developer aid: wipe the persisted store and start over. Mirrors the `BROWSER_RESET_STORE`
      // launch flag but available at runtime.
      CommandMenu("Debug") {
        Button("Reset Store") { resetStore() }
      }
      #endif
    }

    // The Preferences window (⌘,). A separate scene from the `WindowGroup`, so it needs its own
    // environment injection of the settings stores it edits.
    Settings {
      SettingsView()
        .environment(appSettings)
        .environment(archiveSettings)
    }
  }

  #if DEBUG
  /// Clears the persisted store and replaces the live session with a fresh default space, re-arming
  /// the autosaver and lifecycle coordinator on the new store so subsequent edits persist.
  private func resetStore() {
    persistence?.reset()
    historyStore.clear(since: nil)
    favoritesStore.refresh()
    let fresh = SpaceStore()
    fresh.historyRecorder = { [weak historyStore] url, title in
      historyStore?.record(url: url, title: title)
    }
    fresh.onDownloadStart = { [weak downloadStore] download in
      downloadStore?.start(download)
    }
    fresh.activeSpace?.tabManager.activeTab?.load(appSettings.homeURL)
    persistence?.save(fresh)
    store = fresh
    let newAutosaver = SessionAutosaver(store: fresh) { [persistence] in persistence?.save($0) }
    autosaver = newAutosaver
    lifecycle = AppLifecycle(store: fresh, archiveSettings: archiveSettings, flush: { newAutosaver.flush() })
  }
  #endif
}

/// Owns the app-wide lifecycle side effects so they run once, independent of how many windows are
/// open: a steady auto-archive tick, an archive pass when the app returns to the foreground, and a
/// quit-time flush of the debounced autosave. Replacing the instance cancels its subscriptions.
@MainActor
final class AppLifecycle {
  private var cancellables: Set<AnyCancellable> = []

  init(store: SpaceStore, archiveSettings: ArchiveSettings, flush: @escaping () -> Void) {
    // Auto-archive (Prompt 11): sweep idle tabs on a steady tick. The pass is a no-op when nothing
    // is stale, so the minute timer is cheap.
    Timer.publish(every: 60, on: .main, in: .common).autoconnect()
      .sink { [weak store, weak archiveSettings] _ in
        guard let store, let archiveSettings else { return }
        store.archiveStaleTabs(threshold: archiveSettings.threshold)
      }
      .store(in: &cancellables)

    // Also sweep whenever the app returns to the foreground (which also fires shortly after launch).
    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      .sink { [weak store, weak archiveSettings] _ in
        guard let store, let archiveSettings else { return }
        store.archiveStaleTabs(threshold: archiveSettings.threshold)
      }
      .store(in: &cancellables)

    // Flush the debounced autosave on quit so the last change isn't lost to the debounce window.
    NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
      .sink { _ in flush() }
      .store(in: &cancellables)
  }
}

extension SpaceStore {
  /// App-level convenience: create a space (with a rotating accent color so new spaces look
  /// distinct) and load `home` into its seeded tab. Lives in the app layer, and takes the home URL as
  /// a parameter, because `BrowserCore` doesn't know the (now user-configurable) home page.
  @discardableResult
  func newSpaceWithHome(_ home: URL) -> Space {
    let colorHex = SpaceColor.palette[spaces.count % SpaceColor.palette.count]
    let space = newSpace(name: "New Space", colorHex: colorHex)
    space.tabManager.activeTab?.load(home)
    return space
  }
}
