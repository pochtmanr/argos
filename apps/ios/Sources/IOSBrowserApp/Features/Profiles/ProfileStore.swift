// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Profiles/ProfileStore.swift
import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {
  private(set) var profiles: [BrowserProfile]
  var activeProfile: BrowserProfile

  init(profiles: [BrowserProfile] = [.demo], activeProfile: BrowserProfile = .demo) {
    self.profiles = profiles
    self.activeProfile = activeProfile
  }

  func activate(_ profile: BrowserProfile) {
    guard profiles.contains(profile) else { return }
    activeProfile = profile
  }

  func upsert(_ profile: BrowserProfile) {
    if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
      profiles[index] = profile
    } else {
      profiles.append(profile)
    }
  }
}
