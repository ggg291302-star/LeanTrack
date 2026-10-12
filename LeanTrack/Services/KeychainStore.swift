import Foundation
import Security

/// API keys the owner types into Settings. They're kept in the iOS Keychain on this phone only,
/// never in the app's code, its saved data, backups or the repo.
enum KeychainStore {
    enum Key: String, CaseIterable {
        case usdaAPIKey = "usda-api-key"
        case anthropicAPIKey = "anthropic-api-key"
    }

    private static let service = "com.ggg291302.leantrack"

    private static func baseQuery(_ key: Key) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key.rawValue]
    }

    static func string(for key: Key) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty
        else { return nil }
        return value
    }

    static func has(_ key: Key) -> Bool { string(for: key) != nil }

    /// Saves the value, or removes it when it's nil or empty. Returns false if the Keychain refused.
    @discardableResult
    static func set(_ value: String?, for key: Key) -> Bool {
        SecItemDelete(baseQuery(key) as CFDictionary)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return true }
        var query = baseQuery(key)
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func removeAll() {
        for key in Key.allCases { set(nil, for: key) }
    }
}
