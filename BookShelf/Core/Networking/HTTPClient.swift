import Foundation

/// Byte transport. Tests substitute a stub session so decoding tests never
/// open a socket. Typed throws keep `HTTPError` as the only failure.
nonisolated protocol HTTPClient: Sendable {
    /// Performs the request. `URLError.cancelled` is returned as
    /// `.transport(.cancelled)` so upper layers can ignore it.
    func send(_ endpoint: Endpoint) async throws(HTTPError) -> (Data, HTTPURLResponse)
}

/// `URLSession` implementation of `HTTPClient`. The session is injected so
/// tests can pass an ephemeral configuration that never leaves the process.
nonisolated final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent: String

    init(baseURL: URL, session: URLSession = .openLibrary, userAgent: String) {
        self.session = session
        self.baseURL = baseURL
        self.userAgent = userAgent
    }

    func send(_ endpoint: Endpoint) async throws(HTTPError) -> (Data, HTTPURLResponse) {
        var request = try endpoint.urlRequest(baseURL: baseURL, timeout: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw .transport(.cancelled)
        } catch let urlError as URLError {
            throw .transport(urlError.code)
        } catch {
            throw .transport(.unknown)
        }
        guard let http = response as? HTTPURLResponse else {
            throw .transport(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw .badStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw .emptyBody
        }
        return (data, http)
    }
}
