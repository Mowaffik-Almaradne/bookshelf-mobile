import Foundation
import os
import Testing
@testable import BookShelf

@Suite struct URLSessionHTTPClientTests {
    private let userAgent = "BookShelfTests/1.0"

    @Test func success_returnsBodyAndResponse() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(data: Data("{\"ok\":true}".utf8), status: 200, id: harness.id)
        let (data, response) = try await harness.client.send(Endpoint(path: "/search.json"))
        #expect(String(decoding: data, as: UTF8.self) == "{\"ok\":true}")
        #expect(response.statusCode == 200)
        #expect(URLProtocolStub.requestCount(id: harness.id) == 1)
    }

    @Test func status404_isBadStatus() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(data: Data("missing".utf8), status: 404, id: harness.id)
        await #expect(throws: HTTPError.badStatus(404)) {
            try await harness.client.send(Endpoint(path: "/works/OL0W.json"))
        }
    }

    @Test func status500_isBadStatus() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(data: Data("down".utf8), status: 500, id: harness.id)
        await #expect(throws: HTTPError.badStatus(500)) {
            try await harness.client.send(Endpoint(path: "/search.json"))
        }
    }

    @Test func emptyBody_isEmptyBody() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(data: Data(), status: 200, id: harness.id)
        await #expect(throws: HTTPError.emptyBody) {
            try await harness.client.send(Endpoint(path: "/search.json"))
        }
    }

    @Test func timeout_preservesTimedOutCode() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(error: .timedOut, id: harness.id)
        await #expect(throws: HTTPError.transport(.timedOut)) {
            try await harness.client.send(Endpoint(path: "/search.json"))
        }
    }

    @Test func cancellation_preservesCancelledCode() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueueHang(id: harness.id)
        let recorded = OSAllocatedUnfairLock<HTTPError?>(initialState: nil)
        let client = harness.client
        let task = Task {
            do {
                _ = try await client.send(Endpoint(path: "/search.json"))
            } catch let error as HTTPError {
                recorded.withLock { $0 = error }
            }
        }
        let clock = ContinuousClock()
        let started = clock.now
        while URLProtocolStub.requestCount(id: harness.id) == 0 {
            try #require(clock.now - started < .seconds(2), "request never started")
            await Task.yield()
        }
        task.cancel()
        let cancelledAt = clock.now
        while recorded.withLock({ $0 }) == nil {
            try #require(clock.now - cancelledAt < .seconds(2), "cancellation was not mapped")
            await Task.yield()
        }
        #expect(recorded.withLock { $0 } == .transport(.cancelled))
    }

    @Test func userAgentHeader_isPresent() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(data: Data("{}".utf8), status: 200, id: harness.id)
        _ = try await harness.client.send(Endpoint(path: "/search.json"))
        #expect(URLProtocolStub.userAgents(id: harness.id) == [userAgent])
    }

    private func makeHarness() throws -> Harness {
        let id = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        configuration.httpAdditionalHeaders = ["X-Stub-ID": id]
        let baseURL = try #require(URL(string: "https://openlibrary.org"))
        let client = URLSessionHTTPClient(
            baseURL: baseURL,
            session: URLSession(configuration: configuration),
            userAgent: userAgent
        )
        return Harness(id: id, client: client)
    }

    private struct Harness {
        let id: String
        let client: URLSessionHTTPClient
    }
}
