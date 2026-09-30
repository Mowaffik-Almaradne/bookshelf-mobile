import Foundation

/// Persistence boundary for the shelf. `ShelfStore` is the only app-layer
/// writer; this protocol exists so ViewModels stay free of SwiftData and tests
/// can swap an in-memory fake without spinning up a `ModelContainer`.
@MainActor
protocol ShelfRepository {
    /// All saved books, newest `savedAt` first. Corrupt rows are skipped, not thrown.
    func fetchAll() throws -> [ShelfBook]

    /// `nil` when the key is absent or the stored row cannot map to domain.
    func fetch(workKey: WorkKey) throws -> ShelfBook?

    /// Insert or replace by `workKey`. Unique constraint makes a second save idempotent.
    func save(_ book: ShelfBook) throws

    /// No-op when the key is not present — callers should not treat "already gone" as failure.
    func remove(workKey: WorkKey) throws

    /// Updates reading status only. No-op when the key is missing.
    func update(workKey: WorkKey, status: ReadingStatus) throws
}
