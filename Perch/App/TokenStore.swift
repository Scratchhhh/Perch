import Foundation
import Security
import PerchCore

/// Loads (or lazily creates) the shared secret the helper uses to authenticate with the listener.
/// Stored next to the port file with owner-only permissions.
enum TokenStore {
    static func loadOrCreate() -> String {
        if let existing = read(), !existing.isEmpty {
            return existing
        }
        let token = generate()
        persist(token)
        return token
    }

    private static func read() -> String? {
        guard let data = try? Data(contentsOf: PerchPaths.tokenFile),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func persist(_ token: String) {
        do {
            try PerchPaths.ensureSupportDirectory()
            try Data(token.utf8).write(to: PerchPaths.tokenFile, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: PerchPaths.tokenFile.path
            )
        } catch {
            PerchLog.app.error("failed to persist token: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return UUID().uuidString + UUID().uuidString
        }
        return Data(bytes).base64EncodedString()
    }
}
