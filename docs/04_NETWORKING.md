# 04 — Networking layer

Requirement links: Q1 (UI never touches network), Q2 (protocol boundary), Q4 (no force unwrap),
Q5 (decode off main), R1.3 (cancellation).

## Design

```
ViewModel ─▶ BookCatalog (domain protocol)
                └─ OpenLibraryBookCatalog (Data)
                      └─ HTTPClient (Core protocol) ─▶ URLSessionHTTPClient ─▶ URLSession
                      └─ JSONDecoder (@concurrent)
```

Two protocol layers on purpose:
- `HTTPClient` is **generic transport** (bytes in/out). It is what tests mock (`MockHTTPClient`)
  to feed **real JSON fixtures** through the *real* decoding + mapping code.
- `BookCatalog` is the **domain service**. ViewModel tests mock *this* (`StubCatalog`) to script
  pages, delays and errors without JSON.

## `Endpoint` — typed request description

```swift
nonisolated struct Endpoint: Sendable, Equatable {
    var path: String                      // "/search.json"
    var queryItems: [URLQueryItem] = []
    var method: String = "GET"

    func urlRequest(baseURL: URL, timeout: TimeInterval) throws(HTTPError) -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else { throw .invalidURL(path) }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw .invalidURL(path) }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
```

`OpenLibraryEndpoints` is a namespace of static factory functions:
`search(query:page:limit:)`, `work(key:)`, `author(key:)`. Query construction via
`URLQueryItem` — never string interpolation of user text (encoding + injection safety).

## `HTTPClient` protocol

```swift
nonisolated protocol HTTPClient: Sendable {
    /// Performs the request and returns body + response. Throws HTTPError only.
    func send(_ endpoint: Endpoint) async throws(HTTPError) -> (Data, HTTPURLResponse)
}
```

Typed throws (Swift 6) keeps the error surface explicit and forces callers to map errors.

## `HTTPError` → mapped to `AppError` at the catalog boundary

```swift
nonisolated enum HTTPError: Error, Sendable, Equatable {
    case invalidURL(String)
    case transport(URLError.Code)          // offline, timeout, cancelled, …
    case badStatus(Int)
    case emptyBody
}
```

`URLError.cancelled` must be preserved so upper layers can **silently ignore** it (R1.3).

## `URLSessionHTTPClient`

```swift
nonisolated final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent: String

    init(baseURL: URL, session: URLSession = .openLibrary, userAgent: String) { … }

    func send(_ endpoint: Endpoint) async throws(HTTPError) -> (Data, HTTPURLResponse) {
        var request = try endpoint.urlRequest(baseURL: baseURL, timeout: 15)   // throws(HTTPError)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: request) }
        catch let urlError as URLError { throw .transport(urlError.code) }
        catch { throw .transport(.unknown) }
        guard let http = response as? HTTPURLResponse else { throw .transport(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw .badStatus(http.statusCode) }
        guard !data.isEmpty else { throw .emptyBody }
        return (data, http)
    }
}
```

Session configuration (one shared instance, `URLSession.openLibrary`). Declare it as
`nonisolated extension URLSession { static let openLibrary: URLSession = { … }() }` — with
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, declarations in *our* extensions of imported types
would otherwise become main-actor-isolated and be unusable from the `nonisolated` client and the
`ImageLoader` actor. The same applies to `Log`, `JSONDecoding`, `CoverURL` and every DTO — hence
the explicit `nonisolated` keyword on them throughout these docs.

| Setting | Value | Why |
|---|---|---|
| `timeoutIntervalForRequest` | 15 s | API is slow; 60 s default feels frozen. Retry button covers the rest |
| `timeoutIntervalForResource` | 30 s | |
| `waitsForConnectivity` | `false` | We want a fast `.notConnectedToInternet` so the UI shows the offline state immediately; the connectivity monitor handles reconnects |
| `requestCachePolicy` | `.useProtocolCachePolicy` | Let URLCache do HTTP caching for JSON |
| `urlCache` | 10 MB mem / 50 MB disk | Cheap repeat-search performance, some offline resilience |
| `httpAdditionalHeaders` | `Accept`, `User-Agent` | Open Library etiquette |

