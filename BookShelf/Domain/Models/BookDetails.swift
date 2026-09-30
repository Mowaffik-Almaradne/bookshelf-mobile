import Foundation

/// The work document the details screen renders. Author names may still be
/// the search-row seeds when the author requests fail; `firstPublishYear`
/// comes from search, not from the free-form work date.
nonisolated struct BookDetails: Hashable, Sendable {
    let key: WorkKey
    let title: String
    let authors: [String]
    let description: String?
    let subjects: [String]
    let coverID: Int?
    let firstPublishYear: Int?
    /// Displayed as returned. Open Library does not give this a stable format.
    let firstPublishDate: String?

    init(
        key: WorkKey,
        title: String,
        authors: [String],
        description: String?,
        subjects: [String],
        coverID: Int?,
        firstPublishYear: Int?,
        firstPublishDate: String?
    ) {
        self.key = key
        self.title = title
        self.authors = authors
        self.description = description
        self.subjects = subjects
        self.coverID = coverID
        self.firstPublishYear = firstPublishYear
        self.firstPublishDate = firstPublishDate
    }

    /// Builds a minimal details record from a search/shelf row seed.
    ///
    /// WHY: a failed details fetch must not block saving — the user already
    /// found the book; description and subjects stay empty until a later refresh.
    init(seed book: Book) {
        self.key = book.key
        self.title = book.title
        self.authors = book.authors
        self.description = nil
        self.subjects = []
        self.coverID = book.coverID
        self.firstPublishYear = book.firstPublishYear
        self.firstPublishDate = nil
    }
}
