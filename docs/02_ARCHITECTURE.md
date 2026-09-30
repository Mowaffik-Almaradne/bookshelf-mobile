# 02 — Architecture

## Goals (in priority order)

1. **Correctness under hostile conditions**: slow/absent network, malformed payloads, rapid input.
2. **Testability without network**: every I/O boundary is a protocol; ViewModels are pure Swift.
3. **Small, readable, explainable**: a reviewer must understand the whole app in ~20 minutes.
4. **Modern, safe concurrency**: Swift 6 language mode, strict concurrency, no data races.
5. **Reusable building blocks** (HTTP client, paginator, image loader, state views) that are
   generic but not over-engineered.

Non-goals: multi-module SPM packages, Clean-Architecture ceremony (use-case classes for every
call), generic DI frameworks, Combine. These add ceremony without adding value at this size, and
the README should say so.

## Pattern: MVVM + Repository, feature-first

```
┌──────────────────────────────────────────────────────────────────────┐
│ Presentation (SwiftUI)                                               │
│   Views ──observe──▶ ViewModels (@MainActor @Observable)            │
└───────────────┬──────────────────────────────────────────────────────┘
                │ depends on protocols only
┌───────────────▼──────────────────────────────────────────────────────┐
│ Domain (pure Swift, Sendable value types)                            │
│   Book, BookDetails, ShelfBook, ReadingStatus, Paginator, AppError   │
│   protocols: BookCatalog, ShelfRepository, ImageLoading,             │
│              ConnectivityMonitoring                                  │
└───────────────┬──────────────────────────────────────────────────────┘
                │ implemented by
┌───────────────▼──────────────────────────────────────────────────────┐
│ Data                                                                 │
│   OpenLibraryBookCatalog (HTTPClient + DTOs + mappers)               │
│   SwiftDataShelfRepository (@Model entities, ModelContainer)         │
│   ImageLoader actor (URLSession + NSCache + URLCache + ImageIO)      │
│   NWPathMonitor-based ConnectivityMonitor                            │
└──────────────────────────────────────────────────────────────────────┘
```

**Dependency rule**: arrows point inward. `Presentation → Domain ← Data`. Presentation never
imports `Data` types; Data never imports SwiftUI. Domain imports only Foundation.

### Why MVVM (README answer, in short)

- SwiftUI is already a reactive view layer; `@Observable` ViewModels are the natural unit of
  presentation state and the natural unit of **unit testing** (Q3).
- Repository/service protocols give the **network-behind-a-protocol** boundary the task asks for (Q2)
  and let us swap SwiftData for an in-memory store in tests.
- Alternatives considered: **TCA-like** unidirectional (too much ceremony, and no 3rd-party libs);
  **MV (views + environment models only)** — simpler but state machines for search/pagination get
  buried in views and become untestable; **VIPER/Clean** — layered indirection unjustified for 5
  screens.

## Composition root

One `AppDependencies` (a plain `@MainActor final class`) is created in `BookShelfApp` and injected
via `.environment(...)`. It owns long-lived singletons (URLSession client, ModelContainer,
ImageLoader, ShelfStore, ConnectivityMonitor) and exposes factory methods for ViewModels:

```swift
@MainActor
final class AppDependencies {
    let catalog: any BookCatalog
    let shelf: ShelfStore                 // single source of truth for saved state
    let images: any ImageLoading
    let connectivity: any ConnectivityMonitoring

    static func live() throws -> AppDependencies { ... }      // production wiring
    static func preview() -> AppDependencies { ... }           // fakes for #Preview

    func makeSearchViewModel() -> SearchViewModel { ... }
    func makeDetailsViewModel(for book: Book) -> BookDetailsViewModel { ... }
}
```

No service locator, no property-wrapper DI, no singletons accessed statically from Views.

## State ownership

| State | Owner | Why |
|---|---|---|
| Search query, results, page cursor, phase | `SearchViewModel` | Screen-local, testable state machine |
| Details for one work | `BookDetailsViewModel` | Screen-local; merges local (saved) + remote |
| Saved books + `savedKeys: Set<String>` | `ShelfStore` (app-wide, `@Observable`) | **R4.4 cross-screen sync** — every screen reads the same object; no notifications/Combine needed |
| Image cache | `ImageLoader` actor | Shared, thread-safe by construction |
| Online/offline | `ConnectivityMonitor` (`@Observable`) | Drives banners and offline-first decisions |

`ShelfStore` is the *only* writer to persistence. ViewModels call `shelf.save(...)` /
`shelf.remove(...)` and read `shelf.isSaved(workKey)`. Because it is `@Observable`, SwiftUI views
depending on `isSaved` re-render automatically anywhere in the app.

