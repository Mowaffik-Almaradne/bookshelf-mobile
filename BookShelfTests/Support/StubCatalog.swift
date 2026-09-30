import Foundation
@testable import BookShelf

/// Scripted `BookCatalog`. Deterministic pages/errors/delays keyed by (query, page).
///
/// `@unchecked Sendable` because call log and script tables are mutable. Every
/// read and write goes through `lock`, which is what makes sharing across
/// search tasks safe. App code must not copy this pattern.
nonisolated final class StubCatalog: BookCatalog, @unchecked Sendable {
    struct Call: Equatable, Hashable, Sendable {
        let query: String
        let page: Int
    }

    private let lock = NSLock()
    private var _calls: [Call] = []
    private var _searchResults: [Call: Result<SearchPage, AppError>] = [:]
    private var _searchDelays: [Call: Duration] = [:]
    private var _detailsResult: Result<BookDetails, AppError> = .failure(.notFound)
    private var _detailsDelay: Duration?
    private var _detailsCallCount = 0
    private var _detailsWorkKeys: [WorkKey] = []

    var calls: [Call] {
        lock.withLock { _calls }
    }

    var callCount: Int { calls.count }

    var detailsCallCount: Int {
        lock.withLock { _detailsCallCount }
    }

    var detailsWorkKeys: [WorkKey] {
        lock.withLock { _detailsWorkKeys }
    }

    func stub(
        query: String,
        page: Int,
        result: Result<SearchPage, AppError>,
        delay: Duration? = nil
    ) {
        let call = Call(query: query, page: page)
        lock.withLock {
            _searchResults[call] = result
            if let delay {
                _searchDelays[call] = delay
            } else {
                _searchDelays.removeValue(forKey: call)
            }
        }
    }

    func stubDetails(
        _ result: Result<BookDetails, AppError>,
        delay: Duration? = nil
    ) {
        lock.withLock {
            _detailsResult = result
            _detailsDelay = delay
        }
    }

    func search(query: String, page: Int) async throws -> SearchPage {
        let call = Call(query: query, page: page)
        let (delay, result): (Duration?, Result<SearchPage, AppError>) = lock.withLock {
            _calls.append(call)
            return (_searchDelays[call], _searchResults[call, default: .failure(.notFound)])
        }
        if let delay {
            try await Task.sleep(for: delay)
        }
        try Task.checkCancellation()
        return try result.get()
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        let (delay, result): (Duration?, Result<BookDetails, AppError>) = lock.withLock {
            _detailsCallCount += 1
            _detailsWorkKeys.append(workKey)
            return (_detailsDelay, _detailsResult)
        }
        if let delay {
            try await Task.sleep(for: delay)
        }
        try Task.checkCancellation()
        return try result.get()
    }
}
