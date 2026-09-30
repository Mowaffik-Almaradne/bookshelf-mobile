import Foundation
import Testing
@testable import BookShelf

@Suite struct SearchResponseDecodingTests {
    @Test func page1_decodes20Books_mapsOptionalFields() async throws {
        let page = try await decodedPage("search_page1")

        #expect(page.books.count == 20)
        #expect(page.totalCount == 2067)

        let history = try #require(page.books.first { $0.key.rawValue == "/works/OL1625497W" })
        #expect(history.title == "History, its theory and method")
        #expect(history.coverID == nil)
        #expect(history.firstPublishYear == 1978)
        #expect(history.authors == ["B. Sheikh Ali"])

        let anonymous = try #require(page.books.first { $0.key.rawValue == "/works/OL16478631W" })
        #expect(anonymous.authors.isEmpty)
        #expect(anonymous.coverID == 8068862)
        #expect(anonymous.firstPublishYear == 1987)

        let undated = try #require(page.books.first { $0.key.rawValue == "/works/OL20849874W" })
        #expect(undated.firstPublishYear == nil)
        #expect(undated.coverID == 10161252)
        #expect(undated.authors == ["Mtg"])

        let hobbit = try #require(page.books.first { $0.key.rawValue == "/works/OL27482W" })
        #expect(hobbit.title == "The Hobbit")
        #expect(hobbit.coverID == 14627509)
        #expect(hobbit.firstPublishYear == 1937)
        #expect(hobbit.authors == ["J.R.R. Tolkien"])
    }

    @Test func docWithoutKey_isDroppedNotCrash() async throws {
        let page = try await decodedPage("search_doc_missing_key")

        #expect(page.books.count == 1)
        #expect(page.books.first?.key.rawValue == "/works/OL27513W")
        #expect(page.books.first?.title == "The Fellowship of the Ring")
    }

    @Test func emptyDocs_yieldsEmptyPage() async throws {
        let page = try await decodedPage("search_empty")

        #expect(page.books.isEmpty)
        #expect(page.totalCount == 0)
    }

    @Test func numFoundMissing_totalCountIsNil() async throws {
        let original = try Fixtures.data("search_empty")
        let object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var stripped = object
        stripped.removeValue(forKey: "numFound")
        let data = try JSONSerialization.data(withJSONObject: stripped)

        let response = try await JSONDecoding.decode(SearchResponseDTO.self, from: data)
        let page = SearchPage(
            books: response.docs.compactMap { Book(doc: $0) },
            page: 1,
            pageSize: 20,
            totalCount: response.numFound
        )

        #expect(page.totalCount == nil)
        #expect(page.books.isEmpty)
    }

    private func decodedPage(_ name: String) async throws -> SearchPage {
        let response = try await JSONDecoding.decode(SearchResponseDTO.self, from: try Fixtures.data(name))
        return SearchPage(
            books: response.docs.compactMap { Book(doc: $0) },
            page: 1,
            pageSize: 20,
            totalCount: response.numFound
        )
    }
}
