import Foundation
import os

/// Scripted `URLProtocol` for an ephemeral session. Each test gets its own box
/// id so parallel tests do not share a queue. `nonisolated` is required: the
/// test target is main-actor by default, but `URLSession` calls `startLoading`
/// off the main actor. `@unchecked Sendable` is only this test double, because
/// `URLProtocol` itself is not `Sendable`; the registry lock is the shared state.
nonisolated final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private enum Action: Sendable {
        case response(data: Data, status: Int, headers: [String: String])
        case failure(URLError.Code)
        case hang
    }

    private struct Box: Sendable {
        var actions: [Action] = []
        var count = 0
        var userAgents: [String?] = []
    }

    /// Serializes the registry. `@unchecked Sendable` is only this test double:
    /// `URLProtocol` is not Sendable, and sessions call it from background queues.
    private static let registry = OSAllocatedUnfairLock<[String: Box]>(initialState: [:])
    private let finished = OSAllocatedUnfairLock(initialState: false)

    static func enqueue(data: Data, status: Int, headers: [String: String] = [:], id: String) {
        enqueue(.response(data: data, status: status, headers: headers), id: id)
    }

    static func enqueue(error: URLError.Code, id: String) {
        enqueue(.failure(error), id: id)
    }

    static func enqueueHang(id: String) {
        enqueue(.hang, id: id)
    }

    static func requestCount(id: String) -> Int {
        registry.withLock { $0[id]?.count ?? 0 }
    }

    static func userAgents(id: String) -> [String?] {
        registry.withLock { $0[id]?.userAgents ?? [] }
    }

    private static func enqueue(_ action: Action, id: String) {
        registry.withLock { boxes in
            var box = boxes[id] ?? Box()
            box.actions.append(action)
            boxes[id] = box
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "X-Stub-ID") != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let action = Self.registry.withLock { boxes -> Action? in
            guard let id = request.value(forHTTPHeaderField: "X-Stub-ID") else {
                return nil
            }
            var box = boxes[id] ?? Box()
            box.count += 1
            box.userAgents.append(request.value(forHTTPHeaderField: "User-Agent"))
            let next = box.actions.isEmpty ? nil : box.actions.removeFirst()
            boxes[id] = box
            return next
        }
        switch action {
        case .some(.response(let data, let status, let headers)):
            deliver(data: data, status: status, headers: headers)
        case .some(.failure(let code)):
            fail(URLError(code))
        case .some(.hang), .none:
            break
        }
    }

    override func stopLoading() {
        let already = finished.withLock { finished -> Bool in
            if finished { return true }
            finished = true
            return false
        }
        if already { return }
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }

    private func deliver(data: Data, status: Int, headers: [String: String]) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: headers
              ) else {
            fail(URLError(.badURL))
            return
        }
        let first = finished.withLock { finished -> Bool in
            if finished { return false }
            finished = true
            return true
        }
        guard first else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func fail(_ error: URLError) {
        let first = finished.withLock { finished -> Bool in
            if finished { return false }
            finished = true
            return true
        }
        guard first else { return }
        client?.urlProtocol(self, didFailWithError: error)
    }
}
