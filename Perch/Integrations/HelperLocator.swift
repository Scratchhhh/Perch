import Foundation

/// Resolves the bundled `perch-helper` so integrations can write its absolute path into
/// third-party config files. Never hard-coded.
enum HelperLocator {
    static var helperURL: URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/perch-helper", isDirectory: false)
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static var isAvailable: Bool {
        helperURL != nil
    }

    /// A shell-ready invocation, e.g. `"/Applications/Perch.app/Contents/Helpers/perch-helper" hook`.
    static func shellCommand(subcommand: String) -> String? {
        guard let path = helperURL?.path else { return nil }
        return "\"\(path)\" \(subcommand)"
    }
}
