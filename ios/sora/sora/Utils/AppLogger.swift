import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.guitaripod.sora"

    static let auth = Logger(subsystem: subsystem, category: "Authentication")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let video = Logger(subsystem: subsystem, category: "Video")
    static let purchase = Logger(subsystem: subsystem, category: "Purchase")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}
