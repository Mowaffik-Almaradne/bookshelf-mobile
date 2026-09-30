# Prompt 07 — Phase 4b: the Search feature

**Attach:** `@docs/05_SEARCH_AND_PAGINATION.md @docs/08_UI_ACCESSIBILITY_LOCALIZATION.md @docs/11_ERROR_HANDLING_AND_LOGGING.md @docs/09_TESTING.md @docs/12_CODE_STANDARDS.md`

**This is the highest-scoring phase.** It carries R1 (debounce, minimum length, stale results,
row content, five states), R2 (pagination) and Q3-a (search state tests). The stale-result race
test is the single test a senior reviewer looks for first.

**Commits:** 2 (`feat(search): view model with debounce, stale guard and pagination`,
`feat(search): search screen with all five states`).

---

```
Phase 4b of docs/13_IMPLEMENTATION_PLAN.md: the Search feature. Implement exactly the state
machine and behaviour in docs/05, using the component kit from BookShelf/UI (do not build new
generic components here).

DEPENDENCIES THAT DO NOT EXIST YET — define the seams now
- `Domain/Services/SavedStateReading.swift`: `@MainActor protocol SavedStateReading { func isSaved(_ key: WorkKey) -> Bool }`.
  ShelfStore will conform in a later phase. Inject `any SavedStateReading`.
- `Domain/Services/ConnectivityMonitoring.swift`: `nonisolated protocol ConnectivityMonitoring: Sendable { @MainActor var isOnline: Bool { get } }`.
  The real NWPathMonitor implementation comes later. Provide `StubConnectivity` in the test
  support folder and a preview instance.

APP FILES
- Features/Search/SearchPhase.swift
    `enum SearchPhase: Equatable` with idle, loading, loaded(items:footer:), empty, failed(AppError)
    and the nested `enum Footer: Equatable { case idle, loading, failed(AppError), end }`,
    plus small computed helpers the view needs (e.g. `items`, `isFailed`).
- Features/Search/SearchViewModel.swift  (@MainActor @Observable final class)
    Injected: `any BookCatalog`, `any SavedStateReading`, `any ConnectivityMonitoring`,
    `debounce: Duration` (350ms in the app, .zero in tests), `minimumQueryLength: Int = 3`.
    Must implement, exactly as docs/05 specifies:
      * query didSet → cancel searchTask AND pageTask, bump the generation token
      * trim-only normalisation; < 3 characters → .idle and NO catalog call
      * a whitespace-only change ("harry" → "harry ") must NOT refetch
      * debounce via `try? await Task.sleep(for:)` then `guard !Task.isCancelled`
      * stale protection by BOTH cancellation and a generation token compared after every await,
        because a response may already be decoding when the task is cancelled
      * AppError.cancelled is swallowed everywhere and never changes `phase`
      * pagination via the Paginator from Phase 3: loadNextPageIfNeeded(currentItem:) using
        shouldPrefetch(threshold: 5) and beginLoadingIfNeeded() as the in-flight guard
      * a failure on page >= 2 KEEPS the loaded items and sets footer .failed
      * retry(), retryNextPage(), submit() (bypasses the debounce)
      * `func isSaved(_ book: Book) -> Bool` delegating to SavedStateReading
    The ViewModel must NOT import SwiftUI.
- Features/Search/SearchView.swift  (screen: composition + navigation only)
    `.searchable(text:placement:.navigationBarDrawer(displayMode:.always), prompt:)`,
    `.onSubmit(of: .search)`, `.navigationTitle`. A @ViewBuilder switch over `vm.phase` that
    delegates to the five state views. OfflineBanner above the content when !isOnline.
    `NavigationLink(value: book)`; the destination is registered here as a placeholder Text for
    now (the Details screen arrives in a later phase) — keep it a one-line stub.
- Features/Search/Components/BookRow.swift  (feature component)
    Inputs: `book: Book`, `isSaved: Bool`. Uses CoverView + AdaptiveRowLayout from the UI kit.
    Title `.headline` 2 lines, authors `.subheadline` secondary 1 line, year `.caption`,
    bookmark.fill when saved. `.accessibilityElement(children: .combine)` with the composed
    label from docs/08 (title, by authors, first published year, saved to shelf) — build the
    label from parts, omitting the year when nil. Year formatted WITHOUT grouping.
- Features/Search/Components/SearchStateViews.swift
    Small private-to-feature views for idle / loading / empty, each built on
    ContentUnavailableView (use `ContentUnavailableView.search(text:)` for empty) or ProgressView.
    Keep each under 25 lines.

TEST FILES
- Support/StubCatalog.swift — scripted results keyed by (query, page), optional per-call delay,
  records every call, honours cancellation via `try Task.checkCancellation()`. Thread-safe with
  a lock and a justification comment.
- Support/WaitUntil.swift — `waitUntil(timeout:_:)` polling with `Task.yield()`, and a
  `PhaseRecorder` that records every distinct value of an @Observable property using
  `withObservationTracking`. No sleeps as synchronisation.
- Support/StubConnectivity.swift, Support/StubSavedState.swift.
- Features/SearchViewModelTests.swift — the 10 tests listed in docs/05 section 7:
   1. query shorter than 3 chars → .idle and catalog never called
   2. loading then loaded (assert the recorded phase sequence)
   3. zero docs → .empty
   4. error → .failed, then retry() → .loaded
   5. STALE RESULTS: script "harr" with a 300ms delay and "harry" with 10ms; type both; assert
      the final items are "harry"'s AND that the recorded phase history never contained "harr"'s
      items. This test is the proof for R1.3 — make it explicit and well named.
   6. whitespace-only change does not refetch (catalog call count stays 1)
   7. next page appends without duplicates and detects the end
   8. next page failure keeps items and sets footer .failed; retryNextPage() re-requests the
      SAME page number
   9. AppError.cancelled leaves the phase untouched
  10. isSaved reflects the injected SavedStateReading

ACCEPTANCE
- SearchViewModel does not import SwiftUI; SearchView contains no networking, no formatting
  logic and no layout maths (those live in the kit and the row).
- Every one of the five states is reachable in a #Preview (light, dark, .accessibility3).
- The suite still runs in under a few seconds with no real sleeps except the scripted stub delays.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'import SwiftUI' BookShelf/Features/Search/SearchViewModel.swift || echo "view model is UI-free"
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' BookShelf/ || echo "grep clean"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor,
  approachable concurrency is ON: CPU-heavy work MUST be `@concurrent nonisolated`.
- iOS 17.0 deployment target. Apple frameworks only: no packages, no Combine, no
  ObservableObject/@Published. Use @Observable and Swift Testing.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code,
  `AnyView`, hard-coded colours or font sizes, magic spacing numbers.
- Layering: Views never touch URLSession/SwiftData; ViewModels never import SwiftUI.
- Every I/O dependency is a protocol injected through `init`.
- Every user-facing string localized (en + ar); every control has an accessibility label.
- `///` doc comments explaining WHY, especially on the generation token and the in-flight guard.
- Tests in the same commit as the code; deterministic; no sleeps for synchronisation.
- SCOPE: implement exactly what this prompt lists. Do not build the Details or Shelf screens, do
  not add search history/suggestions/sorting. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + greps, pasting the exact result lines, listing assumptions,
  and proposing two commit messages. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- SCREEN (SearchView) = composition + navigation only; no layout maths, no formatting, no logic.
- Feature components live in Features/Search/Components/ and take plain values + closures.
- Reuse the UI kit (CoverView, ErrorStateView, LoadingFooterView, OfflineBanner,
  AdaptiveRowLayout, AppError+Presentation). Report which ones you reused; do not duplicate them.
- If a view body exceeds ~40 lines, extract a child View struct.
- One primary type per file; ≤ 150 lines target, 250 hard limit.
```
