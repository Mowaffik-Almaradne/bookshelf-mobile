# Prompt 09 — Phase 6: persistence, ShelfStore & the Shelf tab

**Attach:** `@docs/06_PERSISTENCE_AND_OFFLINE.md @docs/02_ARCHITECTURE.md @docs/08_UI_ACCESSIBILITY_LOCALIZATION.md @docs/09_TESTING.md @docs/12_CODE_STANDARDS.md`

**Carries:** R4.1 (shelf tab + delete), R4.2 (survives relaunch), R4.3 (offline, including
covers), R4.4 (save state synchronised across screens). `ShelfStore` being the single observable
source of truth is what makes R4.4 free instead of a notification mess.

**Commits:** 2 (`feat(shelf): SwiftData repository and observable store`,
`feat(app): tab root, dependency container, shelf screen`).

---

```
Phase 6 of docs/13_IMPLEMENTATION_PLAN.md: persistence, the shelf store, the Shelf screen, and
the real composition root. Implement exactly docs/06 and the AppDependencies design in docs/02.

APP FILES — Domain
- Domain/Services/ShelfRepository.swift
    `@MainActor protocol ShelfRepository` with fetchAll() throws -> [ShelfBook],
    fetch(workKey:) throws -> ShelfBook?, save(_:) throws (upsert), remove(workKey:) throws,
    update(workKey:status:) throws.

APP FILES — Data
- Data/Persistence/SavedBookEntity.swift
    `@Model final class SavedBookEntity` with @Attribute(.unique) workKey,
    @Attribute(.externalStorage) coverData, statusRaw stored as String (so adding a
    ReadingStatus case later needs no migration; unknown values fall back to .wantToRead),
    `bookDescription` (not `description`, which would clash with CustomStringConvertible),
    init(from: ShelfBook) and `func toDomain() -> ShelfBook?` returning nil for an invalid
    workKey so a corrupt row is skipped instead of crashing.
- Data/Persistence/ModelContainer+App.swift
    `static func live() throws -> ModelContainer` and `static func inMemory() throws -> ModelContainer`.
- Data/Persistence/SwiftDataShelfRepository.swift
    `@MainActor final class SwiftDataShelfRepository: ShelfRepository` over container.mainContext
    with `autosaveEnabled = false` and an explicit `try context.save()` after every mutation, so
    persistence is deterministic. Lookups use #Predicate with FetchDescriptor(fetchLimit: 1).
    fetchAll sorts by savedAt descending and drops rows whose toDomain() is nil.
    /// must justify mainContext: the shelf holds tens of rows, fetches are sub-millisecond, and
    this avoids cross-actor PersistentIdentifier handling; the protocol allows swapping in a
    @ModelActor later if it ever grows.

APP FILES — Feature
- Features/Shelf/ShelfStore.swift
    `@MainActor @Observable final class ShelfStore: SavedStateReading` — the single source of
    truth for saved state. Holds books, savedKeys: Set<WorkKey>, lastError: AppError?.
    - `isSaved(_:)` is O(1) via savedKeys (search rows call it for every visible row).
    - `save(_ details: BookDetails) async`: persist IMMEDIATELY without the cover so the UI
      responds instantly and the save works offline; then best-effort fetch the cover bytes via
      ImageLoading.imageData (usually already in URLCache because the row displayed it) and
      persist again. Failures set lastError and are logged, never thrown at the UI.
    - `remove(_:)`, `setStatus(_:for:)`, `saved(_:) -> ShelfBook?`,
      `refreshDetails(_:)` (updates a saved book's details after a successful online refresh).
    /// must explain why a store beats @Query in views: views stay free of SwiftData, the store
    is testable through a protocol, and isSaved is O(1).
- Features/Shelf/ShelfViewModel.swift — reads ShelfStore, exposes the list (filtering arrives in
  a later phase; keep it a trivial passthrough now, do not pre-build the filter).
- Features/Shelf/ShelfView.swift — screen: List with swipe `Button(role: .destructive)` delete,
  ContentUnavailableView empty state per docs/08, rows via a feature component.
- Features/Shelf/Components/ShelfRow.swift — reuses CoverView with `preloadedData:` (offline
  covers) and AdaptiveRowLayout; accessibility label composed per docs/08.

APP FILES — Composition root
- App/AppDependencies.swift — real wiring: `static func live() throws -> AppDependencies`
  (URLSessionHTTPClient → OpenLibraryBookCatalog, ModelContainer.live() →
  SwiftDataShelfRepository → ShelfStore, ImageLoader, connectivity placeholder) and
  `static func preview() -> AppDependencies` using in-memory persistence and stub services.
  Factory methods `makeSearchViewModel()` and `makeShelfViewModel()`.
- App/BookShelfApp.swift — build dependencies once; if ModelContainer.live() throws, fall back to
  inMemory(), log it, and surface a one-time alert explaining the shelf cannot be saved on this
  device. Never crash at launch.
- App/RootView.swift — real tabs; the Shelf tab shows `.badge(store.books.count)`.
- Wire SearchViewModel's SavedStateReading to the real ShelfStore so a save is reflected in
  search rows (R4.4).

TEST FILES
- Support/InMemoryShelfRepository.swift — a working fake conforming to ShelfRepository, for
  store tests that should not involve SwiftData at all.
- Support/TestImageLoader.swift — returns fixed bytes / throws on demand.
- Features/ShelfStoreTests.swift (7 tests from docs/06):
   1. save then isSaved is true and the book is listed
   2. saving twice is idempotent (unique constraint upsert, one row)
   3. remove updates both books and savedKeys
   4. save persists cover bytes when the loader provides them
   5. save without a cover still persists (offline save path)
   6. a second repository over the SAME container sees the book (persistence proxy for R4.2)
   7. a corrupt row (invalid workKey) is skipped by fetchAll, not crashed on
- Data/SwiftDataShelfRepositoryTests.swift — upsert uniqueness, sort order by savedAt desc,
  update(status:) persists, remove of a missing key does not throw.

ACCEPTANCE
- `rg -n "import SwiftData" BookShelf/Features BookShelf/UI` returns nothing except ShelfStore's
  file if unavoidable — it should NOT be needed there; report the grep output.
- Saving from anywhere updates search rows without any notification/Combine plumbing.
- All SwiftData tests use ModelContainer.inMemory(); no test writes to the real store.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'import SwiftData' BookShelf/Features BookShelf/UI || echo "no SwiftData outside Data layer"
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' BookShelf/ || echo "grep clean"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor.
- iOS 17.0 deployment target. Apple frameworks only: no packages, no Combine, no
  ObservableObject/@Published. Use @Observable, SwiftData, Swift Testing.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code,
  `AnyView`, hard-coded colours or font sizes, `@Query` in views, UserDefaults for domain data.
- Layering: Views never touch SwiftData; ViewModels never import SwiftUI or SwiftData; the
  @Model entity never escapes the Data layer.
- Every I/O dependency is a protocol injected through `init`.
- Every user-facing string localized (en + ar); every control has an accessibility label.
- `///` doc comments explaining WHY: mainContext choice, statusRaw, externalStorage, unique
  upsert, store-vs-@Query, the two-step save.
- Tests in the same commit; deterministic; in-memory containers only.
- SCOPE: implement exactly what this prompt lists. No reading-status UI yet, no iCloud sync, no
  export. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + greps, pasting the exact result lines, listing assumptions,
  and proposing two commit messages. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- SCREEN (ShelfView) = composition + navigation only; the row is a feature component; the cover
  and layout come from the UI kit — reuse, do not duplicate. Report what you reused.
- ShelfStore is the ONLY writer to persistence in the whole app.
- One primary type per file; ≤ 150 lines target, 250 hard limit.
```
