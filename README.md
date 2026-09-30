# The Shelf (الرف) — BookShelf

Native iOS app: search Open Library, view details, save books to an offline-first reading shelf.  
SwiftUI · Swift 6 · SwiftData · iOS 17+ · Apple frameworks only · Swift Testing.

## Run

- **Xcode 26.x**, **iOS 17+** simulator or device. Open `BookShelf.xcodeproj`, scheme **BookShelf**, ⌘R.
- **Tests:** ⌘U or `./scripts/test.sh` (destination: iPhone 17 simulator — adjust the name if your Xcode install differs).
- **Setup:** no API keys, no SPM/CocoaPods, no manual config beyond opening the project.

## Demo

**TODO (required for submission):** add a 2–3 min screen recording link here covering search → pagination → details → save → shelf → airplane mode → Dynamic Type / Dark Mode. Record on device or simulator, then paste the URL.

## Architecture (why)

The app uses **MVVM + repository** with strict layering: SwiftUI views observe `@MainActor @Observable` view models; view models depend only on **domain protocols** (`BookCatalog`, `ShelfRepository`, `ImageLoading`, `ConnectivityMonitoring`); the **Data** layer implements those protocols with `URLSession`, Open Library DTOs/mappers, SwiftData, and an `ImageLoader` actor. Presentation never imports DTOs or touches `URLSession`/`SwiftData` directly, which keeps search/pagination/details testable offline (Q1, Q2).

**Cross-screen save state** lives in one **`ShelfStore`** (`savedKeys: Set<WorkKey>`), injected from `AppDependencies`. Search rows call `savedState.isSaved(_:)`; details calls `shelf.save` / `remove`. Because the store is `@Observable`, bookmark indicators and the shelf tab update without Combine or notifications (R4.4).

**Swift 6 concurrency:** default **MainActor** isolation covers UI and view models. Network I/O uses a `nonisolated` `URLSessionHTTPClient`. CPU-heavy JSON and image work uses **`@concurrent`** on `JSONDecoding.decode` and `ImageDownsampler.downsample` so decoding does not inherit the main actor when called from a view model (SE-0461 / approachable concurrency, Q5).

```
┌──────────────────────────────────────────────────────────────────────┐
│ Presentation (SwiftUI)                                               │
│   Views ──observe──▶ ViewModels (@MainActor @Observable)            │
└───────────────┬──────────────────────────────────────────────────────┘
                │ depends on protocols only
┌───────────────▼──────────────────────────────────────────────────────┐
│ Domain (pure Swift, Sendable value types)                            │
│   Book, BookDetails, ShelfBook, Paginator, AppError                  │
│   protocols: BookCatalog, ShelfRepository, ImageLoading, …           │
└───────────────┬──────────────────────────────────────────────────────┘
                │ implemented by
┌───────────────▼──────────────────────────────────────────────────────┐
│ Data                                                                 │
│   OpenLibraryBookCatalog · SwiftDataShelfRepository · ImageLoader    │
│   ConnectivityMonitor                                                │
└──────────────────────────────────────────────────────────────────────┘
```

Composition root: `AppDependencies` in `BookShelfApp` — factories for `SearchViewModel`, `BookDetailsViewModel`, shared `ShelfStore`, and `.environment(\.imageLoader)`.

## Key decisions & alternatives not chosen

