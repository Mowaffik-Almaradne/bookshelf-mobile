import Foundation

/// A book saved on the shelf. `coverData` is the bytes shown when the device
/// is offline; the remote cover id alone is not enough after the cache is cold.
nonisolated struct ShelfBook: Identifiable, Hashable, Sendable {
    var id: WorkKey { details.key }

    let details: BookDetails
    let savedAt: Date
    var status: ReadingStatus
    /// Mutable so a two-step save can attach cover bytes after the instant persist.
    var coverData: Data?

    init(
        details: BookDetails,
        savedAt: Date,
        status: ReadingStatus,
        coverData: Data?
    ) {
        self.details = details
        self.savedAt = savedAt
        self.status = status
        self.coverData = coverData
    }

    /// Summary used when pushing the shared `Book` details destination from a shelf row.
    var asBook: Book {
        Book(
            key: details.key,
            title: details.title,
            authors: details.authors,
            firstPublishYear: details.firstPublishYear,
            coverID: details.coverID
        )
    }
}
