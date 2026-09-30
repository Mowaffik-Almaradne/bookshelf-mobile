import Foundation
@testable import BookShelf

/// In-memory saved-key set for `isSaved` tests.
@MainActor
final class StubSavedState: SavedStateReading {
    var savedKeys: Set<WorkKey> = []

    func isSaved(_ key: WorkKey) -> Bool {
        savedKeys.contains(key)
    }

    func save(_ key: WorkKey) {
        savedKeys.insert(key)
    }
}
