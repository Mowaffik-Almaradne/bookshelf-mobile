import Foundation
@testable import BookShelf

/// Working fake `ShelfRepository` for store tests that must not involve SwiftData.
@MainActor
final class InMemoryShelfRepository: ShelfRepository {
    private var storage: [WorkKey: ShelfBook] = [:]

    func fetchAll() throws -> [ShelfBook] {
        storage.values.sorted { $0.savedAt > $1.savedAt }
    }

    func fetch(workKey: WorkKey) throws -> ShelfBook? {
        storage[workKey]
    }

    func save(_ book: ShelfBook) throws {
        storage[book.id] = book
    }

    func remove(workKey: WorkKey) throws {
        storage[workKey] = nil
    }

    func update(workKey: WorkKey, status: ReadingStatus) throws {
        guard var book = storage[workKey] else { return }
        book.status = status
        storage[workKey] = book
    }
}
