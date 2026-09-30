import Foundation

extension SearchPage {
    /// The same window as a generic `Page`, so `Paginator` never mentions `Book`
    /// and the catalog never mentions pagination. Field names differ (`books`
    /// vs `items`); the values do not.
    var asPage: Page<Book> {
        Page(
            items: books,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount
        )
    }
}
