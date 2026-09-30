import Foundation

/// Reading progress stored on a saved book. The raw value is the persisted
/// token, so the case names are the on-disk contract.
nonisolated enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case wantToRead
    case reading
    case finished

    /// User-facing label (String Catalog). Keep short for menus and filters.
    var title: String {
        switch self {
        case .wantToRead: String(localized: "Want to read")
        case .reading: String(localized: "Reading")
        case .finished: String(localized: "Finished")
        }
    }
}
