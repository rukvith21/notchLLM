import Foundation
import Security

/// Resolves API keys from env → Keychain (notchLLM) → credentials.json.
/// Settings UI writes secrets to Keychain only (never into settings.json).
actor CredentialStore {
    static let shared = CredentialStore()
    static let keychainService = "notchLLM"

    enum Account: String, CaseIterable, Sendable {
        case gemini
        case openai
        case cursor
    }

    private let credentialsFileURL: URL

    init(credentialsFileURL: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("notchLLM", isDirectory: true)
        self.credentialsFileURL = credentialsFileURL ?? dir.appendingPathComponent("credentials.json")
    }

    func geminiAPIKey() -> String? {
        firstNonEmpty([
            ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
            ProcessInfo.processInfo.environment["GOOGLE_API_KEY"],
            keychainValue(account: .gemini),
            fileCredentials()?.geminiAPIKey
        ])
    }

    func openAIAPIKey() -> String? {
        firstNonEmpty([
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
            keychainValue(account: .openai),
            fileCredentials()?.openAIAPIKey
        ])
    }

    func cursorAPIKey() -> String? {
        firstNonEmpty([
            ProcessInfo.processInfo.environment["CURSOR_API_KEY"],
            keychainValue(account: .cursor),
            fileCredentials()?.cursorAPIKey
        ])
    }

    func hasKeychainValue(account: Account) -> Bool {
        keychainValue(account: account) != nil
    }

    /// Empty / whitespace `value` deletes the Keychain item.
    @discardableResult
    func setAPIKey(_ value: String?, account: Account) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        deleteKeychainValue(account: account)
        guard !trimmed.isEmpty else { return true }
        guard let data = trimmed.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func maskedKeyPreview(account: Account) -> String? {
        guard let key = keychainValue(account: account), key.count >= 4 else {
            return keychainValue(account: account).map { String(repeating: "•", count: max($0.count, 4)) }
        }
        let suffix = key.suffix(4)
        return String(repeating: "•", count: max(key.count - 4, 4)) + suffix
    }

    // MARK: - Private

    private func fileCredentials() -> CredentialsFile? {
        guard FileManager.default.fileExists(atPath: credentialsFileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: credentialsFileURL) else { return nil }
        return try? JSONDecoder().decode(CredentialsFile.self, from: data)
    }

    private func keychainValue(account: Account) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychainValue(account: Account) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: account.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
