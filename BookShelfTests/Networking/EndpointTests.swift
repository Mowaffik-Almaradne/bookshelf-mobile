import Foundation
import Testing
@testable import BookShelf

@Suite struct EndpointTests {
    private let base = URL(string: "https://openlibrary.org")

    @Test func searchURL_encodesSpacesAndKeepsQueryOrder() throws {
        let endpoint = Endpoint(
            path: "/search.json",
            queryItems: [
                URLQueryItem(name: "q", value: "harry potter"),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "20")
            ]
        )
        let request = try request(for: endpoint)
        let absolute = try #require(request.url?.absoluteString)
        #expect(absolute == "https://openlibrary.org/search.json?q=harry%20potter&page=1&limit=20")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.httpMethod == "GET")
    }

    @Test func arabicQuery_isPercentEncoded() throws {
        let endpoint = Endpoint(
            path: "/search.json",
            queryItems: [URLQueryItem(name: "q", value: "الرف")]
        )
        let request = try request(for: endpoint)
        let url = try #require(request.url)
        let absolute = url.absoluteString
        #expect(absolute.contains("q=%D8%A7%D9%84%D8%B1%D9%81"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first?.value == "الرف")
    }

    @Test func pathWithoutLeadingSlash_throwsInvalidURL() throws {
        let endpoint = Endpoint(path: "search.json")
        let baseURL = try #require(base)
        #expect(throws: HTTPError.invalidURL("search.json")) {
            try endpoint.urlRequest(baseURL: baseURL, timeout: 15)
        }
    }

    private func request(for endpoint: Endpoint) throws -> URLRequest {
        let baseURL = try #require(base)
        return try endpoint.urlRequest(baseURL: baseURL, timeout: 15)
    }
}
