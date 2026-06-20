import AppKit
import BrowserCore
import SwiftUI

/// The browser chrome that drives the active ``WebTab``: navigation buttons, an editable address
/// field with URL/search parsing, and a load-progress indicator. Replaces the throwaway strip from
/// Prompt 01.
struct ToolbarView: View {
  /// The tab being controlled. Read-only `@Observable` state; this view only reads it and calls its
  /// navigation methods, so no `@Bindable` is needed.
  let tab: WebTab

  private let parser = URLBarParser()

  /// The address field's editable text. Mirrors `tab.url` when unfocused; holds the user's typing
  /// while focused.
  @State private var text = ""
  @FocusState private var addressFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Button { tab.goBack() } label: { Image(systemName: "chevron.backward") }
          .disabled(!tab.canGoBack)
          .help("Back")

        Button { tab.goForward() } label: { Image(systemName: "chevron.forward") }
          .disabled(!tab.canGoForward)
          .help("Forward")

        Button {
          if tab.isLoading { tab.stop() } else { tab.reload() }
        } label: {
          Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
        }
        .help(tab.isLoading ? "Stop" : "Reload")

        addressField
      }
      .buttonStyle(.borderless)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      progressBar
    }
    .background(.bar)
    .onAppear(perform: syncTextToURL)
    .onChange(of: tab.url) {
      // Reflect programmatic navigation (clicks, back/forward) — but never clobber active typing.
      if !addressFocused { syncTextToURL() }
    }
    .onChange(of: addressFocused) { _, focused in
      if focused {
        selectAll()
      } else {
        // Focus left without committing (Return) — restore the current URL.
        syncTextToURL()
      }
    }
  }

  // MARK: - Address field

  private var addressField: some View {
    HStack(spacing: 6) {
      // Favicon affordance — placeholder for now; real favicons arrive later.
      Image(systemName: "globe")
        .foregroundStyle(.secondary)
        .imageScale(.small)

      TextField("Search or enter address", text: $text)
        .textFieldStyle(.plain)
        .focused($addressFocused)
        .onSubmit(commit)
        .onKeyPress(.escape) {
          syncTextToURL()
          addressFocused = false
          return .handled
        }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(Capsule().fill(Color(nsColor: .textBackgroundColor)))
    .overlay(Capsule().strokeBorder(.separator))
    // Title affordance: hover the field to see the current page title.
    .help(tab.title.isEmpty ? (tab.url?.absoluteString ?? "") : tab.title)
  }

  // MARK: - Progress

  @ViewBuilder
  private var progressBar: some View {
    if tab.isLoading {
      ProgressView(value: tab.estimatedProgress)
        .progressViewStyle(.linear)
        .frame(height: 2)
    } else {
      // Keep the row height stable so the toolbar doesn't jump as loading toggles.
      Color.clear.frame(height: 2)
    }
  }

  // MARK: - Actions

  private func commit() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    tab.load(parser.resolve(trimmed))
    addressFocused = false
  }

  private func syncTextToURL() {
    text = tab.url?.absoluteString ?? ""
  }

  /// Selects the whole address (Arc-like) when the field gains focus. SwiftUI has no direct hook,
  /// so route a `selectAll:` action to the focused field's editor on the next runloop tick.
  private func selectAll() {
    DispatchQueue.main.async {
      NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }
  }
}
