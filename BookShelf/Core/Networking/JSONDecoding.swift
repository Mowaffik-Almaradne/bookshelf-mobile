import Foundation

/// JSON decoding for API payloads.
///
/// `@concurrent` is mandatory. Under approachable concurrency a plain
/// `nonisolated async` function stays on the caller's executor (SE-0461).
/// Called from a view model, that executor is the main actor, so a search
/// payload would hitch scrolling. A new `JSONDecoder` is created on each call:
/// the class is mutable and not `Sendable`, so a shared instance would race
/// when two `@concurrent` decodes overlap.
nonisolated enum JSONDecoding {
    /// Runs on the concurrent thread pool regardless of the caller.
    @concurrent
    static func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        from data: Data
    ) async throws(AppError) -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }
}
