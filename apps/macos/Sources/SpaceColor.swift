import SwiftUI

/// Maps a `Space.colorHex` string to a SwiftUI `Color` and offers curated palettes for the
/// create/recolor/icon pickers.
///
/// `BrowserCore` stays UI-agnostic — a `Space` stores only a hex string and an SF Symbol name — so
/// this hex→`Color` conversion lives in the app layer.
enum SpaceColor {
  /// Accent colors offered in the "Color" context menu. Each is a hex string storable on a `Space`.
  static let palette: [String] = [
    "#3B82F6", // blue
    "#8B5CF6", // purple
    "#EC4899", // pink
    "#EF4444", // red
    "#F59E0B", // amber
    "#10B981", // green
    "#14B8A6", // teal
    "#64748B", // slate
  ]

  /// SF Symbols offered in the "Icon" context menu.
  static let icons: [String] = [
    "square.stack", "person", "briefcase", "house", "star",
    "book", "cart", "hammer", "paintbrush", "leaf", "bolt", "globe",
  ]

  /// Converts a hex string like `"#3B82F6"` (or `"3B82F6"`) to a `Color`, falling back to gray for
  /// malformed input so a bad value can never crash a chip.
  static func color(_ hex: String) -> Color {
    var cleaned = hex.trimmingCharacters(in: .whitespaces)
    if cleaned.hasPrefix("#") { cleaned.removeFirst() }
    guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return .gray }
    let r = Double((value >> 16) & 0xFF) / 255
    let g = Double((value >> 8) & 0xFF) / 255
    let b = Double(value & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
  }
}
