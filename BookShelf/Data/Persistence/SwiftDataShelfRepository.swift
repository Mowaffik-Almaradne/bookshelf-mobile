import Foundation
import SwiftData

/// SwiftData-backed `ShelfRepository`.
///
/// Uses `container.mainContext` because the shelf holds tens of rows, fetches
/// are sub-millisecond, and this avoids cross-actor `PersistentIdentifier`
/// handling. The protocol allows swapping in a `@ModelActor` later if volume grows.
@MainActor
final class SwiftDataShelfRepository: ShelfRepository {
    /// WHY retain the container: taking only `mainContext` does **not** keep the
    /// `ModelContainer` alive. When the container is released, the next
    /// `context.fetch` / `context.save` traps with `EXC_BREAKPOINT` — the save
    /// crash seen in the simulator. Unit tests hid this because they kept a
    /// local `container` binding for the whole test.
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
        // Explicit `save()` after each mutation keeps R4.2 deterministic.
        self.context.autosaveEnabled = false
    }

    func fetchAll() throws -> [ShelfBook] {
        let descriptor = FetchDescriptor<SavedBookEntity>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        let entities = try context.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    func fetch(workKey: WorkKey) throws -> ShelfBook? {
        try fetchEntity(workKey: workKey)?.toDomain()
    }

    func save(_ book: ShelfBook) throws {
        if let existing = try fetchEntity(workKey: book.details.key) {
            existing.apply(book)
        } else {
            context.insert(SavedBookEntity(from: book))
        }
        try context.save()
    }

    func remove(workKey: WorkKey) throws {
        guard let entity = try fetchEntity(workKey: workKey) else { return }
        context.delete(entity)
        try context.save()
    }

    func update(workKey: WorkKey, status: ReadingStatus) throws {
        guard let entity = try fetchEntity(workKey: workKey) else { return }
        entity.statusRaw = status.rawValue
        try context.save()
    }

    /// Finds the row for `workKey`, or `nil` when the book is not on the shelf.
    ///
    /// Matching happens in memory rather than through `#Predicate` because the
    /// shelf holds tens of rows, so the fetch is sub-millisecond either way and
    /// this keeps the upsert path free of predicate-expression translation.
    private func fetchEntity(workKey: WorkKey) throws -> SavedBookEntity? {
        let key = workKey.rawValue
        let entities = try context.fetch(FetchDescriptor<SavedBookEntity>())
        return entities.first { $0.workKey == key }
    }
}
