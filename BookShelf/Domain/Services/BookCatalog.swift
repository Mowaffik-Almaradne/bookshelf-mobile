import Foundation

/// One page of search results.
///
/// `totalCount` is Open Library's `numFound`. The index updates between pages
/// and the field is sometimes missing, so it is not a promise the client will
/// see that many books.
nonisolated struct SearchPage: Sendable, Equatable {
    let books: [Book]
    let page: Int
    let pageSize: Int
    let totalCount: Int?
}

/// Remote catalog of works.
///
/// View models depend on this protocol, so tests script pages without JSON
/// and the data layer can change transport without touching the screens.
nonisolated protocol BookCatalog: Sendable {
    /// `page` is 1-based. An empty `books` array is a successful search with
    /// no matches, not an error.
    func search(query: String, page: Int) async throws -> SearchPage

    /// Loads one work. `seedAuthors` are the names already known from the
    /// search row; they remain when author requests fail.
    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails
}