## Concurrency model (Swift 6, "approachable concurrency")

Project already has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
`SWIFT_APPROACHABLE_CONCURRENCY = YES`. We set `SWIFT_VERSION = 6.0`.

Consequences and rules:

- **Everything is `@MainActor` by default** (views, view models, ShelfStore, AppDependencies). This
  is what we want for UI code and eliminates most `Sendable` friction.
- Types that must run off-main or be shared across actors are **explicitly** `nonisolated`
  or actors:
  - `actor ImageLoader` — cache + in-flight de-duplication.
  - `URLSessionHTTPClient: nonisolated final class, Sendable` — URLSession is thread-safe.
  - DTOs and domain models are `nonisolated struct ... : Sendable`.
- **CPU-heavy work must be `@concurrent`**. With approachable concurrency (SE-0461), a plain
  `nonisolated async func` runs on the *caller's* executor — i.e. on the main actor when called
  from a ViewModel. To guarantee off-main execution for JSON decoding and image downsampling, mark
  those functions `@concurrent nonisolated`. This is the single most common mistake in Xcode 26
  projects and the README/AI_NOTES should mention it (Q5).
- Cancellation is cooperative and **first-class**: every network call is inside a `Task` stored by
  the ViewModel; new query ⇒ `cancel()` previous ⇒ `URLSession` request is cancelled ⇒
  `CancellationError`/`URLError.cancelled` is swallowed, never shown (R1.3).
- No `DispatchQueue`, no `Combine`, no `@unchecked Sendable` unless justified in a comment.

## Folder structure (feature-first, layers inside)

```
BookShelf/
├── App/
│   ├── BookShelfApp.swift            // @main, creates AppDependencies
│   ├── AppDependencies.swift         // composition root
│   └── RootView.swift                // TabView: Search | Shelf
├── Core/                              // reusable, app-agnostic
│   ├── Networking/
│   │   ├── HTTPClient.swift          // protocol + URLSessionHTTPClient
│   │   ├── Endpoint.swift            // typed endpoint description
│   │   └── HTTPError.swift
│   ├── Images/
│   │   ├── ImageLoading.swift        // protocol
│   │   ├── ImageLoader.swift         // actor: memory+disk cache, in-flight dedupe
│   │   ├── ImageDownsampler.swift    // ImageIO thumbnail decoding (@concurrent)
│   │   └── RemoteImage.swift         // SwiftUI view, race-free
│   ├── Connectivity/
│   │   └── ConnectivityMonitor.swift // NWPathMonitor wrapper (@Observable)
│   ├── Logging/Log.swift             // os.Logger categories
│   └── Extensions/
├── Domain/
│   ├── Models/  Book.swift  BookDetails.swift  ShelfBook.swift  ReadingStatus.swift
│   ├── Errors/  AppError.swift
│   ├── Pagination/ Paginator.swift    // pure, generic, unit-tested
│   └── Services/ BookCatalog.swift  ShelfRepository.swift
├── Data/
│   ├── OpenLibrary/
│   │   ├── OpenLibraryEndpoints.swift
│   │   ├── DTO/  SearchResponseDTO.swift  WorkDTO.swift  AuthorDTO.swift  FlexibleText.swift
│   │   ├── Mapping/  Book+DTO.swift  BookDetails+DTO.swift
│   │   └── OpenLibraryBookCatalog.swift
│   └── Persistence/
│       ├── SavedBookEntity.swift     // @Model
│       ├── SwiftDataShelfRepository.swift
│       └── ModelContainer+App.swift  // live / inMemory factories
├── Features/                          // each: screen + view model + feature-only components
│   ├── Search/  SearchView.swift  SearchViewModel.swift  SearchPhase.swift
│   │            Components/ BookRow.swift  SearchStateViews.swift
│   ├── Details/ BookDetailsView.swift  BookDetailsViewModel.swift
│   │            Components/ DetailsHeaderView.swift  DescriptionSection.swift  SubjectsSection.swift
│   └── Shelf/   ShelfView.swift  ShelfViewModel.swift  ShelfStore.swift
│                Components/ ShelfRow.swift
├── UI/                                // app-agnostic: knows nothing about Book/Shelf/networking
│   ├── Components/  CoverView.swift  CoverPlaceholder.swift  ErrorStateView.swift
│   │                LoadingFooterView.swift  OfflineBanner.swift  SaveToggleButton.swift
│   │                InfoRow.swift  TagChip.swift  FlowLayout.swift  AdaptiveRowLayout.swift
│   ├── Presentation/ AppError+Presentation.swift   // error copy lives in UI, not Domain
│   └── Theme/  Spacing.swift  CoverSize.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings          // en + ar

BookShelfTests/
├── Support/   MockHTTPClient.swift  Fixtures.swift  InMemoryShelfRepository.swift  TestImageLoader.swift
├── Fixtures/  search_page1.json  search_page2_overlap.json  work_description_string.json
│              work_description_object.json  work_minimal.json  work_redirect.json  author.json
├── Decoding/  SearchResponseDecodingTests.swift  WorkDecodingTests.swift
├── Domain/    PaginatorTests.swift
├── Features/  SearchViewModelTests.swift  BookDetailsViewModelTests.swift  ShelfStoreTests.swift
└── Core/      ImageLoaderTests.swift
```

