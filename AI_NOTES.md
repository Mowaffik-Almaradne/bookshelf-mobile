# AI notes

## Tools

- **Cursor (Agent mode, Composer)** — scaffolding and implementation driven by `docs/prompts/` (networking → domain/data → search → images → shelf → details → hardening → deliverables).
- **Xcode** — iOS 17 / Swift 6 target settings, simulator QA, signing.
- **Independent grading** — `docs/prompts/92_GRADE.md` adversarial pass; findings fixed in a follow-up hardening pass (paginator end rule, `CoverView` race, offline cover policy).

**Not AI-written (human-owned):** final hours below, demo video link, Instruments / Network Link Conditioner / VoiceOver device passes, bundle ID and reviewer invites.

## Workflow

1. Read **`docs/01_TASK_SPEC.md`** and architecture docs (`docs/02`–`docs/12`).
2. Execute **one prompt per phase** in `docs/prompts/` (02 → 13).
3. After each phase: **build + unit tests** (`./scripts/test.sh` or ⌘U) and forbidden-pattern grep from `docs/prompts/00_SHARED_RULES.md`.
4. **Review / fix** via `90_REVIEW.md` / `91_FIX.md` when something fails.
5. **Commit** logical slices (see `docs/13_IMPLEMENTATION_PLAN.md`); Phase 11 is README + AI_NOTES + video.

Running notes: **`docs/AI_LOG.md`**. This file is the curated summary for graders (D4).

## Three prompts that mattered

### 1. Phase 10 — Hardening (`docs/prompts/13_HARDENING.md`)

- **Prompt:** Hostile review + fixes for pagination cancel, error UX, and regression tests.
- **Output:** Findings table; fixes for pagination stuck after cancel (R2.4), cancelled first-page spinner, `ShelfStore.lastError` alert, “Showing saved copy” when online refresh fails, search Retry gated on `AppError.isRetryable`; test `whitespaceDuringPageLoad_doesNotStickPagination`.
- **What I changed:** Rejected a draft that called `failLoading()` on every generation mismatch during page loads — that could clear a **newer** in-flight page lock and allow duplicate page requests. Kept `failLoading()` only in `cancelInFlightAndBumpGeneration` and same-generation cancel paths (`SearchViewModel`).

### 2. Phase 3 — Pagination (`docs/prompts/05_PAGINATION.md`)

- **Prompt:** Pure `Paginator` value type, short-page end rule, overlap fixtures, in-flight guard.
- **Output:** `Paginator` + `PaginatorTests` covering dedupe, `beginLoadingIfNeeded`, short-page end, prefetch threshold.
- **What I changed:** Did not trust `numFound` alone (`computeHasMore`). After independent grading, also ended the list when a **full page yields zero fresh IDs** — otherwise overlapping Open Library windows + a large total kept `hasMore == true` forever while the list never grew. Test: `append_allDuplicates_returnsEmptyAndEndsList`.

### 3. Phase 5 — Images (`docs/prompts/08_IMAGES.md`)

- **Prompt:** `ImageLoader` actor, ImageIO downsampling, `RemoteImage` race guard; reject `AsyncImage`.
- **Output:** Actor loader with in-flight dedupe, `@concurrent` downsample, url-keyed `RemoteImage`.
- **What I changed:** Applied the same structural race guard to the **offline** path in `CoverView` (pair image with `Data`, check `!Task.isCancelled`). Added `allowsNetwork` / `CoverLoadPolicy` so airplane mode never starts a cover URL request when bytes are missing.

## Where the AI was wrong (and how I noticed)

From **`docs/AI_LOG.md` Phase 10** (verified in code):

- **Wrong:** Clearing pagination in-flight state on **every** generation mismatch after a page `await`.
- **Right:** On stale generation after page fetch, **do not** call `paginator.failLoading()` — only `cancelInFlightAndBumpGeneration` (sync on main) and same-gen cancel paths release `isLoading`.
- **How I noticed:** Reasoning about interleaving (whitespace-only query edit during page load); regression test `SearchViewModelTests/whitespaceDuringPageLoad_doesNotStickPagination`.

From **independent grade (`92_GRADE.md`)**:

- **Wrong / incomplete:** Claiming R2.4 and R5.2 were fully solved while (1) all-duplicate full pages never set `hasMore = false`, and (2) `CoverView.preloadedImage` had no data-keyed bind.
- **How I noticed:** Grader attack matrix with file:line; reproduced with unit tests that fail before the fix.

**Other mistakes this repo guards against:**

- Claiming `nonisolated async` decode runs off-main → `@concurrent` on `JSONDecoding` / `ImageDownsampler`.
- Suggesting `@unchecked Sendable` on the HTTP client → rejected; `URLSessionHTTPClient` is a `nonisolated final class` with an immutable session.
- Suggesting `AsyncImage` → rejected; custom loader + `RemoteImage` / offline `CoverView` path.

## What I learned (Swift / iOS)

- Default **MainActor** isolation + **approachable concurrency (SE-0461)** — caller executor inheritance and when `@concurrent` is required so JSON/ImageIO stay off the UI thread.
- **Swift Testing** parameterized and async view-model tests without sleeps for synchronisation (`waitUntil` + `Task.yield`).
- **SwiftData** `externalStorage` for cover bytes; upsert by unique `workKey`; fall back to in-memory container if the on-disk store will not open.
- **ImageIO** thumbnail downsampling vs decoding full images into memory.
- **Open Library** quirks: description string vs object, drifting `numFound`, `-1` cover ids, `?default=false` on covers, full-page ID overlap that must end pagination.
