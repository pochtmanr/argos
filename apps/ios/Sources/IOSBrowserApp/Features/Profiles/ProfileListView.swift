// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Profiles/ProfileListView.swift
import SwiftUI

struct ProfileListView: View {
  @Environment(ProfileStore.self) private var profileStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(profileStore.profiles) { profile in
        Button {
          profileStore.activate(profile)
          dismiss()
        } label: {
          HStack {
            Circle().fill(Color(hex: profile.colorHex)).frame(width: 12, height: 12)
            Text(profile.displayName)
            Spacer()
            if profile.id == profileStore.activeProfile.id {
              Image(systemName: "checkmark")
            }
          }
        }
      }
      .navigationTitle("Profiles")
    }
  }
}

private extension Color {
  init(hex: String) {
    let scanner = Scanner(string: hex.replacingOccurrences(of: "#", with: ""))
    var value: UInt64 = 0
    scanner.scanHexInt64(&value)
    self.init(
      red: Double((value >> 16) & 0xff) / 255,
      green: Double((value >> 8) & 0xff) / 255,
      blue: Double(value & 0xff) / 255
    )
  }
}
