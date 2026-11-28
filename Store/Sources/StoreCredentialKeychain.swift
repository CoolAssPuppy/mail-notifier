import Foundation
import Security

enum StoreCredentialKeychain {
    private static func query(_ account: String) -> [String: Any] {
        // Never probe the file-based login Keychain. Its items may belong to
        // the independently signed app and require an ACL approval dialog.
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.strategicnerds.MailNotifierApp",
         kSecAttrAccount as String: account,
         kSecUseDataProtectionKeychain as String: true,
         kSecAttrSynchronizable as String: false]
    }

    static func data(for account: String) throws -> Data? {
        var lookup = query(account)
        lookup[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        return result as? Data
    }

    static func set(_ data: Data, for account: String) throws {
        var item = query(account)
        let status = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            try check(SecItemAdd(item as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    static func remove(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
