import Foundation
@testable import BookShelf

/// Scripted transport for catalog tests. Responses are matched by path
/// substring and consumed in enqueue order, so a redirect and its target can
/// share the same client.
///
/// `@unchecked Sendable` because the queue and the recorded endpoints are
/// mutable. Author resolution calls `send` from several tasks at once; every
/// access goes through `lock`, which is what makes the mock safe to share.
nonisolated final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private struct Stub {
        let needle: String
        let result: Result<StubBody, HTTPError>
    }

    private struct StubBody {
        let data: Data
        let status: Int
    }

    private let lock = NSLock()
    private var stubs: [Stub] = []
    private var sent: [Endpoint] = []

    /// Every endpoint passed to `send`, in call order.
    var sentEndpoints: [Endpoint] {
        lock.withLock { sent }
    }

    func enqueue(data: Data, status: Int = 200, whenPathContains needle: String) {
        let stub = Stub(needle: needle, result: .success(StubBody(data: data, status: status)))
        lock.withLock { stubs.append(stub) }
    }

    func enqueue(error: HTTPError, whenPathContains needle: String) {
        let stub = Stub(needle: needle, result: .failure(error))
        lock.withLock { stubs.append(stub) }
    }

    func send(_ endpoint: Endpoint) async throws(HTTPError) -> (Data, HTTPURLResponse) {
        let matched: Result<StubBody, HTTPError>? = lock.withLock {
            sent.append(endpoint)
            guard let index = stubs.firstIndex(where: { endpoint.path.contains($0.needle) }) else {
                return nil
            }
            return stubs.remove(at: index).result
        }
        guard let matched else {
            throw .invalidURL("unmatched \(endpoint.path)")
        }
        switch matched {
        case .failure(let error):
            throw error
        case .success(let body):
            guard (200..<300).contains(body.status) else {
                throw .badStatus(body.status)
            }
            guard !body.data.isEmpty else {
                throw .emptyBody
            }
            guard let url = URL(string: "https://openlibrary.org") else {
                throw .invalidURL(endpoint.path)
            }
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: body.status,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw .transport(.badServerResponse)
            }
            return (body.data, response)
        }
    }
}
