# 09 — Testing strategy

Requirement links: Q2, Q3 (≥ 3 areas: search states, pagination/no-dupes, details decoding).
Target: **~35 focused unit tests, < 3 s total**, zero network, zero flakiness, run on every commit.

## Framework: Swift Testing (`import Testing`)

Chosen over XCTest because: `#expect`/`#require` give rich failure diagnostics, `@Test(arguments:)`
makes the decoding-shape matrix a one-liner, `@Suite` structs give per-test isolation without
`setUp`, async tests are natural. Mention in README (it also signals currency with the platform).
XCTest remains available for a UI smoke test if desired.

## Test target setup (one-time, manual — Phase 0)

1. Xcode ▸ File ▸ New ▸ Target ▸ **Unit Testing Bundle** → name `BookShelfTests`, Testing System:
   **Swift Testing**, target to test: `BookShelf`.
2. Ensure `BookShelfTests` build settings inherit `SWIFT_VERSION = 6.0` and
   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (tests that touch `@MainActor` types then need no
   annotations).
3. Add `Fixtures/` folder (JSON) to the test target — with synchronized groups this is automatic
   when the folder lives inside `BookShelfTests/`.
4. Share the scheme (Product ▸ Scheme ▸ Manage Schemes ▸ Shared) so `xcodebuild test` works for
   reviewers; commit `BookShelf.xcodeproj/xcshareddata/xcschemes/BookShelf.xcscheme`.
5. Verify from terminal:
   ```bash
   xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:BookShelfTests | xcbeautify   # xcbeautify optional
   # Installed simulators on this Mac: iPhone 17 / 17 Pro / Air / 16e, iPad Pro (M5), iPad mini (A17 Pro).
   # Runtimes installed: iOS 26.2 / 26.4 / 26.5 — the app still targets iOS 17.0 so reviewers on older runtimes can run it.
   ```

## Test pyramid for this app

| Layer | What | How | Count |
|---|---|---|---|
| Decoding & mapping | DTO shapes → domain | Real JSON fixtures through real `JSONDecoding` | ~12 |
| Pure logic | `Paginator`, `WorkKey`, `CoverURL`, error mapping | Direct calls | ~10 |
| ViewModels | `SearchViewModel`, `BookDetailsViewModel`, `ShelfStore` | Stub `BookCatalog`, in-memory SwiftData, `debounce: .zero` | ~14 |
| Core | `ImageLoader` | `URLProtocol` stub | ~5 |
| UI (optional) | one XCUITest smoke: type → results → open → save → shelf shows | Launch arg `-uiTesting` swaps `AppDependencies.live()` for stub catalog | 1 |

No snapshot tests (no library allowed and hand-rolled ones are brittle). Previews cover visual
states instead.

## Test doubles (BookShelfTests/Support)

```swift
/// Scripted domain service. Deterministic, records calls.
final class StubCatalog: BookCatalog, @unchecked Sendable {   // guarded by a lock
    struct Call: Equatable { let query: String; let page: Int }
    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.withLock { _calls } }

    /// Result per (query, page). Missing → throws .notFound so tests fail loudly.
    var searchResults: [Call: Result<SearchPage, AppError>] = [:]
    var searchDelays: [Call: Duration] = [:]
    var detailsResult: Result<BookDetails, AppError> = .failure(.notFound)

    func search(query: String, page: Int) async throws -> SearchPage {
        let call = Call(query: query, page: page)
        lock.withLock { _calls.append(call) }
        if let delay = searchDelays[call] { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
        return try searchResults[call, default: .failure(.notFound)].get()
    }
    …
}

final class MockHTTPClient: HTTPClient, @unchecked Sendable { … enqueue(data, status, for: pathContains) … }

struct TestImageLoader: ImageLoading { var data: Data?; var image: UIImage? … }

final class StubConnectivity: ConnectivityMonitoring { var isOnline = true }

enum Fixtures {
    static func data(_ name: String) throws -> Data   // Bundle(for:) lookup; #require non-nil
    static func page(_ name: String, page: Int) throws -> SearchPage
}

extension Book { static func stub(id: String = "OL1W", title: String = "Book \(id)") -> Book }
extension SearchPage { static func stub(ids: [String], page: Int, total: Int?) -> SearchPage }
```

`@unchecked Sendable` in **test doubles only**, with a lock; never in app code.

