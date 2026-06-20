// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Sync/SyncClient.swift
import Foundation

struct SyncClient {
  let apiClient: APIClient

  func fetchMutations(workspaceId: UUID, after lamportClock: Int) async throws -> [SyncMutation] {
    try await apiClient.get(
      "/v1/workspaces/\(workspaceId.uuidString)/sync/mutations?after=\(lamportClock)",
      as: [SyncMutation].self
    )
  }
}
