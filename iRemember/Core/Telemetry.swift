import Foundation
import OSLog

enum AppTelemetry {
    static let subsystem = Bundle.main.bundleIdentifier ?? "iRemember"
    static let archive = Logger(subsystem: subsystem, category: "Archive")
    static let session = Logger(subsystem: subsystem, category: "Session")
    static let search = Logger(subsystem: subsystem, category: "Search")
    static let timeline = Logger(subsystem: subsystem, category: "Timeline")
    static let merge = Logger(subsystem: subsystem, category: "Merge")
}
