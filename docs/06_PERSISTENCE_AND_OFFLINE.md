# 06 — Persistence (SwiftData) & offline-first behaviour

Requirement links: R3.2, R4.1–R4.4, O1 (reading status), O3 (offline covers).

## Offline strategy in one paragraph

The **Shelf is the source of truth for everything the user cares about offline**. When a book is
saved we persist the *complete* `BookDetails` **plus the cover image bytes**, so Shelf and Details
of saved books never need the network (R4.3). Search results are not persisted (O2 is optional and
would use a separate, clearly-labelled snapshot). Connectivity is observed via `NWPathMonitor`
only to *inform* the UI and to skip a doomed refresh — never to gate reading local data.

## SwiftData model

```swift
import SwiftData

@Model
final class SavedBookEntity {
    @Attribute(.unique) var workKey: String
    var title: String
    var authors: [String]
    var bookDescription: String?          // `description` clashes with CustomStringConvertible
    var subjects: [String]
    var coverID: Int?
    var firstPublishYear: Int?
    var firstPublishDate: String?
    var savedAt: Date
    var statusRaw: String                 // ReadingStatus.rawValue — enums as raw for migration safety
    @Attribute(.externalStorage) var coverData: Data?

    init(from book: ShelfBook) { … }
    func toDomain() -> ShelfBook? { … }   // nil if workKey invalid — never crash on bad rows
}
```

Decisions:
- `@Attribute(.unique)` on `workKey` makes `save` an **upsert** — saving twice is idempotent.
- Arrays of `String` are supported natively by SwiftData (stored as transformable Codable).
- `.externalStorage` keeps cover blobs (~20–60 KB at `M`, up to ~300 KB at `L`) out of the main
  SQLite pages → fast list fetches.
- `statusRaw: String` instead of `ReadingStatus` directly: adding a case later is a no-op
  migration, and unknown values fall back to `.wantToRead`.
- Domain `ShelfBook` is a **struct**; the entity never leaks to Views or ViewModels.

### Container

```swift
extension ModelContainer {
    static func live() throws -> ModelContainer {
        try ModelContainer(for: SavedBookEntity.self)
    }
    static func inMemory() throws -> ModelContainer {
        try ModelContainer(for: SavedBookEntity.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
```

If `live()` throws (corrupt store — extremely rare), **fall back to `inMemory()` and log an error**
rather than crashing at launch; README documents this trade-off.

## `ShelfRepository` (persistence boundary) → `SwiftDataShelfRepository`

```swift
@MainActor
protocol ShelfRepository {
    func fetchAll() throws -> [ShelfBook]           // sorted by savedAt desc
    func fetch(workKey: WorkKey) throws -> ShelfBook?
    func save(_ book: ShelfBook) throws            // upsert
    func remove(workKey: WorkKey) throws
    func update(workKey: WorkKey, status: ReadingStatus) throws
}
```

