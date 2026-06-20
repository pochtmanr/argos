import SwiftUI
import BrowserCore

/// The browser window's root chrome: a `NavigationSplitView` with the vertical tab `SidebarView`
/// (plus the Spaces switcher) on the left and, on the right, the address `ToolbarView` above the
/// active tab's web view.
///
/// Shared app state (`SpaceStore` and its tabs, history/favorites/downloads, settings) is injected
/// from the app. Per-window selection and presentation live in this window's `WindowState`: which
/// Space it shows, the sidebar visibility, and its own command-bar/history/downloads controllers.
/// The active space's `TabManager` is injected into the environment so the tab `SidebarView`/`TabRow`/
/// detail pane keep operating on a plain `TabManager`, unaware of spaces.
///
/// Each window exclusively *claims* the Space it displays (see `WindowState`), so two windows never
/// mount the same tab's single `WKWebView` — they always show different Spaces.
struct BrowserWindowView: View {
  @Environment(SpaceStore.self) private var store
  @Environment(DownloadStore.self) private var downloadStore
  @Environment(AppSettings.self) private var appSettings

  /// This window's local state, created once per window and keyed by the `WindowGroup` value.
  @State private var windowState: WindowState

  init(windowID: WindowState.ID) {
    _windowState = State(initialValue: WindowState(id: windowID))
  }

