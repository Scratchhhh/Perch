import Foundation

/// Atomic config writes that can re-assert restrictive permissions afterwards (atomic replace
/// otherwise resets them to the umask default, which would loosen secret-bearing files).
enum ConfigWriter {
    static func write(_ data: Data, to url: URL, posixPermissions: Int? = nil) throws {
        try data.write(to: url, options: .atomic)
        if let posixPermissions {
            try? FileManager.default.setAttributes(
                [.posixPermissions: posixPermissions],
                ofItemAtPath: url.path
            )
        }
    }
}
