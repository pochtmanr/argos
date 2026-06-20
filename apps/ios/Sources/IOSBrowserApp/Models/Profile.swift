// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Models/Profile.swift
import Foundation

struct BrowserProfile: Identifiable, Codable, Hashable {
  let id: UUID
  var workspaceId: UUID
  var displayName: String
  var colorHex: String
  var proxyId: UUID?
  var vaultNamespace: String
}

extension BrowserProfile {
  static let demo = BrowserProfile(
    id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
    workspaceId: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
    displayName: "Research",
    colorHex: "#2563EB",
    proxyId: nil,
    vaultNamespace: "workspace-demo-research"
  )
}
