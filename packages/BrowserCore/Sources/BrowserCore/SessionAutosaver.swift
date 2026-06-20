import Foundation
import Observation

/// Debounced, observation-driven autosave for a live `SpaceStore`.
///
/// Tracks only the *persisted* fields of the whole graph via `withObservationTracking`; the first
/// mutation of anything tracked schedules a single coalesced save after a short debounce, then
/// re-arms tracking. Transient load state (`estimatedProgress`, `isLoading`) is deliberately never
/// read, so a page loading doesn't trigger a write on every progress tick. Reading the `spaces` /
/// `tabs` arrays means add/close/reorder of either are caught too.
@MainActor
public final class SessionAutosaver {
  private let store: SpaceStore
  private let onSave: (SpaceStore) -> Void
  private let debounce: Duration
  private var pending: Task<Void, Never>?

  public init(
    store: SpaceStore,
    debounce: Duration = .milliseconds(750),
    onSave: @escaping (SpaceStore) -> Void
  ) {
    self.store = store
    self.onSave = onSave
    self.debounce = debounce
    arm()
  }

  /// Registers a one-shot observation over every persisted field. `withObservationTracking` fires
  /// `onChange` once, for the first mutation of anything touched here, so we re-arm afterwards.
  private func arm() {
    withObservationTracking {
      _ = store.activeSpaceID
      for space in store.spaces {
        _ = space.name
        _ = space.colorHex
        _ = space.icon
        let manager = space.tabManager
        _ = manager.activeTabID
        for tab in manager.tabs {
          _ = tab.url
          _ = tab.title
          _ = tab.isPinned
          _ = tab.lastAccessed
        }
      }
    } onChange: { [weak self] in
      // onChange runs synchronously inside the mutation; hop to the main actor to re-arm and schedule.
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.scheduleSave()
        self.arm()
      }
    }
  }

  /// Coalesces a burst of changes into one save after `debounce`.
  private func scheduleSave() {
    pending?.cancel()
    pending = Task { [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: self.debounce)
      guard !Task.isCancelled else { return }
      self.onSave(self.store)
    }
  }

  /// Cancels any pending debounce and saves immediately. Call on app termination so the last change
  /// isn't lost inside the debounce window.
  public func flush() {
    pending?.cancel()
    pending = nil
    onSave(store)
  }
}
