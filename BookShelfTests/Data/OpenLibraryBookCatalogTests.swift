import Foundation
import Testing
@testable import BookShelf

@Suite struct OpenLibraryBookCatalogTests {
    @Test func search_mapsPageAndPageSize() async throws {
        let http = MockHTTPClient()
        http.enqueue(data: try Fixtures.data("search_page1"), whenPathContains: "/search.json")
        let catalog = OpenLibraryBookCatalog(http: http)

        let page = try await catalog.search(query: "tolkien", page: 2)

        #expect(page.books.count == 20)
        #expect(page.page == 2)
        #expect(page.pageSize == 20)
        #expect(page.totalCount == 2067)
        let sent = try #require(http.sentEndpoints.first)
        #expect(sent.path == "/search.json")
        #expect(sent.queryItems == [
            URLQueryItem(name: "q", value: "tolkien"),
            URLQueryItem(name: "page", value: "2"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "fields", value: OpenLibraryEndpoints.searchFields)
        ])
    }

    @Test func http500_surfacesAsServer() async {
        let http = MockHTTPClient()
        http.enqueue(data: Data("nope".utf8), status: 500, whenPathContains: "/search.json")
        let catalog = OpenLibraryBookCatalog(http: http)

        await #expect(throws: AppError.server) {
            try await catalog.search(query: "tolkien", page: 1)
        }
    }

    @Test func redirect_isFollowedExactlyOnce() async throws {
        let http = MockHTTPClient()
        http.enqueue(data: try Fixtures.data("work_redirect"), whenPathContains: "/works/OL45883W")
        http.enqueue(data: try Fixtures.data("work_minimal"), whenPathContains: "/works/OL45804W")
        let catalog = OpenLibraryBookCatalog(http: http)
        let key = try #require(WorkKey(rawValue: "/works/OL45883W"))

        let details = try await catalog.details(workKey: key, seedAuthors: ["Seed"])

        #expect(http.sentEndpoints.map(\.path) == [
            "/works/OL45883W.json",
            "/works/OL45804W.json"
        ])
        #expect(details.key == key)
        #expect(details.title == "Fantastic Mr Fox")
        #expect(details.authors == ["Seed"])
    }

    @Test func authorNames_areResolvedAndMerged() async throws {
        let http = MockHTTPClient()
        http.enqueue(data: try Fixtures.data("work_description_string"), whenPathContains: "/works/OL45804W")
        http.enqueue(data: try Fixtures.data("author"), whenPathContains: "/authors/OL34184A")
        let catalog = OpenLibraryBookCatalog(http: http)
        let key = try #require(WorkKey(rawValue: "/works/OL45804W"))

        let details = try await catalog.details(workKey: key, seedAuthors: ["Seed Author"])

        #expect(details.authors == ["Roald Dahl"])
        #expect(details.title == "Fantastic Mr Fox")
        #expect(http.sentEndpoints.map(\.path) == [
            "/works/OL45804W.json",
            "/authors/OL34184A.json"
        ])
    }

    @Test func authorFailure_keepsSeedNames() async throws {
        let http = MockHTTPClient()
        http.enqueue(data: try Fixtures.data("work_description_string"), whenPathContains: "/works/OL45804W")
        http.enqueue(error: .badStatus(500), whenPathContains: "/authors/OL34184A")
        let catalog = OpenLibraryBookCatalog(http: http)
        let key = try #require(WorkKey(rawValue: "/works/OL45804W"))

        let details = try await catalog.details(workKey: key, seedAuthors: ["Seed Author"])

        #expect(details.authors == ["Seed Author"])
        #expect(details.title == "Fantastic Mr Fox")
        #expect(details.description != nil)
    }
}
