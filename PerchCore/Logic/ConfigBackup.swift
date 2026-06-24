import Foundation

/// Makes a timestamped copy of a config file before Perch edits it. Returns the backup location,
/// or nil when there was nothing to back up yet.
public enum ConfigBackup {
    @discardableResult
    public static func backup(_ url: URL) throws -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())

        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).perch-backup-\(stamp)")

        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }
        try FileManager.default.copyItem(at: url, to: backupURL)
        return backupURL
    }
}
