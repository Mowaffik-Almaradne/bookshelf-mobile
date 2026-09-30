import Foundation

/// Read-only view of which works are on the shelf.
///
/// Search rows need a bookmark indicator without depending on SwiftData or the
/// full `ShelfStore` write API. Production injects `ShelfStore`; previews may
/// use `EmptySavedState`.
@MainActor
protocol SavedStateReading {
    /// Whether the work is currently saved. Cheap; called from list rows.
    func isSaved(_ key: WorkKey) -> Bool
}

/// Always-empty shelf for Search `#Preview` canvases that do not wire persistence.
@MainActor
final class EmptySavedState: SavedStateReading {
    func isSaved(_ key: WorkKey) -> Bool { false }
}
