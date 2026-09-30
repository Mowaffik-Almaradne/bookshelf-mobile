# 05 — Search state machine, debounce, stale protection & pagination

Requirement links: R1.1–R1.5, R2.1–R2.4, Q3-a, Q3-b.

## 1. Search phase (explicit state machine — R1.5)

```swift
enum SearchPhase: Equatable {
    case idle                                  // before any search (query < 3 chars)
    case loading                               // first page in flight, nothing to show yet
    case loaded(items: [Book], footer: Footer) // ≥1 result
    case empty                                 // 0 results for a valid query
    case failed(AppError)                      // first page failed → full-screen error + Retry

    enum Footer: Equatable {
        case idle           // more pages available, not loading
        case loading        // next page in flight → spinner row
        case failed(AppError) // next page failed → inline "Retry" row (keep existing items!)
        case end            // no more pages ("You've reached the end")
    }
}
```

Rules:
- A failure while loading page ≥2 **must not** discard already-loaded items: it becomes
  `.loaded(items, footer: .failed)`. Discarding results on a pagination hiccup is a classic bad UX.
- `.idle` also has copy: "Search for a title, author or subject" with `ContentUnavailableView`.
- `.empty` copy includes the query: `No results for "xyz"`.

## 2. `SearchViewModel`

```swift
@MainActor @Observable
final class SearchViewModel {
    // Inputs
    var query: String = "" { didSet { queryDidChange() } }

    // Outputs
    private(set) var phase: SearchPhase = .idle
    var isOnline: Bool { connectivity.isOnline }
    func isSaved(_ book: Book) -> Bool { shelf.isSaved(book.key) }

    // Dependencies (injected)
    private let catalog: any BookCatalog
    private let shelf: ShelfStore
    private let connectivity: any ConnectivityMonitoring
    private let debounce: Duration                // 350 ms in app, .zero in tests
    private let minimumQueryLength = 3

    // Internal
    private var paginator = Paginator<Book>(pageSize: 20)
    private var searchTask: Task<Void, Never>?
    private var pageTask: Task<Void, Never>?
    private var activeQuery: String = ""          // normalized query that the current results belong to
    private var generation = 0                    // monotonically increasing; stale guard

    // API
    func retry()                                  // re-run first page for activeQuery
    func retryNextPage()
    func loadNextPageIfNeeded(currentItem: Book)  // called from row .onAppear
    func submit()                                 // keyboard "Search": bypass debounce
}
```

### Debounce (R1.1) + minimum length (R1.2)

```swift
private func queryDidChange() {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    searchTask?.cancel()
    pageTask?.cancel()
    generation += 1

    guard normalized.count >= minimumQueryLength else {
        activeQuery = ""
        paginator.reset()
        phase = .idle
        return
    }
    guard normalized != activeQuery || phase.isFailed else { return }  // same query → no refetch

    let gen = generation
    searchTask = Task { [weak self] in
        try? await Task.sleep(for: debounce)         // cancelled → returns early below
        guard !Task.isCancelled, let self else { return }
        await self.performSearch(normalized, generation: gen)
    }
}
```

Notes:
- Normalisation = trim only. Do **not** lowercase (query shown back to user in `.empty`).
- Whitespace-only edits (`"harry"` → `"harry "`) must **not** trigger a new search (compare
  normalized strings).
- `submit()` cancels the debounce and runs immediately.

### Stale-result protection (R1.3) — two independent guards

1. **Cancellation**: cancelling `searchTask` propagates into `URLSession` → old request dies.
2. **Generation token**: even if a response slipped through (already decoded when cancelled), we
   only apply results whose `generation == self.generation`. Cancellation alone is not enough
   because cancellation is cooperative and the decode may already be finishing.

```swift
private func performSearch(_ q: String, generation gen: Int) async {
    activeQuery = q
    paginator.reset()
    phase = .loading
    do {
        let page = try await catalog.search(query: q, page: 1)
        guard gen == generation, !Task.isCancelled else { return }        // ← stale guard
        let added = paginator.append(page)
        phase = added.isEmpty && paginator.items.isEmpty
            ? .empty
            : .loaded(items: paginator.items, footer: paginator.hasMore ? .idle : .end)
    } catch let error as AppError where error == .cancelled {
        return                                                              // silent
    } catch {
        guard gen == generation else { return }
        phase = .failed(AppError(error))
    }
}
```

The test for R1.3: enqueue page for "harr" with delay 300 ms, then "harry" with delay 10 ms;
type "harr" then "harry"; advance; assert final phase items are the "harry" set and the "harr"
set was **never** observed in the phase history (record phase changes via `withObservationTracking`
or by polling in the test).

## 3. `Paginator<Item: Identifiable & Sendable>` — pure, generic, unit-tested

```swift
nonisolated struct Paginator<Item: Identifiable & Sendable>: Sendable {
    let pageSize: Int
    private(set) var items: [Item] = []
    private(set) var nextPage: Int = 1
    private(set) var hasMore: Bool = true
    private(set) var isLoading: Bool = false
    private var seenIDs: Set<Item.ID> = []

    init(pageSize: Int)

    mutating func reset()

    /// Returns true if a request for `nextPage` should start. Idempotent under rapid calls (R2.3).
    mutating func beginLoadingIfNeeded() -> Int? {
        guard hasMore, !isLoading else { return nil }
        isLoading = true
        return nextPage
    }

    mutating func failLoading()          // isLoading = false; page number unchanged → retry-able

    /// Merges a page, dropping duplicates (R2.2). Returns the newly added items.
    @discardableResult
    mutating func append(_ page: Page<Item>) -> [Item] {
        isLoading = false
        let fresh = page.items.filter { seenIDs.insert($0.id).inserted }
        items.append(contentsOf: fresh)
        nextPage = page.page + 1
        hasMore = Self.computeHasMore(page: page, loadedCount: items.count)
        return fresh
    }

    /// End detection (R2.4). `totalCount` drifts, so we AND two signals:
    /// short page ⇒ end; else loaded < total ⇒ more.
    static func computeHasMore(page: Page<Item>, loadedCount: Int) -> Bool {
        if page.items.count < page.pageSize { return false }
        if let total = page.totalCount { return loadedCount < total }
        return !page.items.isEmpty
    }

    /// Prefetch trigger: true when `item` is among the last `threshold` items.
    func shouldPrefetch(after item: Item, threshold: Int = 5) -> Bool
}
```