`SwiftDataShelfRepository` uses `container.mainContext`. Rationale: the shelf holds tens, not
thousands, of rows — fetches are sub-millisecond, and main-context use avoids cross-actor
`PersistentIdentifier` juggling. If it ever grows, swap in a `@ModelActor` behind the same
protocol (that's the point of the protocol). `context.autosaveEnabled = false`; we call
`try context.save()` explicitly after each mutation so persistence is deterministic (R4.2).

`#Predicate` for lookups: `#Predicate<SavedBookEntity> { $0.workKey == key }` with
`FetchDescriptor(fetchLimit: 1)`.

## `ShelfStore` — app-wide observable façade (R4.4)

```swift
@MainActor @Observable
final class ShelfStore {
    private(set) var books: [ShelfBook] = []
    private(set) var savedKeys: Set<WorkKey> = []
    private(set) var lastError: AppError?

    private let repository: any ShelfRepository
    private let images: any ImageLoading

    init(repository: any ShelfRepository, images: any ImageLoading) {
        self.repository = repository; self.images = images
        reload()
    }

    func isSaved(_ key: WorkKey) -> Bool { savedKeys.contains(key) }

    func save(_ details: BookDetails) async {
        // 1. Persist immediately WITHOUT cover (instant UI feedback, works offline)
        var book = ShelfBook(details: details, savedAt: .now, status: .wantToRead, coverData: nil)
        persist(book)
        // 2. Best-effort: fetch cover bytes (from image cache if already shown) and update
        if let id = details.coverID, let url = CoverURL.url(coverID: id, size: .medium),
           let data = try? await images.imageData(for: url) {
            book.coverData = data
            persist(book)
        }
    }

    func remove(_ key: WorkKey) { … repository.remove …; reload() }
    func setStatus(_ status: ReadingStatus, for key: WorkKey) { … }
    func saved(_ key: WorkKey) -> ShelfBook? { books.first { $0.id == key } }

    private func persist(_ book: ShelfBook) {
        do { try repository.save(book); reload() }
        catch { lastError = .persistence; Log.persistence.error("save failed: \(error)") }
    }
    private func reload() {
        do { books = try repository.fetchAll(); savedKeys = Set(books.map(\.id)) }
        catch { lastError = .persistence }
    }
}
```

Why not `@Query` in views? `@Query` is great for pure-SwiftData apps, but it (a) makes Views know
the persistence framework (violates Q1-style layering), (b) can't be exercised through a protocol
in ViewModel tests, and (c) does not give us an O(1) `isSaved` for search rows. `ShelfStore` does
all three with ~60 lines.

Optimistic UI: `save`/`remove` update `books`/`savedKeys` synchronously after the repository
call; SwiftUI re-renders the Details button and every visible Search row on the same run loop
tick — no notifications, no Combine (R4.4).

## Details screen offline flow (R4.3)

```swift
@MainActor @Observable
final class BookDetailsViewModel {
    enum Phase: Equatable { case loading, loaded(BookDetails, source: Source), failed(AppError) }
    enum Source { case local, remote }

    let book: Book                                   // seed from search/shelf row
    private(set) var phase: Phase = .loading
    var isSaved: Bool { shelf.isSaved(book.key) }
    var isOffline: Bool { !connectivity.isOnline }

    func load() async {
        if let local = shelf.saved(book.key) {
            phase = .loaded(local.details, source: .local)       // instant, offline-safe
            guard connectivity.isOnline else { return }
            // background refresh; ignore failures silently (we already show data)
            if let fresh = try? await catalog.details(workKey: book.key, seedAuthors: book.authors) {
                phase = .loaded(fresh, source: .remote)
                await shelf.refreshDetails(fresh)                  // keep offline copy current
            }
            return
        }
        do {
            phase = .loaded(try await catalog.details(…), source: .remote)
        } catch let e as AppError where e == .cancelled {
        } catch {
            phase = .failed(AppError(error))
        }
    }

    func toggleSaved() async {
        if isSaved { shelf.remove(book.key) }
        else if case .loaded(let d, _) = phase { await shelf.save(d) }
        else { await shelf.save(BookDetails(seed: book)) }       // allow saving even if details failed
    }
}
```

Behaviours to demo in the video:
1. Save a book online → airplane mode → kill app → relaunch → Shelf shows it **with cover** →
   open details → full content, no spinner, no error.
2. Airplane mode → open a *non-saved* book → error state with **Retry** + offline banner.
3. Save from Details → back → row shows bookmark (R4.4).

## Connectivity monitor

```swift
@Observable @MainActor
final class ConnectivityMonitor: ConnectivityMonitoring {
    private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity"))   // NWPathMonitor requires a queue
    }
}
```

Use `isOnline` for banners and to skip network refreshes — **never** to block local reads.
Note: on the simulator, `NWPathMonitor` reflects the Mac's connectivity; toggling Wi-Fi on the
Mac is the way to demo. On device, airplane mode works directly.

## Optional O1 — Reading status

- `ShelfView` gets a segmented `Picker` (`All / Want to read / Reading / Finished`) bound to
  `ShelfViewModel.filter`; filtering is in-memory over `store.books`.
- Row context menu + Details menu: "Mark as Reading/Finished". Persisted via
  `repository.update(workKey:status:)`.
- Accessibility: status shown as text badge, not colour only; `accessibilityValue` on the row.
- Tests: `ShelfStoreTests.setStatus_persistsAndFilters`.

## Tests for this layer

`ShelfStoreTests` (in-memory container, `TestImageLoader` returning fixed bytes):

1. `save_thenIsSavedAndListed`
2. `save_twice_isIdempotent` (unique constraint)
3. `remove_updatesKeysAndList`
4. `save_persistsCoverBytesWhenAvailable` / `save_withoutCover_stillPersists`
5. `reload_fromSameStore_survives` — create a second repository over the **same** container and
   assert the book is there (R4.2 proxy in-process; the real relaunch is shown in the video)
6. `setStatus_persists`
7. `corruptRow_isSkippedNotCrash` — entity with invalid `workKey` → `fetchAll` drops it

`BookDetailsViewModelTests`:
1. `savedBook_offline_showsLocalWithoutNetwork` (catalog stub asserts it is **not** called)
2. `savedBook_online_refreshesAndUpdates`
3. `unsavedBook_offline_failsWithOfflineError`
4. `toggleSaved_fromLoaded_savesFullDetails`
