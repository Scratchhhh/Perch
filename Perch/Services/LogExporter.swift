import Foundation
import OSLog
import PerchCore

struct LogLine: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let level: String
    let message: String

    var text: String {
        "\(date.formatted(date: .omitted, time: .standard)) [\(category)] \(level): \(message)"
    }

    init?(_ entry: OSLogEntry) {
        guard let log = entry as? OSLogEntryLog else { return nil }
        date = entry.date
        category = log.category
        message = log.composedMessage
        switch log.level {
        case .undefined: level = "log"
        case .debug: level = "debug"
        case .info: level = "info"
        case .notice: level = "notice"
        case .error: level = "error"
        case .fault: level = "fault"
        @unknown default: level = "log"
        }
    }
}

/// Reads Perch's own log entries from this process for the debug screen and export. Scoped to the
/// current process, so it needs no special entitlement and never sees other apps' logs.
enum LogExporter {
    static func recentEntries(within interval: TimeInterval = 3600) -> [LogLine] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return [] }
        let position = store.position(date: Date().addingTimeInterval(-interval))
        let predicate = NSPredicate(format: "subsystem == %@", PerchLog.subsystem)
        guard let entries = try? store.getEntries(at: position, matching: predicate) else { return [] }
        return entries.compactMap(LogLine.init)
    }

    static func formatted(_ lines: [LogLine]) -> String {
        lines.map(\.text).joined(separator: "\n")
    }
}