The **image** session is separate (`URLSession.covers`) with a **larger disk cache** (150 MB) so
JSON and images do not evict each other. See `07_IMAGE_LOADING.md`.

## Decoding — off the main actor

```swift
nonisolated enum JSONDecoding {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Runs on the global concurrent executor regardless of caller isolation.
    @concurrent
    static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws(AppError) -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw .decoding(String(describing: error)) }
    }
}
```

Why `@concurrent`: under approachable concurrency a `nonisolated async` function inherits the
caller's actor (SE-0461). Search payloads are ~10–40 KB, work payloads can reach 100 KB+; decoding
on the main actor during scrolling causes visible hitches. `@concurrent` guarantees a background
thread.

## `OpenLibraryBookCatalog`

Responsibilities: build endpoints → `HTTPClient.send` → decode → map DTO → domain; **map errors**
to `AppError`; implement author resolution and redirect following.

```swift
nonisolated final class OpenLibraryBookCatalog: BookCatalog {
    private let http: any HTTPClient
    private let pageSize = 20

    func search(query: String, page: Int) async throws -> SearchPage {
        let (data, _) = try await http.send(.search(query: query, page: page, limit: pageSize))
        let dto = try await JSONDecoding.decode(SearchResponseDTO.self, from: data)
        return SearchPage(dto: dto, page: page, pageSize: pageSize)   // mapping drops docs w/o key
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        var dto = try await fetchWork(path: workKey.detailsPath)
        if dto.type?.key == "/type/redirect", let location = dto.location,
           let redirected = WorkKey(rawValue: location) {
            dto = try await fetchWork(path: redirected.detailsPath)       // follow once only
        }
        let names = await resolveAuthorNames(refs: dto.authors ?? [], fallback: seedAuthors)
        return BookDetails(dto: dto, key: workKey, authors: names)
    }
}
```

Error mapping (single function, unit-tested):

| `HTTPError` | `AppError` |
|---|---|
| `.transport(.cancelled)` | `.cancelled` (never shown) |
| `.transport(.notConnectedToInternet / .networkConnectionLost / .dataNotAllowed)` | `.offline` |
| `.transport(.timedOut)` | `.timeout` |
| `.transport(other)` | `.network` |
| `.badStatus(429)` | `.rateLimited` |
| `.badStatus(5xx)` | `.server` |
| `.badStatus(4xx)` | `.notFound` (404) / `.server` |
| decoding failure | `.decoding` |

## Retry policy

- **No automatic retries** for search (user is typing; the Retry button is the requirement). A
  silent retry would also re-order results and complicate stale protection.
- Details: **one** automatic retry on `.timeout`/`.server` after 1 s **only if** the task is not
  cancelled — cheap win for the slow API; document in README.
- Images: no retry; a failed image shows the placeholder, and a re-scroll naturally retries.

## Testing hooks

- `MockHTTPClient` (`nonisolated final class, Sendable` with a lock-protected state, or an actor):
  - `enqueue(_ result: Result<(Data, Int), HTTPError>, for matcher: (Endpoint) -> Bool)`
  - records `sentEndpoints` so tests assert **exact page numbers requested** (R2.3).
  - optional per-response `delay: Duration` to simulate slow responses and ordering races (R1.3).
- `Fixtures.data("work_description_object")` loads JSON from the test bundle.

## Checklist for this layer

- [ ] No `URLSession.shared` in app code (explicit configuration only).
- [ ] No `String(format:)`/interpolation to build URLs with user text.
- [ ] All decoding via `JSONDecoding.decode` (`@concurrent`).
- [ ] Every `HTTPError` is mapped; `.cancelled` never reaches the UI.
- [ ] `User-Agent` set.
- [ ] Zero `!`, `try!`, `as!` in `Core/Networking` and `Data/`.
