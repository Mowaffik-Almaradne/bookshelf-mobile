import Foundation
@testable import BookShelf

extension Book {
    /// Builds a domain book for view-model tests. `id` is the work segment only.
    static func stub(
        id: String = "OL1W",
        title: String? = nil,
        authors: [String] = ["Author"],
        firstPublishYear: Int? = 2000,
        coverID: Int? = 1
    ) -> Book {
        guard let key = WorkKey(rawValue: "/works/\(id)") else {
            preconditionFailure("stub WorkKey must be a valid /works/ path")
        }
        return Book(
            key: key,
            title: title ?? "Book \(id)",
            authors: authors,
            firstPublishYear: firstPublishYear,
            coverID: coverID
        )
    }
}

extension SearchPage {
    /// One scripted page. `ids` become `/works/{id}` keys in order.
    static func stub(
        ids: [String],
        page: Int,
        pageSize: Int = 20,
        total: Int?
    ) -> SearchPage {
        SearchPage(
            books: ids.map { Book.stub(id: $0) },
            page: page,
            pageSize: pageSize,
            totalCount: total
        )
    }
}

extension BookDetails {
    /// Builds details for view-model and store tests.
    static func stub(
        id: String = "OL1W",
        title: String = "Stub Book",
        authors: [String] = ["Author"],
        description: String? = "A description",
        subjects: [String] = ["Fiction"],
        coverID: Int? = 1,
        firstPublishYear: Int? = 2000,
        firstPublishDate: String? = "2000"
    ) -> BookDetails {
        guard let key = WorkKey(rawValue: "/works/\(id)") else {
            preconditionFailure("stub WorkKey must be a valid /works/ path")
        }
        return BookDetails(
            key: key,
            title: title,
            authors: authors,
            description: description,
            subjects: subjects,
            coverID: coverID,
            firstPublishYear: firstPublishYear,
            firstPublishDate: firstPublishDate
        )
    }
}
