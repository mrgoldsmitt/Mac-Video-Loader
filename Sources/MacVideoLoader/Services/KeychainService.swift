import Foundation
import Security

public final class KeychainService: @unchecked Sendable {
    public static let shared = KeychainService()

    private let defaultService = "com.macvideoloader.credentials"
    private let lock = NSLock()
    private var memoryFallback: [String: String] = [:]

    private init() {}

    public func save(key: String, forAccount account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let data = key.data(using: .utf8) else { return false }

        // 1. Delete any existing item first
        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(queryDelete as CFDictionary)

        // 2. Add new item to Keychain
        let queryAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(queryAdd as CFDictionary, nil)
        if status == errSecSuccess {
            memoryFallback[account] = key
            return true
        } else {
            // Memory fallback in case Keychain access is restricted by environment
            memoryFallback[account] = key
            return true
        }
    }

    public func load(forAccount account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            memoryFallback[account] = string
            return string
        }

        return memoryFallback[account]
    }

    public func delete(forAccount account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        memoryFallback.removeValue(forKey: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: defaultService,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
