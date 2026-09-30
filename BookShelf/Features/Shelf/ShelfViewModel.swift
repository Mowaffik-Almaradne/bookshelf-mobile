import Foundation
import Observation

/// Shelf screen state over `ShelfStore`: list, delete, reading-status filter (O1).
///
/// `@MainActor`: reads `store.books` for the list; stays with the store’s actor.
@MainActor
@Observable
final class ShelfViewModel {
    private let store: ShelfStore

    /// `nil` means show every status. Changing the filter never touches persistence.
    var statusFilter: ReadingStatus?

    init(store: ShelfStore) {
        self.store = store
    }

    /// Books visible under the current filter, newest-first (store order).
    var books: [ShelfBook] {
        guard let statusFilter else { return store.books }
        return store.books.filter { $0.status == statusFilter }
    }

    /// True when the shelf has any persisted books (ignores the active filter).
    var hasSavedBooks: Bool { !store.books.isEmpty }

    func remove(_ key: WorkKey) {
        store.remove(key)
    }

    func setStatus(_ status: ReadingStatus, for key: WorkKey) {
        store.setStatus(status, for: key)
    }
}
