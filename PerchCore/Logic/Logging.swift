import Foundation
import os

public enum PerchLog {
    public static let subsystem = "com.perch.app"

    public static let bus = Logger(subsystem: subsystem, category: "eventbus")
    public static let listener = Logger(subsystem: subsystem, category: "listener")
    public static let notifier = Logger(subsystem: subsystem, category: "notifier")
    public static let helper = Logger(subsystem: subsystem, category: "helper")
    public static let integration = Logger(subsystem: subsystem, category: "integration")
    public static let filewatch = Logger(subsystem: subsystem, category: "filewatch")
    public static let mcp = Logger(subsystem: subsystem, category: "mcp")
    public static let app = Logger(subsystem: subsystem, category: "app")
}
