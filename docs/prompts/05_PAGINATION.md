# Prompt 05 — Phase 3: the pagination engine

**Attach:** `@docs/05_SEARCH_AND_PAGINATION.md @docs/12_CODE_STANDARDS.md`

**Why it is its own phase:** requirement Q3-b asks for tested pagination logic including
no-duplication. Keeping it a pure value type outside the ViewModel is what makes the tests
deterministic — and it is the most obviously reusable piece in the app.

**Commit:** 1 (`feat(domain): generic paginator with dedupe and in-flight guard`).

---

```
Phase 3 of docs/13_IMPLEMENTATION_PLAN.md: a pure, generic pagination engine. Implement exactly
the design in docs/05 section 3.

APP FILES
- BookShelf/Domain/Pagination/Page.swift
    `nonisolated struct Page<Item: Identifiable & Sendable>: Sendable` with items, page, pageSize,
    totalCount: Int?.
- BookShelf/Domain/Pagination/Paginator.swift
    `nonisolated struct Paginator<Item: Identifiable & Sendable>: Sendable` where Item.ID: Hashable
    & Sendable, with: items, nextPage, hasMore, isLoading, private seenIDs;
    reset(), beginLoadingIfNeeded() -> Int?, failLoading(), @discardableResult append(_:) -> [Item],
    static computeHasMore(page:loadedCount:), shouldPrefetch(after:threshold:) -> Bool.
- BookShelf/Domain/Pagination/SearchPage+Page.swift — conversion from SearchPage to Page<Book>.

INVARIANTS TO ENCODE IN /// COMMENTS (and to preserve in the implementation)
- append() is the ONLY place that clears isLoading on success; failLoading() clears it on failure
  WITHOUT advancing the page, so a retry re-requests the same page.
- beginLoadingIfNeeded() returns a page number at most once until the request settles — this is
  what makes fast scrolling unable to fire two requests for the same page (R2.3).
- Duplicate items are dropped by ID on merge, first occurrence wins, order is preserved (R2.2).
- End detection ANDs two signals because `numFound` drifts between pages on the real API:
  a short page always means the end; otherwise loadedCount < totalCount when totalCount is known;
  otherwise a full page means "probably more" (R2.4).
- A page that is entirely duplicates must still advance nextPage, otherwise the list would loop
  forever requesting the same page.

TEST FILE
BookShelfTests/Domain/PaginatorTests.swift with a tiny `struct TestItem: Identifiable, Sendable`
stub. Cover every row of the edge-case table in docs/05 section 3:
 1. page 2 repeating 2 IDs from page 1 → 38 items, order preserved, first occurrence wins
 2. a page that is 100% duplicates → append returns [], nextPage still advances
 3. beginLoadingIfNeeded() called 5 times rapidly → one page number then 4 nils
 4. failLoading() then beginLoadingIfNeeded() → the SAME page number again
 5. a short page (7 of 20) → hasMore == false
 6. totalCount nil with a full page → hasMore == true
 7. totalCount == loadedCount → hasMore == false
 8. reset() → items, seenIDs, nextPage, hasMore, isLoading all back to initial
Plus: shouldPrefetch is true only for the last `threshold` items and false for an item not in the
list.

ACCEPTANCE
- Paginator has no dependency on Book, networking, SwiftUI or Foundation beyond the standard
  library types it needs; it compiles as a pure value type.
- Every mutating method is covered by at least one test.
- No test uses async, sleeps or stubs — this is synchronous pure logic.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor;
  this type must be explicitly `nonisolated` and `Sendable`.
- iOS 17.0 deployment target. Apple frameworks only. No Combine.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code.
- Domain imports Foundation only.
- `///` doc comments on the type and every method, explaining WHY and the invariants above.
- Tests: Swift Testing, deterministic. Same commit as the code.
- SCOPE: implement exactly what this prompt lists. No extra features (no prefetch scheduling, no
  caching, no async APIs). If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests, pasting the exact result lines, listing assumptions, and
  proposing the commit message. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- One primary type per file; file name == type name; ≤ 150 lines.
- The engine must be usable by any future list screen: no Book-specific code, no assumptions
  about 1-based vs 0-based beyond what the initialiser states.
```
