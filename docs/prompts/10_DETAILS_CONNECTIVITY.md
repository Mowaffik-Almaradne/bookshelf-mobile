# Prompt 10 — Phase 7: Details screen & connectivity

**Attach:** `@docs/06_PERSISTENCE_AND_OFFLINE.md @docs/08_UI_ACCESSIBILITY_LOCALIZATION.md @docs/11_ERROR_HANDLING_AND_LOGGING.md @docs/12_CODE_STANDARDS.md`

**Carries:** R3.1/R3.2 (details content and save toggle) and the offline half of R4.3 — a saved
book's details must render with **zero** network calls. The test that asserts the catalog is
never called for a saved book is the proof.

**Commits:** 2 (`feat(details): local-first details with save toggle`,
`feat(core): connectivity monitor and offline banner wiring`).

---

```
Phase 7 of docs/13_IMPLEMENTATION_PLAN.md: the Details screen and real connectivity.
Implement exactly the flow in docs/06 "Details screen offline flow" and the layout in docs/08
"BookDetailsView".

APP FILES
- Core/Connectivity/ConnectivityMonitor.swift
    `@MainActor @Observable final class ConnectivityMonitor: ConnectivityMonitoring` wrapping
    NWPathMonitor. Starts on a dedicated DispatchQueue (NWPathMonitor requires one — this is the
    single permitted DispatchQueue in the app; add a /// saying so). isOnline defaults to TRUE so
    the app never starts by claiming to be offline before the first path callback.
    Note in the /// that on the Simulator this reflects the Mac's connectivity, so offline demos
    need a real device or toggling the Mac's Wi-Fi.
- Features/Details/BookDetailsViewModel.swift  (@MainActor @Observable final class)
    `enum Phase: Equatable { case loading, loaded(BookDetails, source: Source), failed(AppError) }`
    with `enum Source { case local, remote }`.
    Injected: `any BookCatalog`, `ShelfStore` (or a narrow protocol), `any ConnectivityMonitoring`,
    and the seed `Book` from the list row.
    load():
      * if the book is saved → immediately show the LOCAL copy (no network call at all); then, if
        online, refresh in the background and on success update the phase and persist the
        refreshed copy via ShelfStore.refreshDetails. A failed refresh is SILENT — the local copy
        stays.
      * if not saved → fetch; on .cancelled do nothing; on other errors → .failed.
      * one automatic retry on .timeout / .server after 1 second, but only while not cancelled.
    toggleSaved(): remove when saved; otherwise save the loaded details; if details failed to
    load, still allow saving using the seed Book converted to BookDetails, so a user on a bad
    network is never blocked. Document this as an assumption.
    Must NOT import SwiftUI.
- Features/Details/BookDetailsView.swift  (screen: composition + navigation only)
    ScrollView composing: hero CoverView(.detail) centred, title `.title2.bold()`, authors,
    first published (InfoRow), the save toggle, description, subjects.
    `.task { await vm.load() }`. When the source is .local and offline, a `.footnote` caption
    "Showing saved copy". On .failed show ErrorStateView with Retry AND still offer the save
    button when seed data exists.
    iPad: content `.frame(maxWidth: 700)` centred.
- Features/Details/Components/DetailsHeaderView.swift — cover + title + authors + year block.
- Features/Details/Components/DescriptionSection.swift — description text with
  `.textSelection(.enabled)` and a "Read more" expander when longer than 8 lines; the expanded
  flag is view-local @State (this is legitimate view state, not domain state).
- Features/Details/Components/SubjectsSection.swift — subject chips via the UI kit's FlowLayout
  + TagChip, capped at 20 with a "+N more" chip.
- UI/Components/SaveToggleButton.swift — app-agnostic: inputs `isSaved: Bool`, `isEnabled: Bool`,
  `action: () -> Void`. Label and accessibility label/hint change with state per docs/08.
- Navigation: register `.navigationDestination(for: Book.self)` in BOTH tabs (Search and Shelf)
  pointing at BookDetailsView; add a `ShelfBook → Book` conversion so shelf rows can push the
  same screen. Replace the placeholder destination stub from Phase 4b.
- AppDependencies: wire the real ConnectivityMonitor into live(); keep a stub in preview().

TEST FILE — BookShelfTests/Features/BookDetailsViewModelTests.swift (the 4 tests in docs/06)
 1. a saved book while OFFLINE renders from local data and the catalog is NEVER called
    (assert the stub's call count is 0) — this is the R4.3 proof
 2. a saved book while online refreshes and updates the phase to .remote, and the refreshed
    details are persisted
 3. an unsaved book while offline fails with AppError.offline and the phase exposes Retry
 4. toggleSaved from a .loaded phase saves the FULL details (not just the seed)
Add a fifth: a failed details load still allows saving from the seed Book.

ACCEPTANCE
- No network call happens on the saved+offline path — proven by test 1, not by inspection.
- BookDetailsViewModel does not import SwiftUI; BookDetailsView contains no error-copy strings
  (they come from AppError+Presentation) and no networking.
- Both tabs can push the same details screen.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'import SwiftUI' BookShelf/Features/Details/BookDetailsViewModel.swift || echo "view model is UI-free"
rg -n 'DispatchQueue' BookShelf/ | rg -v 'ConnectivityMonitor' || echo "DispatchQueue only in the monitor"
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|Task\.detached' BookShelf/ || echo "grep clean"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor,
  approachable concurrency is ON: CPU-heavy work MUST be `@concurrent nonisolated`.
- iOS 17.0 deployment target. Apple frameworks only: no packages, no Combine.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code, `AnyView`,
  hard-coded colours or font sizes. DispatchQueue is permitted ONLY for NWPathMonitor's queue.
- Layering: Views never touch URLSession/SwiftData; ViewModels never import SwiftUI.
- Every I/O dependency is a protocol injected through `init`.
- Every user-facing string localized (en + ar); every control has an accessibility label; the
  save button's label AND hint change with state.
- `///` doc comments explaining WHY: local-first ordering, the silent refresh failure, the
  single automatic retry, the save-from-seed fallback, the simulator connectivity caveat.
- Tests in the same commit; deterministic; no real network.
- SCOPE: implement exactly what this prompt lists. No share sheet, no related-books, no ratings.
  If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + greps, pasting the exact result lines, listing assumptions,
  and proposing two commit messages. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- SCREEN (BookDetailsView) = composition only; the three sections are feature components taking
  plain values; SaveToggleButton and the chips/flow layout are app-agnostic UI kit pieces.
- Reuse CoverView, ErrorStateView, OfflineBanner, InfoRow, FlowLayout, TagChip,
  AppError+Presentation. Report which ones you reused; do not duplicate them.
- If a view body exceeds ~40 lines, extract a child View struct.
- One primary type per file; ≤ 150 lines target, 250 hard limit.
```
