import Foundation

/// Open Library implementation of `BookCatalog`.
///
/// Decoding and mapping run in `@concurrent` functions so a view model calling
/// on the main actor only receives domain values. `HTTPError` is mapped to
/// `AppError` here and does not escape this type.
nonisolated final class OpenLibraryBookCatalog: BookCatalog, Sendable {
    private let http: any HTTPClient
    private let pageSize = 20
    /// Longer author lists are mostly editors. Four names cover the byline
    /// without holding the details screen on the long tail.
    private let maxAuthors = 4

    init(http: any HTTPClient) {
        self.http = http
    }

    func search(query: String, page: Int) async throws -> SearchPage {
        let data = try await body(for: OpenLibraryEndpoints.search(query: query, page: page, limit: pageSize))
        return try await Self.searchPage(from: data, page: page, pageSize: pageSize)
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        var dto = try await fetchWork(key: workKey)
        if let redirected = Self.redirectTarget(of: dto) {
            dto = try await fetchWork(key: redirected)
        }
        let authors = try await authorNames(refs: dto.authors ?? [], fallback: seedAuthors)
        return await Self.makeDetails(from: dto, key: workKey, authors: authors)
    }

    private func body(for endpoint: Endpoint) async throws -> Data {
        do {
            let (data, _) = try await http.send(endpoint)
            return data
        } catch {
            throw AppError(error)
        }
    }

    private func fetchWork(key: WorkKey) async throws -> WorkDTO {
        let data = try await body(for: OpenLibraryEndpoints.work(key: key))
        return try await JSONDecoding.decode(WorkDTO.self, from: data)
    }

    /// Follow a redirect only when the type says so. A normal work can carry
    /// a `location` field; that is not a redirect.
    private static func redirectTarget(of dto: WorkDTO) -> WorkKey? {
        guard dto.type?.key == "/type/redirect", let location = dto.location else {
            return nil
        }
        return WorkKey(rawValue: location)
    }

    private func authorNames(refs: [AuthorRefDTO], fallback: [String]) async throws -> [String] {
        let keys = Array(refs.compactMap(\.key).prefix(maxAuthors))
        guard !keys.isEmpty else { return fallback }
        do {
            return try await resolvedNames(keys: keys)
        } catch AppError.cancelled {
            throw AppError.cancelled
        } catch is CancellationError {
            throw AppError.cancelled
        } catch {
            return fallback
        }
    }

    private func resolvedNames(keys: [String]) async throws -> [String] {
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, key) in keys.enumerated() {
                group.addTask {
                    try await self.authorName(at: index, key: key)
                }
            }
            var pairs: [(Int, String)] = []
            for try await pair in group {
                pairs.append(pair)
            }
            return pairs.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func authorName(at index: Int, key: String) async throws -> (Int, String) {
        let data = try await body(for: OpenLibraryEndpoints.author(key: key))
        let author = try await JSONDecoding.decode(AuthorDTO.self, from: data)
        guard let name = author.preferredName else { throw AppError.notFound }
        return (index, name)
    }

    /// Decode and map on the concurrent pool. A plain `nonisolated async`
    /// function would stay on the caller's executor, which is the main actor
    /// when a view model calls `search`.
    @concurrent
    private static func searchPage(from data: Data, page: Int, pageSize: Int) async throws -> SearchPage {
        let response = try await JSONDecoding.decode(SearchResponseDTO.self, from: data)
        return SearchPage(
            books: response.docs.compactMap { Book(doc: $0) },
            page: page,
            pageSize: pageSize,
            totalCount: response.numFound
        )
    }

    @concurrent
    private static func makeDetails(from dto: WorkDTO, key: WorkKey, authors: [String]) async -> BookDetails {
        BookDetails(dto: dto, key: key, authors: authors, fallbackTitle: Book.missingTitle)
    }
}