## Waiting for `@Observable` state in tests (no Combine, no XCTestExpectation)

```swift
/// Polls until `condition` is true or timeout. Yields to let MainActor tasks progress.
@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async throws {
    let clock = ContinuousClock(); let start = clock.now
    while !condition() {
        try #require(clock.now - start < timeout, "timed out")
        await Task.yield()
    }
}

/// Records every distinct phase (for asserting "stale results never appeared").
@MainActor
final class PhaseRecorder<Phase: Equatable> {
    private(set) var history: [Phase] = []
    func observe(_ read: @escaping @MainActor () -> Phase) { … withObservationTracking recursive … }
}
```

With `debounce: .zero` and `Task.yield()` polling, the whole `SearchViewModelTests` suite runs in
well under a second and is deterministic (no real sleeps except explicit stub delays of ≤ 50 ms
in the race test).

## Test inventory (the acceptance matrix)

### Decoding — `WorkDecodingTests` (Q3-c) — parametrised
```swift
@Suite struct WorkDecodingTests {
    @Test(arguments: [
        ("work_description_string", "The main character of Fantastic Mr. Fox"),
        ("work_description_object", "Turning the envelope over"),
    ])
    func description_decodesBothShapes(fixture: String, prefix: String) async throws { … }

    @Test func description_absent_isNil()
    @Test func covers_filterNegativeAndPickFirst()          // [-1, 6498519] → coverID 6498519
    @Test func authors_nestedShape_extractsKeys()
    @Test func authors_legacyShape_extractsKeys()
    @Test func subjects_absent_isEmptyArray()
    @Test func minimalWork_decodesWithFallbackTitle()
    @Test func redirect_isDetectedAndFollowedOnce()          // via MockHTTPClient + real catalog
    @Test func malformedJSON_throwsDecodingError_noCrash()
    @Test func crlf_isNormalizedToLF()
}
```

### Decoding — `SearchResponseDecodingTests`
- `page1_decodes20Books_mapsOptionalFields`
- `docWithoutKey_isDroppedNotCrash`
- `emptyDocs_yieldsEmptyPage`
- `numFoundMissing_totalIsNil`

### Pure logic — `PaginatorTests` (Q3-b) — the 8 rows from 05 §3, plus `WorkKeyTests`
(`init?(rawValue:)` rejects `/authors/…`, accepts `/works/OL1W`), `CoverURLTests`
(`default=false` present, non-positive id → nil), `AppErrorMappingTests` (table from 04).

### ViewModels — `SearchViewModelTests` (Q3-a) — the 10 tests from 05 §7.

### ViewModels — `BookDetailsViewModelTests` — the 4 tests from 06.

### Store — `ShelfStoreTests` — the 7 tests from 06 (in-memory `ModelContainer`).

### Core — `ImageLoaderTests` — the 5 tests from 07.

## Conventions

- Test names: `behaviour_underCondition` (`nextPage_failureKeepsItems_showsFooterRetry`).
- One behaviour per test; arrange/act/assert separated by a blank line.
- Use `#require` for preconditions (unwrap fixtures), `#expect` for assertions.
- Never `sleep` for synchronisation; use `waitUntil`.
- Fixtures are **real API responses**, trimmed, with a header comment in `Fixtures.swift` listing
  the source URL and capture date.
- Tests compile under Swift 6 strict concurrency with **zero warnings**.

## CI-ish safety (cheap, optional but recommended for D2 "senior" signal)

Add `scripts/test.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BookShelfTests -quiet
```
and a `.github/workflows/ci.yml` running it on `macos-latest` with `xcode-select` to Xcode 26 if
available. Reviewers seeing a green check on the repo is a strong stability signal; if runner
Xcode versions are a hassle, keep the script only and mention CI in "what I'd do with one more day".

## What "100/100 on tests" looks like to a grader

- The three mandated areas are **obviously present** — name the files after them.
- Tests run offline, fast, and green from a clean clone with one command.
- Fixtures are real payloads and include the ugly shapes (string vs object, `-1` covers, redirect).
- The race condition (R1.3) and the in-flight guard (R2.3) have **explicit** tests — these are the
  "hard cases" evaluators check.
- No `XCTAssertNoThrow(try!…)`-style cheats, no disabled tests, no `sleep(1)`.
