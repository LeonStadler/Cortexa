import Foundation
import Security

public final class LicenseStore {
    private let service: String
    private let account: String

    public init(service: String = "com.wisprlocal.license", account: String = "primary") {
        self.service = service
        self.account = account
    }

    public func saveLicenseKey(_ key: String) throws {
        let data = Data(key.utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "LicenseStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not save license key"]) 
        }
    }

    public func loadLicenseKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "LicenseStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not read license key"]) 
        }

        return key
    }

    public func removeLicenseKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
