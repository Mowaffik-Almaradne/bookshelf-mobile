import Foundation

/// Shared sessions. The extension is `nonisolated` on purpose: with default
/// main-actor isolation a plain extension of `URLSession` would isolate these
/// statics to the main actor, and the nonisolated HTTP client (and later the
/// image actor) could not use them.
nonisolated extension URLSession {
    /// JSON API. Small caches, fast failure when the network is down.
    static let openLibrary: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "openlibrary-json", directoryHint: .isDirectory)
        )
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "BookShelf/1.0 (com.efendi.bookshelf)"
        ]
        return URLSession(configuration: configuration)
    }()

    /// Cover images. A separate disk cache so JSON responses do not evict covers.
    /// Covers are immutable by id, so a cached image is always valid.
    static let covers: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 0,
            diskCapacity: 150 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "covers", directoryHint: .isDirectory)
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        // Match JSON session: fail fast offline instead of waiting for a path.
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()
}
