import Foundation
import SwiftData

/// SwiftData row for one saved book. Never escapes the Data layer — Views and
/// ViewModels see only `ShelfBook`.
///
/// `nonisolated` is required, not cosmetic: the target builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it this `@Model` would
/// be main-actor isolated while SwiftData reads and materialises rows on its own
/// coordinator queues — an isolation mismatch the runtime can trap on mid-fetch.
@Model
nonisolated final class SavedBookEntity {
    /// Stable work path (`/works/OL…`). Upsert is enforced in
    /// `SwiftDataShelfRepository.save` (fetch → apply / insert) — do **not** mark
    /// this `@Attribute(.unique)`. Reading a non-optional unique property after
    /// an explicit `context.save()` is a known SwiftData crash
    /// (`EXC_BREAKPOINT`) when the same identity-mapped instance is fetched again.
    var workKey: String
    var title: String
    var authors: [String]
    /// Named to avoid clashing with `CustomStringConvertible.description`.
    var bookDescription: String?
    var subjects: [String]
    var coverID: Int?
    var firstPublishYear: Int?
    var firstPublishDate: String?
    var savedAt: Date
    /// Raw `ReadingStatus` token: adding an enum case later needs no migration;
    /// unknown values fall back to `.wantToRead` in `toDomain()`.
    var statusRaw: String
    /// Cover blobs stay off the main SQLite pages so list fetches stay cheap.
    @Attribute(.externalStorage) var coverData: Data?

    init(from book: ShelfBook) {
        self.workKey = book.details.key.rawValue
        self.title = book.details.title
        self.authors = book.details.authors
        self.bookDescription = book.details.description
        self.subjects = book.details.subjects
        self.coverID = book.details.coverID
        self.firstPublishYear = book.details.firstPublishYear
        self.firstPublishDate = book.details.firstPublishDate
        self.savedAt = book.savedAt
        self.statusRaw = book.status.rawValue
        self.coverData = book.coverData
    }

    /// Test / repair entry point for rows that may not round-trip from domain.
    init(
        workKey: String,
        title: String,
        authors: [String],
        bookDescription: String?,
        subjects: [String],
        coverID: Int?,
        firstPublishYear: Int?,
        firstPublishDate: String?,
        savedAt: Date,
        statusRaw: String,
        coverData: Data?
    ) {
        self.workKey = workKey
        self.title = title
        self.authors = authors
        self.bookDescription = bookDescription
        self.subjects = subjects
        self.coverID = coverID
        self.firstPublishYear = firstPublishYear
        self.firstPublishDate = firstPublishDate
        self.savedAt = savedAt
        self.statusRaw = statusRaw
        self.coverData = coverData
    }

    /// Applies domain fields onto an existing row during upsert.
    func apply(_ book: ShelfBook) {
        title = book.details.title
        authors = book.details.authors
        bookDescription = book.details.description
        subjects = book.details.subjects
        coverID = book.details.coverID
        firstPublishYear = book.details.firstPublishYear
        firstPublishDate = book.details.firstPublishDate
        savedAt = book.savedAt
        statusRaw = book.status.rawValue
        coverData = book.coverData
    }

    /// `nil` when `workKey` is not a valid `/works/…` path so a corrupt row is
    /// skipped instead of crashing the shelf list.
    func toDomain() -> ShelfBook? {
        guard let key = WorkKey(rawValue: workKey) else { return nil }
        let status = ReadingStatus(rawValue: statusRaw) ?? .wantToRead
        let details = BookDetails(
            key: key,
            title: title,
            authors: authors,
            description: bookDescription,
            subjects: subjects,
            coverID: coverID,
            firstPublishYear: firstPublishYear,
            firstPublishDate: firstPublishDate
        )
        return ShelfBook(
            details: details,
            savedAt: savedAt,
            status: status,
            coverData: coverData
        )
    }
}
