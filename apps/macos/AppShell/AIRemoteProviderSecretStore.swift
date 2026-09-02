import Foundation
import Security

final class AIRemoteProviderSecretStore {
    private let service = "com.wisprlocal.ai.remote-provider"
    // Keychain reads can trigger a macOS authorization dialog when an item was
    // created by a different app signature. Cache the result for this app
    // lifetime so a settings redraw or processing-stack rebuild never asks
    // for the same item repeatedly.
    private var cachedAPIKeys: [String: String?] = [:]
    private var unavailableAPIKeys: Set<String> = []

    func saveAPIKey(_ key: String, providerID: String) throws {
        let data = Data(key.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "AIRemoteProviderSecretStore",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Could not save remote AI API key."]
            )
        }
        cachedAPIKeys[providerID] = key
        unavailableAPIKeys.remove(providerID)
    }

    func loadAPIKey(providerID: String) -> String? {
        if let cachedValue = cachedAPIKeys[providerID] {
            return cachedValue
        }
        if unavailableAPIKeys.contains(providerID) {
            return nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            unavailableAPIKeys.insert(providerID)
            return nil
        }

        let key = String(data: data, encoding: .utf8)
        cachedAPIKeys[providerID] = key
        unavailableAPIKeys.remove(providerID)
        return key
    }

    func removeAPIKey(providerID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID
        ]
        SecItemDelete(query as CFDictionary)
        cachedAPIKeys[providerID] = nil
        unavailableAPIKeys.remove(providerID)
    }
}
