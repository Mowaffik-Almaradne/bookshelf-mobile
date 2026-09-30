import Foundation

/// A request built only from `URLComponents` and `URLQueryItem`. User text goes
/// in query items so it is percent-encoded, never interpolated into a URL string.
nonisolated struct Endpoint: Sendable, Equatable {
    /// Absolute path on the host, including the leading slash (`/search.json`).
    var path: String
    /// Query items in the order they should appear. Empty omits the query.
    var queryItems: [URLQueryItem]
    /// HTTP method. Open Library calls are GET.
    var method: String

    init(path: String, queryItems: [URLQueryItem] = [], method: String = "GET") {
        self.path = path
        self.queryItems = queryItems
        self.method = method
    }

    /// Composes `baseURL` + path + query. Throws `.invalidURL` when the path
    /// cannot form a URL (for example it does not start with `/`).
    func urlRequest(baseURL: URL, timeout: TimeInterval) throws(HTTPError) -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw .invalidURL(path)
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw .invalidURL(path)
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
