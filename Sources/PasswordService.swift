import Foundation
import CryptoKit
import Security

/// Master password stored as salted SHA-256 in Keychain. Recovery phrase also hashed.
final class PasswordService {
    static let shared = PasswordService()

    private let service = AppConfig.bundleID
    private let passwordAccount = "master-password-hash"
    private let saltAccount = "master-password-salt"
    private let recoveryAccount = "recovery-phrase-hash"

    private init() {}

    var hasPassword: Bool {
        loadKey(passwordAccount) != nil && loadKey(saltAccount) != nil
    }

    func setPassword(_ password: String, recoveryPhrase: String) throws {
        guard password.count >= 6 else {
            throw PasswordError.tooShort
        }
        let salt = randomBytes(16)
        let hash = hashPassword(password, salt: salt)
        let recoveryHash = sha256(recoveryPhrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        try saveKey(passwordAccount, data: hash)
        try saveKey(saltAccount, data: salt)
        try saveKey(recoveryAccount, data: recoveryHash)
    }

    func verifyPassword(_ password: String) -> Bool {
        guard let salt = loadKey(saltAccount), let expected = loadKey(passwordAccount) else {
            return false
        }
        return hashPassword(password, salt: salt) == expected
    }

    func verifyRecovery(_ phrase: String) -> Bool {
        guard let expected = loadKey(recoveryAccount) else { return false }
        let got = sha256(phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        return got == expected
    }

    /// Reset password using recovery phrase.
    func resetPassword(recoveryPhrase: String, newPassword: String) throws {
        guard verifyRecovery(recoveryPhrase) else { throw PasswordError.badRecovery }
        try setPassword(newPassword, recoveryPhrase: recoveryPhrase)
    }

    static func generateRecoveryPhrase() -> String {
        // 6 short words-ish tokens — easy to write down
        let words = [
            "anchor", "brave", "cedar", "delta", "ember", "flint", "grove", "haven",
            "ivory", "jade", "kite", "lunar", "moss", "north", "onyx", "pine",
            "quartz", "ridge", "stone", "tide", "umbra", "vale", "willow", "zephyr",
            "amber", "birch", "coral", "dusk", "echo", "frost", "gale", "harbor"
        ]
        return (0..<6).map { _ in words.randomElement()! }.joined(separator: "-")
    }

    // MARK: - Crypto

    private func hashPassword(_ password: String, salt: Data) -> Data {
        var combined = salt
        combined.append(Data(password.utf8))
        // Stretch a bit
        var digest = SHA256.hash(data: combined)
        for _ in 0..<10_000 {
            digest = SHA256.hash(data: Data(digest))
        }
        return Data(digest)
    }

    private func sha256(_ string: String) -> Data {
        Data(SHA256.hash(data: Data(string.utf8)))
    }

    private func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    // MARK: - Keychain

    private func saveKey(_ account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw PasswordError.keychain(status) }
    }

    private func loadKey(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
}

enum PasswordError: LocalizedError {
    case tooShort
    case badRecovery
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .tooShort: return "Password must be at least 6 characters."
        case .badRecovery: return "Recovery phrase does not match."
        case .keychain(let s): return "Keychain error: \(s)"
        }
    }
}
