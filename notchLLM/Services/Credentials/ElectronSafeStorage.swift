import Foundation
import Security
import CommonCrypto

/// Decrypts Electron `safeStorage` payloads written as `cursor-safe-storage:v1:<b64(v10||ciphertext)>`.
/// Uses the Chromium OSCrypt scheme: Keychain password → PBKDF2-SHA1 → AES-128-CBC (IV = 16 spaces).
enum ElectronSafeStorage {
    static func decryptCursorAccessToken(_ ciphertext: String) -> String? {
        decrypt(
            ciphertext,
            keychainService: "Cursor Safe Storage",
            keychainAccounts: ["Cursor", "Cursor Key"]
        )
    }

    static func decrypt(
        _ ciphertext: String,
        keychainService: String,
        keychainAccounts: [String]
    ) -> String? {
        guard let password = keychainPassword(service: keychainService, accounts: keychainAccounts) else {
            return nil
        }
        return decrypt(ciphertext, password: password)
    }

    static func decrypt(_ ciphertext: String, password: String) -> String? {
        let trimmed = ciphertext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("cursor-safe-storage:v1:") else {
            // Already plaintext JWT / bearer token.
            return trimmed.isEmpty ? nil : trimmed
        }
        let b64 = String(trimmed.dropFirst("cursor-safe-storage:v1:".count))
        guard let data = Data(base64Encoded: b64, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        // Chromium prefixes ciphertext with ASCII "v10".
        let body: Data
        if data.starts(with: Data("v10".utf8)) {
            body = data.dropFirst(3)
        } else {
            body = data
        }
        guard let key = pbkdf2SHA1(password: password, salt: Data("saltysalt".utf8), iterations: 1003, keyLength: 16) else {
            return nil
        }
        let iv = Data(repeating: UInt8(ascii: " "), count: 16)
        guard let plain = aes128CBCDecrypt(data: Data(body), key: key, iv: iv) else {
            return nil
        }
        let text = String(data: plain, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty == false) ? text : nil
    }

    // MARK: - Keychain / crypto

    private static func keychainPassword(service: String, accounts: [String]) -> String? {
        for account in accounts {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let data = item as? Data,
                  let password = String(data: data, encoding: .utf8),
                  !password.isEmpty
            else { continue }
            return password
        }
        return nil
    }

    private static func pbkdf2SHA1(password: String, salt: Data, iterations: UInt32, keyLength: Int) -> Data? {
        guard let passwordData = password.data(using: .utf8) else { return nil }
        var derived = Data(count: keyLength)
        let result = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        iterations,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }
        return result == kCCSuccess ? derived : nil
    }

    private static func aes128CBCDecrypt(data: Data, key: Data, iv: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let outCapacity = data.count + kCCBlockSizeAES128
        var outBytes = [UInt8](repeating: 0, count: outCapacity)
        var outLength = 0
        let status: CCCryptorStatus = data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, data.count,
                        &outBytes, outCapacity,
                        &outLength
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data(outBytes.prefix(outLength))
    }
}