The Xcode project uses **file-system-synchronized groups** (`objectVersion = 77`), so files
created on disk inside `BookShelf/` are picked up automatically — no `.pbxproj` editing.
The **test target** must be added once via Xcode (File ▸ New ▸ Target ▸ Unit Testing Bundle,
name `BookShelfTests`, Swift Testing). See `13_IMPLEMENTATION_PLAN.md` Phase 0.

## Key contracts (the rest of the docs refine these)

```swift
// Domain/Services/BookCatalog.swift
nonisolated protocol BookCatalog: Sendable {
    func search(query: String, page: Int) async throws -> SearchPage
    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails
}

nonisolated struct SearchPage: Sendable, Equatable {
    let books: [Book]
    let page: Int
    let pageSize: Int
    let totalCount: Int?         // numFound; optional and may drift between pages — see 05
}

// Domain/Services/ShelfRepository.swift  (persistence boundary; ShelfStore wraps it)
@MainActor
protocol ShelfRepository {
    func fetchAll() throws -> [ShelfBook]
    func save(_ book: ShelfBook) throws
    func remove(workKey: WorkKey) throws
    func update(workKey: WorkKey, status: ReadingStatus) throws
}

// Core/Images/ImageLoading.swift
nonisolated protocol ImageLoading: Sendable {
    func image(for url: URL, targetSize: CGSize) async throws -> UIImage
}

nonisolated protocol ConnectivityMonitoring: Sendable {
    @MainActor var isOnline: Bool { get }
}
```

`WorkKey` is a tiny `struct WorkKey: Hashable, Sendable, Codable { let rawValue: String }` that
normalises `/works/OL45804W` and guarantees we never build URLs from arbitrary strings.

## Data flow examples

**Search (R1/R2)**
```
TextField ─▶ vm.query (didSet) ─▶ debounce Task(350ms) ─▶ cancel old task
   ─▶ phase = .loading ─▶ catalog.search(q, page 1) [network, decode @concurrent]
   ─▶ guard !Task.isCancelled && vm.currentQuery == q   (stale protection)
   ─▶ paginator.reset(); paginator.append(page) [dedupe] ─▶ phase = .loaded / .empty
List end ─▶ vm.loadNextPageIfNeeded(currentItem:) ─▶ paginator.canLoadMore && !isLoadingMore
   ─▶ catalog.search(q, page n+1) ─▶ append ─▶ phase updated
```

**Details (R3/R4.3)**
```
open ─▶ if shelf.saved(key) → show local details immediately (offline-safe)
     ─▶ if connectivity.isOnline → refresh from network, merge, (if saved) persist refreshed copy
     ─▶ else if not saved → .error(.offline) with Retry
Save ─▶ shelf.save(details + cover bytes) ─▶ savedKeys updated ─▶ Search rows re-render (R4.4)
```

## Decision log (copy the relevant rows into README)

| Decision | Chosen | Rejected | Why |
|---|---|---|---|
| UI framework | SwiftUI | UIKit | Declarative state → all 5 search states are trivially expressible; task is small |
| State mgmt | `@Observable` VMs + one app-wide store | Combine/`ObservableObject` | iOS 17 target; fine-grained observation, less boilerplate |
| Persistence | SwiftData | Core Data, JSON file | Native to iOS 17, `@Model` is compact; repository protocol hides it anyway |
| Persistence read path | Repository + store (domain models) | `@Query` in views | `@Query` couples views to SwiftData and can't be unit-tested through a protocol |
| Image disk cache | `URLCache` on a dedicated session + saved-cover bytes in SwiftData | custom FileManager cache | URLCache is Apple-native, honours HTTP caching; saved books need guaranteed offline covers → persisted `Data` |
| Language mode | Swift 6 + default MainActor isolation | Swift 5 | Compile-time data-race safety; shows platform depth |
| Debounce | `Task.sleep` + cancellation | Combine `.debounce` | No Combine; trivially testable via injected `Duration` |
| Pagination | Pure `Paginator` value type | logic inside VM | Deterministic unit tests (Q3-b) |
