import Foundation

/// A search-row summary. The details screen opens by `key`; fields the search
/// index omits stay optional rather than blocking the row.
nonisolated struct Book: Identifiable, Hashable, Sendable {
    var id: WorkKey { key }

    let key: WorkKey
    let title: String
    let authors: [String]
    let firstPublishYear: Int?
    /// Open Library cover id. Absent, zero, and negative ids have no image.
    let coverID: Int?

    /// Used when a search document omits `title`. Domain values stay
    /// non-optional so a row always has text.
    static let missingTitle = "Untitled"

    init(
        key: WorkKey,
        title: String,
        authors: [String],
        firstPublishYear: Int?,
        coverID: Int?
    ) {
        self.key = key
        self.title = title
        self.authors = authors
        self.firstPublishYear = firstPublishYear
        self.coverID = coverID
    }
}
