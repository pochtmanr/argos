import BrowserCore
import SwiftUI

/// The Archived sheet: a searchable list of the active Space's auto-archived tabs (Prompt 11). Each row
/// can be **restored** (re-opens a live tab in this Space, reloading its page) or **deleted** for good.
/// Reads the active space's `TabManager` (injected by `BrowserWindowView`, inherited through the sheet),
/// so it updates live as the archive pass runs or tabs are restored/deleted. The archive threshold is
/// edited in the Settings scene (Prompt 13).
struct ArchivedView: View {
  @Environment(TabManager.self) private var manager
  @Environment(\.dismiss) private var dismiss

  @State private var searchText = ""

  var body: some View {
    NavigationStack {
      Group {
        if filtered.isEmpty {
          ContentUnavailableView(
            searchText.isEmpty ? "No Archived Tabs" : "No Results",
            systemImage: "archivebox",
            description: Text(searchText.isEmpty
              ? "Idle tabs are archived here automatically."
              : "No archived tab matches “\(searchText)”.")
          )
        } else {
          archivedList
        }
      }
      .navigationTitle("Archived")
      .searchable(text: $searchText, placement: .toolbar, prompt: "Search Archived")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .frame(minWidth: 520, minHeight: 460)
  }

  private var archivedList: some View {
    List {
      ForEach(filtered) { tab in
        ArchivedRow(tab: tab)
          .contextMenu {
            Button("Restore") { restore(tab) }
            Button("Delete", role: .destructive) { manager.deleteArchived(tab.id) }
          }
          .swipeActions {
            Button("Delete", role: .destructive) { manager.deleteArchived(tab.id) }
            Button("Restore") { restore(tab) }.tint(.blue)
          }
      }
    }
  }

  // MARK: - Actions

  /// Restore the tab into this Space (reloads its page) and close the sheet so the user lands on it.
  private func restore(_ tab: ArchivedTab) {
    manager.restoreArchived(tab.id)
    dismiss()
  }

  /// Archived tabs matching the search, newest-accessed first.
  private var filtered: [ArchivedTab] {
    let sorted = manager.archivedTabs.sorted { $0.lastAccessed > $1.lastAccessed }
    let needle = searchText.lowercased()
    guard !needle.isEmpty else { return sorted }
    return sorted.filter {
      $0.title.lowercased().contains(needle)
        || ($0.url?.absoluteString.lowercased().contains(needle) ?? false)
    }
  }
}

/// One archived row: globe placeholder, title (falling back to host/URL), the URL, and when it was last
/// accessed. Mirrors `HistoryRow`'s layout for visual consistency.
private struct ArchivedRow: View {
  let tab: ArchivedTab

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "globe")
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 1) {
        Text(tab.title.isEmpty ? (tab.url?.host() ?? "New Tab") : tab.title)
          .lineLimit(1)
        if let url = tab.url {
          Text(url.absoluteString)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 8)

      Text(tab.lastAccessed.formatted(date: .abbreviated, time: .shortened))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}
