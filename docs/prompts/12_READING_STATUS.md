# Prompt 12 — Phase 9: reading status (optional feature O1)

**Attach:** `@docs/06_PERSISTENCE_AND_OFFLINE.md @docs/08_UI_ACCESSIBILITY_LOCALIZATION.md @docs/12_CODE_STANDARDS.md`

**Only run this if the core is complete and green.** The task says one optional feature done well
beats four half-done, and no marks are lost for skipping extras. If you are over budget, skip
this and write it in the README's "what's missing" section instead.

`ReadingStatus` and the `statusRaw` column already exist from Phase 6, so this is a thin
vertical slice — which is exactly why it was chosen as the extra.

**Commit:** 1 (`feat(shelf): reading status with filtering`).

---

```
Phase 9 of docs/13_IMPLEMENTATION_PLAN.md: optional feature O1, reading status per shelf book
with filtering. The ReadingStatus enum and the persisted statusRaw column already exist — do not
change the schema.

APP FILES
- Data/Persistence/SwiftDataShelfRepository.swift — ensure `update(workKey:status:)` is
  implemented and saves explicitly (it may already be).
- Features/Shelf/ShelfStore.swift — `setStatus(_:for:)` persisting through the repository and
  refreshing the in-memory list.
- Features/Shelf/ShelfViewModel.swift — add `enum Filter: CaseIterable { all, wantToRead,
  reading, finished }`, a `filter` property, and `filteredBooks` computed in memory over
  store.books. Keep the filtering pure and trivial; no fetch predicates.
- Features/Shelf/ShelfView.swift — a segmented Picker bound to the filter, shown only when the
  shelf is not empty. When a filter yields no books, show a distinct empty state naming the
  filter (not the generic "your shelf is empty").
- UI/Components/ReadingStatusBadge.swift — app-agnostic: inputs `title: LocalizedStringKey`,
  `systemImage: String`. Text + icon, never colour alone (colour-blind users), semantic colours.
- Features/Shelf/Components/ShelfRow.swift — show the badge; add a context menu to change status.
- Features/Details/BookDetailsView.swift — when the book is saved, a Menu (or Picker) to change
  its status, using the same localized titles.
- Localization: add the three status names and the filter titles to the String Catalog with
  Arabic (أنوي قراءته / أقرأه الآن / انتهيت منه).
- Accessibility: the row's `.accessibilityValue` announces the status; the badge itself is not a
  separate element; the status menu items have clear labels.

TEST FILES
- Features/ShelfStoreTests.swift — add: setStatus persists and survives a repository reload;
  setStatus on a missing key does not throw or corrupt the list.
- Features/ShelfViewModelTests.swift — filtering returns exactly the matching books for each
  filter case; `all` returns everything in savedAt-descending order; an empty filter result is
  distinguishable from an empty shelf.

ACCEPTANCE
- Default status for a newly saved book is .wantToRead.
- An unknown persisted status string falls back to .wantToRead without crashing (there should
  already be a test or guard from Phase 6 — verify it still holds).
- No schema change, no migration needed.
- Filtering is in-memory; the repository API did not need to grow.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|Task\.detached' BookShelf/ || echo "grep clean"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor.
- iOS 17.0 deployment target. Apple frameworks only: no packages, no Combine.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `print`,
  `Task.detached`, `@unchecked Sendable` in app code, `AnyView`, hard-coded colours or font
  sizes, status conveyed by colour alone.
- Layering unchanged: Views never touch SwiftData; ShelfStore remains the only writer.
- Every new string localized (en + ar); every new control has an accessibility label.
- `///` doc comments on the new types explaining WHY (raw-value storage, in-memory filtering).
- Tests in the same commit; deterministic.
- SCOPE: implement exactly this feature. No sorting options, no progress tracking, no dates
  read, no statistics. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + grep, pasting the exact result lines, listing assumptions,
  and proposing the commit message. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- The badge is app-agnostic and lives in UI/Components; the mapping from ReadingStatus to its
  title/icon lives in a UI presentation extension, not inside the Domain enum.
- Reuse the existing row and empty-state components; do not fork them for the filtered case.
- One primary type per file; ≤ 150 lines target, 250 hard limit.
```
