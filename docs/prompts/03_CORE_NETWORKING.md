# Prompt 03 — Phase 1: core networking & error model

**Attach:** `@docs/04_NETWORKING.md @docs/11_ERROR_HANDLING_AND_LOGGING.md @docs/09_TESTING.md @docs/12_CODE_STANDARDS.md`

**Why this first:** everything else depends on it, and it is the "network behind a protocol"
requirement (Q2) that makes offline testing possible.

**Commits:** 1–2 (`feat(core): typed HTTP client with error mapping`).

---

```
Phase 1 of docs/13_IMPLEMENTATION_PLAN.md: the transport layer and the single user-facing error
type. Implement exactly what docs/04 and docs/11 specify.

APP FILES
- BookShelf/Core/Networking/Endpoint.swift
    `nonisolated struct Endpoint: Sendable, Equatable` with path, queryItems, method, and
    `func urlRequest(baseURL:timeout:) throws(HTTPError) -> URLRequest` built via URLComponents +
    URLQueryItem (never string interpolation). Sets Accept: application/json.
- BookShelf/Core/Networking/HTTPError.swift
    `nonisolated enum HTTPError: Error, Sendable, Equatable` — invalidURL(String),
    transport(URLError.Code), badStatus(Int), emptyBody.
- BookShelf/Core/Networking/HTTPClient.swift
    `nonisolated protocol HTTPClient: Sendable` with
    `func send(_ endpoint: Endpoint) async throws(HTTPError) -> (Data, HTTPURLResponse)`,
    plus `nonisolated final class URLSessionHTTPClient: HTTPClient` exactly as in docs/04
    (User-Agent header, status validation, empty-body check, URLError.cancelled preserved as
    .transport(.cancelled)).
- BookShelf/Core/Networking/URLSession+App.swift
    `nonisolated extension URLSession` with `static let openLibrary` and `static let covers`
    configured per the tables in docs/04 and docs/07. The `nonisolated` keyword on the extension
    is required: with default MainActor isolation these statics would otherwise be main-actor
    isolated and unusable from the nonisolated client and the image actor. Say that in a ///.
- BookShelf/Core/Networking/JSONDecoding.swift
    `nonisolated enum JSONDecoding` with a shared JSONDecoder (convertFromSnakeCase) and
    `@concurrent static func decode<T: Decodable & Sendable>(_:from:) async throws(AppError) -> T`.
    /// must explain why @concurrent is mandatory here (SE-0461: nonisolated async inherits the
    caller's executor, which would be the main actor).
- BookShelf/Domain/Errors/AppError.swift
    `nonisolated enum AppError: Error, Equatable, Sendable` with the cases and the two
    initialisers (`init(_ error: any Error)`, `init(http: HTTPError)`) and `isRetryable`, exactly
    per the mapping table in docs/11.

TEST FILES (BookShelfTests/)
- Support/URLProtocolStub.swift — URLProtocol subclass usable on an ephemeral configuration;
  supports queued responses, per-request error injection, and a thread-safe request counter.
- Support/Fixtures.swift — loads JSON from the test bundle by name; `#require`-friendly API.
  (Fixture JSON files arrive in the next phase; create the loader only.)
- Networking/EndpointTests.swift — URL composition; percent-encoding of "harry potter" and of the
  Arabic query "الرف"; query order stability; invalidURL path.
- Networking/URLSessionHTTPClientTests.swift — 200 success returns body+response; 404 →
  .badStatus(404); 500 → .badStatus(500); empty body → .emptyBody; URLError.timedOut →
  .transport(.timedOut); task cancellation → .transport(.cancelled); User-Agent header present.
- Domain/AppErrorMappingTests.swift — parametrised over the full mapping table in docs/11,
  including that .transport(.cancelled) maps to .cancelled and that .cancelled is not retryable.

ACCEPTANCE
- No test touches the real network (ephemeral session + URLProtocolStub only).
- Typed throws used on HTTPClient.send and Endpoint.urlRequest.
- Zero warnings under Swift 6; no @unchecked Sendable in app code (test doubles may use a lock
  with a justification comment).

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' BookShelf/ || echo "grep clean"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor,
  approachable concurrency is ON: a plain `nonisolated async` func runs on the CALLER's executor,
  so CPU-heavy work (JSON decoding, image decoding) MUST be `@concurrent nonisolated`.
- Types used off the main actor (DTOs, domain models, clients, static lets in extensions) must be
  explicitly `nonisolated` and `Sendable`.
- iOS 17.0 deployment target. Apple frameworks only: no SPM/CocoaPods packages, no Combine,
  no ObservableObject/@Published. Use @Observable, SwiftData, Swift Testing.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code,
  `AnyView`, hard-coded colours or font sizes, URLs built by string interpolation of user input.
- Layering: Views never touch URLSession/SwiftData. ViewModels never import SwiftUI or SwiftData.
  Domain imports Foundation only. DTOs never leave the Data layer.
- Every I/O dependency is a protocol injected through `init`. No singletons read from Views.
- `///` doc comments on every type and protocol requirement, explaining WHY and the invariants.
  Every `try?` gets a one-line comment saying why failure is acceptable.
- Tests: Swift Testing, deterministic, no sleeps for synchronisation. Same commit as the code.
- SCOPE: implement exactly what this prompt lists. Do not add files, features, abstractions or
  refactors that were not requested. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + grep, pasting the exact result lines, listing assumptions,
  and proposing commit messages. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- One primary type per file; file name == type name; target ≤ 150 lines, hard limit 250.
- Reusable logic goes into a small tested value type, not into a larger class.
- Before adding a type, grep for an existing one that does the job; report what you reused.
```