| Decision | Chosen | Rejected | Why (one line) |
|---|---|---|---|
| UI framework | SwiftUI | UIKit | Small surface; five search states map cleanly to a single `SearchPhase` enum |
| State mgmt | `@Observable` VMs + `ShelfStore` | Combine / `ObservableObject` | iOS 17 target; no third-party libs; fine-grained observation |
| Persistence | SwiftData + repository | Core Data, JSON file | Native `@Model`; protocol hides storage from domain |
| Persistence reads | `ShelfRepository` + `ShelfStore` | `@Query` in views | Keeps SwiftUI out of persistence and enables in-memory tests |
| Image disk cache | `URLCache` on dedicated sessions + cover `Data` in SwiftData | Custom FileManager cache | Apple-native HTTP cache; saved books need guaranteed offline bytes |
| Debounce | `Task.sleep` + cancel | Combine `.debounce` | No Combine; injectable `Duration` in tests |
| Pagination logic | Pure `Paginator` value type | Logic only in VM | Deterministic unit tests (Q3-b) |
| Cover loading UI | `RemoteImage` + `ImageLoader` actor | `AsyncImage` | Downsampling, URLCache, offline bytes, url/data-keyed race guards (R5.2) |
| Search errors | User taps **Retry** only | Automatic search retry loop | Avoids hammering Open Library; cancellation stays silent (R1.3) |
| Details fetch | One automatic retry on `.timeout` / `.server` | Unlimited retries | Transient blips only; failures stay silent for saved local copy |

## How the hard requirements are met

| Requirement | Where | How |
|---|---|---|
| Debounce / min length (R1.1–2) | `SearchViewModel.queryDidChange` | `Task.sleep(for: debounce)` (default 350 ms) + task cancel; `minimumQueryLength == 3` |
| Stale results (R1.3) | `SearchViewModel.performSearch`, `startNextPageIfPossible` | `generation` token compared after every `await`; tasks cancelled on query change |
| Pagination: no dupes / no double request / end (R2) | `Paginator` | `seenIDs`; in-flight guard; short-page rule; **full page with zero fresh IDs ends the list** |
| Offline shelf & details (R4.3) | `ShelfStore`, `BookDetailsViewModel.load`, `CoverView` | SwiftData stores full details + `coverData`; local-first load; `allowsNetwork` skips remote covers offline |
| Cross-screen sync (R4.4) | `ShelfStore.savedKeys` | Single `@Observable` store; `BookRow(isSaved:)` from `SearchViewModel.isSaved` |
| Wrong image on reuse (R5.2) | `RemoteImage`, `CoverView` | URL-keyed remote state; Data-keyed preloaded state; `.task(id:)` + post-await cancel checks |
| Main thread free for CPU work (Q5) | `JSONDecoding.decode`, `ImageDownsampler.downsample` | Both marked `@concurrent nonisolated` |

## Two hardest parts (in my words)

**Swift 6 isolation and `@concurrent`:** With default MainActor isolation and approachable concurrency, a plain `nonisolated async` decode still runs on the caller’s executor (often the main actor). JSON and ImageIO work had to be explicitly `@concurrent` so Time Profiler does not show `JSONDecoder` / `CGImageSource` on the main thread during scroll.

**Pagination end detection:** Open Library’s `numFound` can drift, and pages can fully overlap. End-of-list uses `Paginator.computeHasMore` (short page always stops) **plus** ending when a full page contributes zero new IDs after dedupe — otherwise prefetch loops forever while totals still look larger.

## Assumptions

- Save/remove control is on **Details** (`SaveToggleButton`); search rows show a **bookmark indicator** only (`BookRow`).
- A book can be saved from **seed search data** when details fail (`BookDetailsViewModel.toggleSaved` → `BookDetails(seed:)`).
- Refresh of saved books online is **silent** on failure; local copy stays authoritative offline.
- Author names prefer search seeds; work → author fetches are best-effort in `OpenLibraryBookCatalog`.
- **Search results are not cached offline** (O2 not implemented); the shelf is the offline surface.
- Publish **years** use `.formatted(.number.grouping(.never))` in details/shelf rows (no locale digit grouping).
- Open Library cover URLs use `?default=false` so missing covers 404 instead of a generic image (`CoverURL`).
- Corrupt SwiftData rows are skipped on load, not fatal (`ShelfStore` / repository tests).
- Reading status (O1) is changed via the shelf row **context menu**; filter lives in the shelf toolbar.

## Testing

**Mandated areas (Q3):**

1. **Search screen states** — `SearchViewModelTests` (idle, loading, loaded, empty, failed, stale guard, pagination footer, R4.4 via `ShelfStore`).
2. **Pagination** — `PaginatorTests` (dedupe, in-flight guard, short-page end, all-dupe full page ends, prefetch threshold).
3. **Details decoding shapes** — `WorkDecodingTests`, `SearchResponseDecodingTests` (string vs object description, legacy authors, missing keys).

