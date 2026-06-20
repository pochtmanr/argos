import Foundation
import Observation

/// Owns an ordered collection of `Space`s and tracks which one is active.
///
/// Mirrors `TabManager`'s design one level up: spaces are referenced by `Space.ID` (not index), so
/// the active selection survives reordering, and there is always at least one space — deleting the
/// last one reseeds a fresh default. Each `Space` owns its own `TabManager`, so switching spaces
/// swaps the entire visible tab set while every space's tabs (and their `WKWebView`s) stay alive in
/// memory; the UI simply mounts only the active space's web views. This type is platform-agnostic;
/// the hosting app decides what a new space's tab loads.
@Observable
@MainActor
public final class SpaceStore {
  /// The spaces in display order.
  public private(set) var spaces: [Space]
  /// The id of the active space, or `nil` only transiently. There is always at least one space.
  public private(set) var activeSpaceID: Space.ID?

  /// The active space resolved from `activeSpaceID`, or `nil` if it cannot be found.
  public var activeSpace: Space? {
    guard let activeSpaceID else { return nil }
    return spaces.first { $0.id == activeSpaceID }
  }

  /// Seeds exactly one default space and makes it active. Its `TabManager` seeds one blank tab, so
  /// the app is never empty on first run.
  public init() {
    let first = Self.makeDefaultSpace()
    self.spaces = [first]
    self.activeSpaceID = first.id
  }

  /// Appends a fresh space, makes it active, and returns it. The new space starts with its own
  /// seeded blank tab; the hosting app decides what to load into it.
  @discardableResult
  public func newSpace(
    name: String = "New Space",
    colorHex: String = SpaceStore.defaultColorHex,
    icon: String = SpaceStore.defaultIcon
  ) -> Space {
    let space = Space(name: name, colorHex: colorHex, icon: icon)
    spaces.append(space)
    activeSpaceID = space.id
    return space
  }

  /// Makes the space with `id` active, if it exists.
  public func switchTo(_ id: Space.ID) {
    guard spaces.contains(where: { $0.id == id }) else { return }
    activeSpaceID = id
  }

  /// Renames the space with `id`, if it exists.
  public func rename(_ id: Space.ID, to name: String) {
    space(id)?.name = name
  }

  /// Recolors the space with `id` (hex string), if it exists.
  public func recolor(_ id: Space.ID, to colorHex: String) {
    space(id)?.colorHex = colorHex
  }

  /// Sets the SF Symbol icon for the space with `id`, if it exists.
  public func setIcon(_ id: Space.ID, to icon: String) {
    space(id)?.icon = icon
  }

  /// Deletes the space with `id`.
  ///
  /// If the deleted space was active, selects the space that shifts into the freed slot (the right
  /// neighbor), falling back to the new last space when the rightmost is deleted. If this empties
  /// the collection, a fresh default space is created and made active so the app is never empty —
  /// mirroring `TabManager.closeTab`. Removing the space drops the last strong reference to its
  /// `TabManager`/`WebTab`s, so its web views are released.
  public func deleteSpace(_ id: Space.ID) {
    guard let index = spaces.firstIndex(where: { $0.id == id }) else { return }
    let wasActive = activeSpaceID == id
    spaces.remove(at: index)

    if spaces.isEmpty {
      let fresh = Self.makeDefaultSpace()
      spaces = [fresh]
      activeSpaceID = fresh.id
      return
    }

    if wasActive {
      let neighbor = spaces[min(index, spaces.count - 1)]
      activeSpaceID = neighbor.id
    }
  }

  /// Moves the space at `from` to `to` (remove-then-insert semantics, both clamped to valid
  /// ranges). The active selection is preserved by identity, independent of index.
  public func moveSpace(from: Int, to: Int) {
    guard spaces.indices.contains(from) else { return }
    let space = spaces.remove(at: from)
    let destination = min(max(to, 0), spaces.count)
    spaces.insert(space, at: destination)
  }

  // MARK: - Defaults & helpers

  /// Default accent color for a seeded space.
  public static let defaultColorHex = "#3B82F6"
  /// Default SF Symbol for a seeded space.
  public static let defaultIcon = "square.stack"

  private func space(_ id: Space.ID) -> Space? {
    spaces.first { $0.id == id }
  }

  private static func makeDefaultSpace() -> Space {
    Space(name: "Personal", colorHex: defaultColorHex, icon: defaultIcon)
  }
}
