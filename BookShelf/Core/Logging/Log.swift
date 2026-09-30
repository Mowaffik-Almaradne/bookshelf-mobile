import Foundation
import os

/// Unified log categories. The subsystem is the app bundle id, with a fixed
/// fallback so logging still works when previews have no bundle identifier.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.efendi.bookshelf"

    /// HTTP requests and responses.
    static let network = Logger(subsystem: subsystem, category: "network")
    /// JSON decoding failures.
    static let decoding = Logger(subsystem: subsystem, category: "decoding")
    /// Shelf reads and writes.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    /// Cover downloads and the image cache.
    static let images = Logger(subsystem: subsystem, category: "images")
    /// User-visible state changes worth tracing.
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
