import Foundation

/// Open Library paths. User text is a query item, so `URLComponents` encodes it
/// and it is never interpolated into the URL.
nonisolated enum OpenLibraryEndpoints {
    /// Field list from the search contract. Extra fields inflate every keystroke.
    static let searchFields = "key,title,author_name,first_publish_year,cover_i,edition_count"

    static func search(query: String, page: Int, limit: Int) -> Endpoint {
        Endpoint(
            path: "/search.json",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "fields", value: searchFields)
            ]
        )
    }

    /// Work document. The path comes from a validated `WorkKey`.
    static func work(key: WorkKey) -> Endpoint {
        Endpoint(path: key.detailsPath)
    }

    /// Author document. `key` is an API path such as `/authors/OL34184A`.
    static func author(key: String) -> Endpoint {
        Endpoint(path: key + ".json")
    }
}