  var body: some View {
    @Bindable var windowState = windowState
    return Group {
      // Render the split view only once this window has claimed a Space. The sidebar and detail read
      // the active Space's `TabManager` from the environment, so they must not evaluate before that
      // manager exists — the claim lands in `.onAppear` below, which fires *after* the first body
      // render. Until then this placeholder (which reads no `TabManager`) fills the window.
      if let space = windowState.activeSpace(in: store) {
        NavigationSplitView(columnVisibility: $windowState.columnVisibility) {
          SidebarView()
            // `ideal:` is the Settings-controlled default width. `NavigationSplitView` doesn't report a
            // user's manual drag back to us, so this sets the opening/default width, not a live mirror.
            .navigationSplitViewColumnWidth(min: 200, ideal: appSettings.sidebarIdealWidth, max: 360)
        } detail: {
          detailPane
        }
        // The ⌘L / ⌘T command bar floats centered over the whole window chrome when open.
        .overlay {
          if windowState.commandBar.isPresented {
            CommandBarView()
          }
        }
        // ⌘Y History sheet.
        .sheet(isPresented: historyPresented) {
          HistoryView()
        }
        .toolbar {
          // No custom sidebar-toggle button here: `NavigationSplitView` auto-inserts one, and adding a
          // second (at `.navigation`) made the toggle appear twice. The ⌥⌘S View ▸ Toggle Sidebar menu
          // item (BrowserCommands) covers the keyboard path.
          //
          // Safari-style single top line: back/forward sit next to the sidebar toggle, the address pill
          // takes the centered `.principal` slot, and the actions live trailing in `.primaryAction`.
          if let tab = space.tabManager.activeTab {
            ToolbarItem(placement: .navigation) {
              Button { tab.goBack() } label: { Image(systemName: "chevron.backward") }
                .disabled(!tab.canGoBack)
                .help("Back")
            }
            ToolbarItem(placement: .navigation) {
              Button { tab.goForward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!tab.canGoForward)
                .help("Forward")
            }
            ToolbarItem(placement: .principal) {
              // `.id(tab.id)` gives the field fresh @State (address text/focus) per active tab.
              AddressBarView(tab: tab)
                .id(tab.id)
            }
          }
          // Trailing actions: New Tab, proxy/AI inspectors, and downloads. Favorites now lives inside
          // the address pill (see AddressBarView's trailing star), and the share button was removed.
          // "+" needs no active tab, so it sits outside the `if let tab` block above.
          ToolbarItemGroup(placement: .primaryAction) {
            Button {
              space.tabManager.newTab()
            } label: {
              Image(systemName: "plus")
            }
            .help("New Tab (⌘T)")
            Button {
              windowState.toggleRightPanel(.proxy)
            } label: {
              Image(systemName: "network")
                .symbolVariant(windowState.rightPanel == .proxy ? .fill : .none)
            }
            .help("Proxy")
            Button {
              windowState.toggleRightPanel(.ai)
            } label: {
              Image(systemName: "sparkles")
                .foregroundStyle(windowState.rightPanel == .ai ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
            .help("AI Assistant")
            Button {
              windowState.downloads.toggle()
            } label: {
              // Filled (and tinted) while a download is active, so the icon doubles as the active indicator.
              Image(systemName: hasActiveDownload ? "arrow.down.circle.fill" : "arrow.down.circle")
                .symbolRenderingMode(hasActiveDownload ? .multicolor : .monochrome)
            }
            .help("Downloads")
            .popover(isPresented: downloadsPresented, arrowEdge: .bottom) {
              DownloadsPopoverView()
            }
          }
        }
        // Scope the tab views to this window's active space's manager. Non-nil here (we're inside the
        // `if let`); re-injected when the active space changes so the sidebar/detail swap tab sets.
        .environment(space.tabManager)
      } else {
        Color(nsColor: .windowBackgroundColor)
      }
    }
    .frame(minWidth: 900, minHeight: 600)
    // Give this window its Arc-style chrome (transparent titlebar, full-height sidebar). Zero-size, so
    // it only reaches the hosting `NSWindow`; each window configures itself.
    .background(WindowConfigurator())
    // Publish this window's state so the app menu's commands act on the focused window.
    .focusedSceneValue(\.windowState, windowState)
    // Inject the per-window controllers by type so child views (command bar, history, downloads) keep
    // reading them from the environment but now get *this* window's instances, plus the window state
    // itself for the Spaces switcher.
    .environment(windowState)
    .environment(windowState.commandBar)
    .environment(windowState.history)
    .environment(windowState.downloads)
    // Claim a Space on first appear (first unclaimed, honoring the restore hint, else a new Space),
    // and release the claim when the window closes so another window can reuse the Space.
    .onAppear { windowState.claimInitialSpace(in: store, homeURL: appSettings.homeURL) }
    .onDisappear { windowState.release(in: store) }
    // Recover if this window's Space is deleted (possibly from another window): re-claim another one.
    .onChange(of: store.spaces.map(\.id)) {
      if windowState.activeSpace(in: store) == nil {
        windowState.claimInitialSpace(in: store, homeURL: appSettings.homeURL)
      }
    }
    // Load a lazily-restored tab the first time it becomes active — on launch and on every space/tab
    // switch — and stamp it accessed (powers auto-archive, Prompt 11). `.task(id:)` re-runs whenever
    // the active (space, tab) pair changes.
    .task(id: activeTabKey) {
      guard let tab = windowState.activeSpace(in: store)?.tabManager.activeTab else { return }
      tab.markAccessed()
      tab.ensureLoaded()
    }
  }

  /// Bridges this window's `HistoryWindowController` flag to `.sheet(isPresented:)` so Escape / the
  /// Done button (which flip the flag) dismiss the sheet too.
  private var historyPresented: Binding<Bool> {
    Binding(get: { windowState.history.isPresented },
            set: { windowState.history.isPresented = $0 })
  }

  /// Bridges this window's `DownloadsController` flag to `.popover(isPresented:)` so ⌘⇧J / the toolbar
  /// button / dismissing the popover all stay in sync.
  private var downloadsPresented: Binding<Bool> {
    Binding(get: { windowState.downloads.isPresented },
            set: { windowState.downloads.isPresented = $0 })
  }

  /// Whether any download is currently running — drives the toolbar icon's active indicator.
  private var hasActiveDownload: Bool {
    downloadStore.items.contains { $0.state == .inProgress }
  }

  /// Identity of the active (space, tab) pair, so `.task(id:)` fires once per distinct activation.
  private var activeTabKey: String {
    let space = windowState.activeSpaceID?.uuidString ?? "none"
    let tab = windowState.activeSpace(in: store)?.tabManager.activeTabID?.uuidString ?? "none"
    return "\(space):\(tab)"
  }

  /// The detail pane: address toolbar atop this window's active tab content. Every tab in the active
  /// space stays mounted in a `ZStack`; only the active one is visible and interactive. Keeping the
  /// `WKWebView`s alive (rather than swapping a single `WebView`) means switching tabs never re-hosts
  /// or reloads a page. Only the active space's tabs are mounted; inactive spaces' web views stay
  /// alive in memory but leave the hierarchy until that space is reselected, so switching back is
  /// instant with page/scroll/history intact.
  @ViewBuilder
  private var detailPane: some View {
    if let space = windowState.activeSpace(in: store), let tab = space.tabManager.activeTab {
      VStack(spacing: 0) {
        // Tabs sit directly under the unified top toolbar (nav + address pill now live in the native
        // title-bar toolbar, Safari-style).
        TabStripView()

        // Web view on the left; the proxy/AI inspector slides in on the right when open.
        HStack(spacing: 0) {
          ZStack {
            ForEach(space.tabManager.tabs) { tab in
              WebView(tab: tab)
                .opacity(tab.id == space.tabManager.activeTabID ? 1 : 0)
                .allowsHitTesting(tab.id == space.tabManager.activeTabID)
            }
            // A blank active tab (no URL) is a new-tab page: cover its empty web view with the
            // favorites start page. Loading a URL into the tab replaces this with the live page.
            if let active = space.tabManager.activeTab, active.url == nil {
              StartPageView(tab: active)
            }
          }
          // Make the per-space web-view container identity explicit across space switches.
          .id(space.id)

          if windowState.rightPanel != nil {
            Divider()
            RightPanelView()
          }
        }
      }
    }
  }
}

#Preview {
  BrowserWindowView(windowID: WindowState.ID())
    .environment(SpaceStore())
    .environment(try! HistoryStore(inMemory: true))
    .environment(try! DownloadStore(inMemory: true))
    .environment(try! FavoritesStore(inMemory: true))
    .environment(AppSettings())
}
