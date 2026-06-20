import AppKit
import BrowserCore
import SwiftUI

/// The downloads popover (toolbar button / ⌘⇧J): a list of downloads newest-first with a live
/// progress bar while running, and per-row cancel / reveal-in-Finder / open / remove actions. Reads
/// `DownloadStore.items` (observable), so it updates live as bytes arrive and as state changes.
///
/// Reveal/open use `NSWorkspace` here in the app layer — `BrowserCore` stays AppKit-free and only
/// hands back the destination path.
struct DownloadsPopoverView: View {
  @Environment(DownloadStore.self) private var downloads

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      if downloads.items.isEmpty {
        ContentUnavailableView(
          "No Downloads",
          systemImage: "tray.and.arrow.down",
          description: Text("Files you download will appear here.")
        )
        .frame(maxHeight: .infinity)
      } else {
        List {
          ForEach(downloads.items) { item in
            DownloadRow(item: item)
          }
        }
        .listStyle(.inset)
      }
    }
    .frame(width: 380, height: 440)
  }

  private var header: some View {
    HStack {
      Text("Downloads").font(.headline)
      Spacer()
      Button("Clear") { downloads.clearCompleted() }
        .disabled(!downloads.items.contains { $0.state != .inProgress })
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}

/// One download row: a state icon, the filename, a progress bar (while running) or status line, and
/// the actions available for the current state.
private struct DownloadRow: View {
  @Environment(DownloadStore.self) private var downloads
  let item: DownloadItem

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: iconName)
        .foregroundStyle(iconColor)
        .font(.title3)
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 3) {
        Text(item.filename.isEmpty ? "download" : item.filename)
          .lineLimit(1)

        if item.state == .inProgress {
          if let fraction = item.fractionCompleted {
            ProgressView(value: fraction).progressViewStyle(.linear)
          } else {
            ProgressView().progressViewStyle(.linear)
          }
        }

        Text(statusText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 6)

      actions
    }
    .padding(.vertical, 2)
  }

  // MARK: Actions

  @ViewBuilder
  private var actions: some View {
    switch item.state {
    case .inProgress:
      iconButton("xmark.circle.fill", help: "Cancel") { downloads.cancel(item.id) }
    case .finished:
      iconButton("magnifyingglass", help: "Show in Finder") {
        NSWorkspace.shared.activateFileViewerSelecting([item.destinationURL])
      }
      iconButton("arrow.up.forward.app", help: "Open") {
        NSWorkspace.shared.open(item.destinationURL)
      }
      iconButton("xmark", help: "Remove from List") { downloads.remove(item.id) }
    case .failed, .cancelled:
      iconButton("xmark", help: "Remove from List") { downloads.remove(item.id) }
    }
  }

  private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) { Image(systemName: systemName) }
      .buttonStyle(.borderless)
      .help(help)
  }

  // MARK: Presentation

  private var iconName: String {
    switch item.state {
    case .inProgress: "arrow.down.circle"
    case .finished: "checkmark.circle.fill"
    case .failed: "exclamationmark.triangle.fill"
    case .cancelled: "minus.circle.fill"
    }
  }

  private var iconColor: Color {
    switch item.state {
    case .inProgress: .accentColor
    case .finished: .green
    case .failed: .orange
    case .cancelled: .secondary
    }
  }

  private var statusText: String {
    switch item.state {
    case .inProgress:
      if item.totalBytes > 0 {
        return "\(byteString(item.bytesReceived)) of \(byteString(item.totalBytes))"
      }
      return byteString(item.bytesReceived)
    case .finished:
      return byteString(item.totalBytes > 0 ? item.totalBytes : item.bytesReceived)
    case .failed:
      return "Failed"
    case .cancelled:
      return "Cancelled"
    }
  }

  private func byteString(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}
