import Foundation
import SwiftData
import XCTest
@testable import BrowserCore

@MainActor
final class DownloadStoreTests: XCTestCase {
  // MARK: - Helpers

  /// A fresh in-memory container scoped to `DownloadRecord`. Returned (not just its context) so the
  /// caller keeps it alive for the store's lifetime.
  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([DownloadRecord.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: configuration)
  }

  private func seed(
    _ context: ModelContext,
    id: UUID = UUID(),
    filename: String = "file.bin",
    state: DownloadState,
    totalBytes: Int64 = 100,
    bytesReceived: Int64 = 100
  ) {
    context.insert(DownloadRecord(
      id: id,
      filename: filename,
      destinationPath: "/tmp/\(filename)",
      sourceURL: URL(string: "https://example.com/\(filename)"),
      totalBytes: totalBytes,
      bytesReceived: bytesReceived,
      stateRaw: state.rawValue,
      startedAt: Date(timeIntervalSince1970: 1000)
    ))
    try? context.save()
  }

  private func tempDirectory() throws -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  // MARK: - Filename uniquification

  func testUniqueURLReturnsSuggestedWhenNoCollision() throws {
    let dir = try tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = DownloadStore.uniqueURL(in: dir, for: "report.pdf")
    XCTAssertEqual(url.lastPathComponent, "report.pdf")
  }

  func testUniqueURLAppendsCounterBeforeExtension() throws {
    let dir = try tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    FileManager.default.createFile(atPath: dir.appendingPathComponent("report.pdf").path, contents: Data())

    let url = DownloadStore.uniqueURL(in: dir, for: "report.pdf")
    XCTAssertEqual(url.lastPathComponent, "report (1).pdf")
  }

  func testUniqueURLSkipsTakenCounters() throws {
    let dir = try tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    FileManager.default.createFile(atPath: dir.appendingPathComponent("report.pdf").path, contents: Data())
    FileManager.default.createFile(atPath: dir.appendingPathComponent("report (1).pdf").path, contents: Data())

    let url = DownloadStore.uniqueURL(in: dir, for: "report.pdf")
    XCTAssertEqual(url.lastPathComponent, "report (2).pdf")
  }

  func testUniqueURLHandlesNamesWithoutExtension() throws {
    let dir = try tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    FileManager.default.createFile(atPath: dir.appendingPathComponent("archive").path, contents: Data())

    let url = DownloadStore.uniqueURL(in: dir, for: "archive")
    XCTAssertEqual(url.lastPathComponent, "archive (1)")
  }

  func testUniqueURLFallsBackForEmptyName() throws {
    let dir = try tempDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = DownloadStore.uniqueURL(in: dir, for: "")
    XCTAssertEqual(url.lastPathComponent, "download")
  }

  // MARK: - Persistence / load

  func testStaleInProgressIsRecoveredAsFailedOnLoad() throws {
    let container = try makeContainer()
    seed(container.mainContext, state: .inProgress)

    let store = DownloadStore(modelContext: container.mainContext)
    XCTAssertEqual(store.items.count, 1)
    XCTAssertEqual(store.items.first?.state, .failed)

    // The recovery is persisted, so a second store sees the corrected terminal state too.
    let reopened = DownloadStore(modelContext: container.mainContext)
    XCTAssertEqual(reopened.items.first?.state, .failed)
  }

  func testFinishedRecordLoadsAsFullProgress() throws {
    let container = try makeContainer()
    seed(container.mainContext, state: .finished, totalBytes: 2048, bytesReceived: 2048)

    let store = DownloadStore(modelContext: container.mainContext)
    let item = try XCTUnwrap(store.items.first)
    XCTAssertEqual(item.state, .finished)
    XCTAssertEqual(item.fractionCompleted, 1)
  }

  func testItemsAreNewestFirst() throws {
    let container = try makeContainer()
    let context = container.mainContext
    context.insert(DownloadRecord(id: UUID(), filename: "old", destinationPath: "/tmp/old",
                                  sourceURL: nil, totalBytes: 1, bytesReceived: 1,
                                  stateRaw: DownloadState.finished.rawValue,
                                  startedAt: Date(timeIntervalSince1970: 1000)))
    context.insert(DownloadRecord(id: UUID(), filename: "new", destinationPath: "/tmp/new",
                                  sourceURL: nil, totalBytes: 1, bytesReceived: 1,
                                  stateRaw: DownloadState.finished.rawValue,
                                  startedAt: Date(timeIntervalSince1970: 2000)))
    try? context.save()

    let store = DownloadStore(modelContext: context)
    XCTAssertEqual(store.items.map(\.filename), ["new", "old"])
  }

  // MARK: - Mutations

  func testClearCompletedRemovesTerminalItems() throws {
    let container = try makeContainer()
    let context = container.mainContext
    seed(context, filename: "a", state: .finished)
    seed(context, filename: "b", state: .failed)
    seed(context, filename: "c", state: .cancelled)

    let store = DownloadStore(modelContext: context)
    XCTAssertEqual(store.items.count, 3)

    store.clearCompleted()
    XCTAssertTrue(store.items.isEmpty)
  }

  func testRemoveDeletesSingleItem() throws {
    let container = try makeContainer()
    let context = container.mainContext
    let keep = UUID()
    let drop = UUID()
    seed(context, id: keep, filename: "keep", state: .finished)
    seed(context, id: drop, filename: "drop", state: .finished)

    let store = DownloadStore(modelContext: context)
    store.remove(drop)

    XCTAssertEqual(store.items.map(\.id), [keep])
  }

  // MARK: - DownloadItem value semantics

  func testFractionCompletedIsNilWhenTotalUnknown() {
    let item = DownloadItem(id: UUID(), filename: "x", destinationPath: "/tmp/x", sourceURL: nil,
                            totalBytes: 0, bytesReceived: 500, state: .inProgress,
                            startedAt: Date(timeIntervalSince1970: 1000))
    XCTAssertNil(item.fractionCompleted)
  }

  func testFractionCompletedClampsToOne() {
    let item = DownloadItem(id: UUID(), filename: "x", destinationPath: "/tmp/x", sourceURL: nil,
                            totalBytes: 100, bytesReceived: 250, state: .inProgress,
                            startedAt: Date(timeIntervalSince1970: 1000))
    XCTAssertEqual(item.fractionCompleted, 1)
  }
}
