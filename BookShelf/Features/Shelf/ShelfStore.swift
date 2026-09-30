import Foundation
import Observation
import os

/// App-wide source of truth for saved books (R4.4).
///
/// `@MainActor`: SwiftData `mainContext` and `@Observable` shelf state are
/// main-actor; one actor keeps Search/Details/Shelf in sync without hopping.
///
/// A store beats `@Query` in views because: (1) views stay free of SwiftData,
/// (2) the store is testable through `ShelfRepository`, and (3) `isSaved` is O(1)
/// via `savedKeys` for every visible search row. This is the only writer to
/// persistence in the app — no notification or Combine plumbing.
@MainActor
@Observable
final class ShelfStore: SavedStateReading {
    private(set) var books: [ShelfBook] = []
    private(set) var savedKeys: Set<WorkKey> = []
    private(set) var lastError: AppError?

    private let repository: any ShelfRepository
    private let images: any ImageLoading

    init(repository: any ShelfRepository, images: any ImageLoading) {
        self.repository = repository
        self.images = images
        reload()
    }

    /// O(1) lookup — search rows call this for every visible cell.
    func isSaved(_ key: WorkKey) -> Bool {
        savedKeys.contains(key)
    }

    /// Two-step save: persist immediately without the cover so the UI responds
    /// and the save works offline; then best-effort fetch cover bytes (usually
    /// already in URLCache from the row) and persist again. Failures set
    /// `lastError` and are logged — never thrown at the UI.
    func save(_ details: BookDetails) async {
        var book = ShelfBook(
            details: details,
            savedAt: .now,
            status: .wantToRead,
            coverData: nil
        )
        persist(book)

        guard let coverID = details.coverID,
              let url = CoverURL.url(coverID: coverID, size: .medium)
        else { return }

        // Missing cover is acceptable: the book is already on the shelf without bytes.
        guard let data = try? await images.imageData(for: url) else { return }
        book.coverData = data
        persist(book)
    }

    func remove(_ key: WorkKey) {
        do {
            try repository.remove(workKey: key)
            reload()
        } catch {
            lastError = .persistence
            Log.persistence.error("remove failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setStatus(_ status: ReadingStatus, for key: WorkKey) {
        do {
            try repository.update(workKey: key, status: status)
            reload()
        } catch {
            lastError = .persistence
            Log.persistence.error("status update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saved(_ key: WorkKey) -> ShelfBook? {
        books.first { $0.id == key }
    }

    /// Replaces details on an already-saved book after a successful online refresh,
    /// keeping `savedAt`, status, and offline cover bytes.
    func refreshDetails(_ details: BookDetails) {
        guard let existing = saved(details.key) else { return }
        let updated = ShelfBook(
            details: details,
            savedAt: existing.savedAt,
            status: existing.status,
            coverData: existing.coverData
        )
        persist(updated)
    }

    private func persist(_ book: ShelfBook) {
        do {
            try repository.save(book)
            reload()
        } catch {
            lastError = .persistence
            Log.persistence.error("save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func reload() {
        do {
            books = try repository.fetchAll()
            savedKeys = Set(books.map(\.id))
            lastError = nil
        } catch {
            lastError = .persistence
            Log.persistence.error("fetchAll failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clears a surfaced persistence alert after the user dismisses it.
    func clearLastError() {
        lastError = nil
    }
}
