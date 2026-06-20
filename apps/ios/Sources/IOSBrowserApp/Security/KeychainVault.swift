// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Security/KeychainVault.swift
import Foundation
import Security

enum KeychainVault {
  static func save(data: Data, account: String, service: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service
    ]
    SecItemDelete(query as CFDictionary)
    var attributes = query
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
  }

  static func load(account: String, service: String) throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    return item as? Data
  }
}

enum KeychainError: Error {
  case unhandled(OSStatus)
}