**Also covered:** HTTP client, `AppError` mapping, catalog, SwiftData repository, `ShelfStore`, `ShelfViewModel` filter, `BookDetailsViewModel`, `ImageLoader`, `CoverLoadPolicy`.

**Run:** `./scripts/test.sh` or `xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests`.

**Why Swift Testing:** `@Test` / `#expect`, parameterized cases, async tests without XCTest boilerplate; fixtures under `BookShelfTests/Fixtures/` are trimmed from real Open Library JSON.

## Accessibility & localization

- **VoiceOver:** combined labels on `BookRow` / `ShelfRow`; `Label` + `.labelStyle(.iconOnly)` on icon actions; loading/error/footer controls expose labels and hints.
- **Dynamic Type:** `AdaptiveRowLayout` stacks cover above text at accessibility sizes; previews use `.dynamicTypeSize(.accessibility3)`.
- **Dark Mode:** semantic system colors only (no hard-coded RGB).
- **Arabic + RTL:** strings in `Resources/Localizable.xcstrings` (en + ar).
- **iPad:** details content capped with `ContentWidth.details` (700 pt); not a full split-view layout (O4 partial).

## Performance notes

- **Downsampling:** `ImageDownsampler` uses ImageIO thumbnail API at target pixel size.
- **Decode off main:** `@concurrent` on JSON and image decode.
- **Caches:** Open Library JSON — URLCache 10 MB memory / 50 MB disk; covers session — 0 MB memory / **150 MB** disk, `waitsForConnectivity = false`; `ImageLoader` NSCache default **64 MB**; saved cover bytes in SwiftData `externalStorage`.

## Time spent (≈ 16 h budget)

| Phase | Estimated | Actual | Notes |
|---|---|---|---|
| 0 | 0.75 | ~0.75 | Hygiene, test target |
| 1 | 1.5 | ~1.5 | HTTP client |
| 2 | 2.0 | ~2.0 | Domain + Open Library |
| 3 | 0.75 | ~0.75 | Paginator |
| 4a | 0.75 | ~0.75 | UI kit |
| 4b | 1.75 | ~1.75 | Search feature |
| 5 | 1.5 | ~1.5 | Images |
| 6 | 2.0 | ~2.0 | Shelf + SwiftData |
| 7 | 1.5 | ~1.5 | Details + connectivity |
| 8 | 1.0 | ~1.0 | A11y + l10n |
| 9 | 0.75 | ~0.75 | Reading status filter + context menu |
| 10 | 0.75 | ~1.25 | Hardening + grade fixes (dupe end, CoverView) |
| 11 | 1.0 | ~1.0 | README, AI_NOTES (video still human) |
| **Total** | **16.0** | **~16.5** | Slightly over on hardening / grade fixes |

## What's missing / next day

- **D5:** demo video link (see Demo section) — **must add before submit**.
- **O2:** stale last search results when offline (not cached).
- **O4:** iPad split view / multi-column shelf — only centered details width today.
- **CI:** none; `./scripts/test.sh` is the gate.
- **Manual QA log:** Network Link Conditioner + Instruments + VoiceOver on a real device — run once and note pass/fail in `docs/AI_LOG.md` if reviewers ask.

## Requirement coverage

| ID | Status | Notes |
|---|---|---|
| R1–R5, Q1–Q6 | ✅ | See table above |
| O1 reading status + filter | ✅ | Toolbar filter + context menu on shelf rows |
| O2 offline search cache | ⚠️ | Not implemented |
| O3 Arabic + offline covers | ✅ | Catalog + `coverData` + `allowsNetwork` |
| O4 iPad layout | ⚠️ | Width constraint only |
| D3 README / D4 AI_NOTES | ✅ | This file + `AI_NOTES.md` |
| D5 video | ⚠️ | TODO link |

## AI usage

See **`AI_NOTES.md`**. Planning documents and the phase prompt pack live in **`docs/`**.
