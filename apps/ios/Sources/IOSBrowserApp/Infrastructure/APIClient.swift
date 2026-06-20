// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Infrastructure/APIClient.swift
import Foundation

struct APIClient {
  let baseURL: URL
  var bearerTokenProvider: @Sendable () async throws -> String

  func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
    var request = URLRequest(url: baseURL.appending(path: path))
    request.setValue("Bearer \(try await bearerTokenProvider())", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder.api.decode(type, from: data)
  }
}

extension JSONDecoder {
  static var api: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
