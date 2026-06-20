// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Models/APIModels.swift
import Foundation

struct SyncMutation: Codable, Identifiable {
  let id: UUID
  let workspaceId: UUID
  let deviceId: UUID
  let profileId: UUID?
  let type: String
  let lamportClock: Int
  let payload: [String: String]
  let createdAt: Date
}

struct Entitlement: Codable {
  let workspaceId: UUID
  let tier: String
  let active: Bool
  let currentPeriodEnd: Date?
}