`Page<Item>` is a tiny generic (`items, page, pageSize, totalCount?`); `SearchPage` converts to it.
Domain independence lets the same paginator power any future list (Shelf paging, subjects, …).

Edge cases the tests must cover (Q3-b):

| Case | Expected |
|---|---|
| Page 2 repeats 2 keys from page 1 | `items.count == 38`, order preserved, first occurrence wins |
| Whole page duplicates (index shift) | `fresh.isEmpty` on a full page → `hasMore = false`; `nextPage` still advances |
| `beginLoadingIfNeeded` called 5× rapidly | returns page once, then `nil` ×4 |
| Failure then retry | `failLoading()` → next `beginLoadingIfNeeded()` returns the **same** page |
| Page of 7 with `pageSize 20` | `hasMore == false` |
| `totalCount` nil, full page | `hasMore == true` |
| `totalCount == loadedCount` | `hasMore == false` |
| `reset()` | everything back to initial including `seenIDs` |

## 4. Next-page trigger in the view (R2.1, R2.3)

```swift
ForEach(items) { book in
    BookRow(book: book, isSaved: vm.isSaved(book))
        .onAppear { vm.loadNextPageIfNeeded(currentItem: book) }
}
footer(for: phase)   // spinner / retry row / "end" caption
```

```swift
func loadNextPageIfNeeded(currentItem: Book) {
    guard case .loaded = phase,
          paginator.shouldPrefetch(after: currentItem),
          let page = paginator.beginLoadingIfNeeded() else { return }
    let gen = generation
    let q = activeQuery
    phase = .loaded(items: paginator.items, footer: .loading)
    pageTask = Task { [weak self] in
        guard let self else { return }
        do {
            let result = try await catalog.search(query: q, page: page)
            guard gen == generation else { return }
            paginator.append(result)
            phase = .loaded(items: paginator.items, footer: paginator.hasMore ? .idle : .end)
        } catch let error as AppError where error == .cancelled {
        } catch {
            guard gen == generation else { return }
            paginator.failLoading()
            phase = .loaded(items: paginator.items, footer: .failed(AppError(error)))
        }
    }
}
```

Why `onAppear` on rows (threshold = 5 from the end) instead of a sentinel row at the bottom:
`LazyVStack`/`List` may pre-render a sentinel early or skip it on fast fling; the threshold
approach starts loading **before** the user hits the bottom (smoother) and the paginator's
in-flight guard makes over-triggering harmless (R2.3).

## 5. View layout of states (R1.5)

| Phase | UI |
|---|---|
| `.idle` | `ContentUnavailableView("Find your next book", systemImage: "books.vertical", description: …)` |
| `.loading` | `ProgressView("Searching…")` centered (or 6 redacted skeleton rows via `.redacted(reason: .placeholder)`) |
| `.loaded` | `List` of `BookRow` + footer |
| `.empty` | `ContentUnavailableView.search(text: query)` — system-provided, localized, a11y-ready |
| `.failed(e)` | `ErrorStateView(error:) { vm.retry() }` — icon, `e.userMessage`, **Retry** button |

Offline: an `OfflineBanner` above the list whenever `!vm.isOnline` — in all phases.

Keyboard: `.searchable(text: $vm.query, prompt: …)` in the navigation bar; `.onSubmit(of: .search) { vm.submit() }`.
`.searchable` also gives a free clear button, dictation and iPad layout. Search suggestions are
not needed.

## 6. Row content (R1.4)

`BookRow`: `CoverView(coverID, size: .row)` (60×90 pt, `@ScaledMetric`) · title (2 lines,
`.headline`) · authors joined (1 line, `.subheadline`, secondary) · year (`.caption`) · saved
indicator `bookmark.fill` (accessibility label "Saved to shelf").

At `dynamicTypeSize.isAccessibilitySize` switch `HStack` → `VStack` (see 08).

## 7. Tests for Q3-a (`SearchViewModelTests`)

Using `StubCatalog` (scripted pages/errors/delays) with `debounce: .zero`:

1. `idle_whenQueryShorterThanThree` — "ha" → `.idle`, catalog never called.
2. `loading_thenLoaded` — phases observed `[.loading, .loaded]`.
3. `empty_onZeroDocs`.
4. `failed_onError_thenRetrySucceeds` — `.failed` → `retry()` → `.loaded`.
5. `staleResultsNeverShown` — the race described above.
6. `whitespaceChangeDoesNotRefetch` — `catalog.callCount == 1`.
7. `nextPage_appendsWithoutDuplicates_andDetectsEnd`.
8. `nextPage_failureKeepsItems_showsFooterRetry`.
9. `cancelledErrorIsSilent` — stub throws `.cancelled` → phase unchanged.
10. `savedStateReflectsShelf` — save via `ShelfStore` → `isSaved(book) == true` (R4.4).
