import BrowserCore
import SwiftUI

/// The ⌘Y History sheet: a searchable list of visited pages grouped by day. Selecting a row loads it
/// into the active tab; rows can be deleted individually and ranges cleared from the toolbar. Reads
/// `HistoryStore.entries` (observable), so it updates live as history is recorded or pruned.
struct HistoryView: View {
  @Environment(HistoryStore.self) private var history
  @Environment(SpaceStore.self) private var store
  @Environment(HistoryWindowController.self) private var controller

  @State private var searchText = ""

  var body: some View {
    NavigationStack {
      Group {
        if groups.isEmpty {
          ContentUnavailableView(
            searchText.isEmpty ? "No History" : "No Results",
            systemImage: "clock",
            description: Text(searchText.isEmpty
              ? "Pages you visit will appear here."
              : "No history matches “\(searchText)”.")
          )
        } else {
          historyList
        }
      }
      .navigationTitle("History")
      .searchable(text: $searchText, placement: .toolbar, prompt: "Search History")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { controller.dismiss() }
        }
        ToolbarItem {
          Menu {
            Button("Clear Last Hour") { history.clear(since: Date().addingTimeInterval(-3600)) }
            Button("Clear Today") { history.clear(since: Calendar.current.startOfDay(for: Date())) }
            Divider()
            Button("Clear All History", role: .destructive) { history.clear(since: nil) }
          } label: {
            Label("Clear", systemImage: "trash")
          }
          .disabled(history.entries.isEmpty)
        }
      }
    }
    .frame(minWidth: 520, minHeight: 460)
  }

  private var historyList: some View {
    List {
      ForEach(groups, id: \.day) { group in
        Section(dayLabel(group.day)) {
          ForEach(group.entries) { entry in
            HistoryRow(entry: entry)
              .contentShape(Rectangle())
              .onTapGesture { open(entry.url) }
              .contextMenu {
                Button("Delete", role: .destructive) { history.delete(entry) }
              }
              .swipeActions {
                Button("Delete", role: .destructive) { history.delete(entry) }
              }
          }
        }
      }
    }
  }

  // MARK: - Actions

  /// Load the chosen page into the active tab and close the sheet (mirrors `CommandBarView.open`).
  private func open(_ url: URL) {
    store.activeSpace?.tabManager.activeTab?.load(url)
    controller.dismiss()
  }

  // MARK: - Grouping

  /// Search results grouped by calendar day, most-recent day first and most-recent visit first
  /// within each day.
  private var groups: [(day: Date, entries: [HistoryEntry])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: history.search(searchText)) {
      calendar.startOfDay(for: $0.visitedAt)
    }
    return grouped.keys.sorted(by: >).map { day in
      (day: day, entries: grouped[day]!.sorted { $0.visitedAt > $1.visitedAt })
    }
  }

  private func dayLabel(_ day: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "Today" }
    if calendar.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(date: .complete, time: .omitted)
  }
}

/// One history row: favicon placeholder, title (falling back to host/URL), the URL, and the visit
/// time. Matches `TabRow`'s globe-placeholder convention until real favicons land.
private struct HistoryRow: View {
  let entry: HistoryEntry

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "globe")
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 1) {
        Text(entry.title.isEmpty ? (entry.url.host() ?? entry.url.absoluteString) : entry.title)
          .lineLimit(1)
        Text(entry.url.absoluteString)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      Text(entry.visitedAt.formatted(date: .omitted, time: .shortened))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}
