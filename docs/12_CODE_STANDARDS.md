# 12 — Code standards, review checklist & git conventions

These rules apply to every file the AI agent or you write. Paste the "Non-negotiables" block into
every implementation prompt (see `14_PROMPTS.md`).

## Non-negotiables (paste into prompts)

```
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor.
- Apple frameworks only. No SPM packages, no CocoaPods, no Combine.
- iOS 17.0 deployment target. Use iOS 17 APIs (@Observable, SwiftData, ContentUnavailableView, .task(id:)).
- No force unwrap (`!`), no `try!`, no `as!`, no `fatalError` on runtime data. Arrays via .first, not [0].
- Views never touch URLSession/SwiftData/UIKit networking; ViewModels never import SwiftUI.
- Every I/O dependency behind a protocol, injected via init (constructor injection). No singletons accessed from Views.
- CPU-heavy work (decode, image processing) is `@concurrent nonisolated`.
- All user-facing strings localized via String Catalog (en + ar). Semantic colours & system fonts only.
- Every interactive control has an accessibility label; icon-only controls use Label + .labelStyle(.iconOnly).
- Public types and non-obvious decisions get a `///` doc comment explaining WHY, not what.
- Files ≤ ~250 lines; one primary type per file; file name == type name.
- Tests for every piece of logic touched, using Swift Testing. Fixtures from real API responses.
- Do not add features, files or abstractions not requested. Do not refactor unrelated code.
- After changes: build, run tests, run the forbidden-pattern grep, and report results.
```

## Naming

| Thing | Convention | Example |
|---|---|---|
| Protocols (capability) | `-ing` / noun | `ImageLoading`, `HTTPClient`, `BookCatalog`, `ShelfRepository` |
| Live implementations | Technology prefix | `URLSessionHTTPClient`, `SwiftDataShelfRepository`, `OpenLibraryBookCatalog` |
| Test doubles | `Stub`(scripted) / `Mock`(records) / `Fake`(working impl) | `StubCatalog`, `MockHTTPClient`, `InMemoryShelfRepository` |
| DTOs | `…DTO` suffix, live only in `Data/` | `WorkDTO` |
| Domain models | plain nouns | `Book`, `BookDetails`, `ShelfBook` |
| ViewModels | `…ViewModel`, `@MainActor @Observable final class` | `SearchViewModel` |
| Views | `…View` for screens, noun for components | `SearchView`, `BookRow`, `CoverView` |
| State enums | `Phase` nested or `…Phase` | `SearchPhase`, `BookDetailsViewModel.Phase` |
| Async functions | verb, no `Async` suffix | `func search(query:page:)` |
| Booleans | `is/has/should/can` | `isSaved`, `hasMore`, `shouldPrefetch` |
| Files | `TypeName.swift`; extensions `Type+Purpose.swift` | `Book+DTO.swift` |

## File header

No Xcode boilerplate header (delete the "Created by … on 18/04/1448 AH" comments). Files start
with imports. Authorship lives in git.

## Access control

- `private` by default for stored properties and helpers; `private(set)` for observable outputs.
- Internal (default) for types — single module, no `public`.
- `final` on every class unless subclassing is intended (it never is here).

## Structure inside a type

```swift
@MainActor @Observable
final class SearchViewModel {
    // MARK: - Output state
    // MARK: - Dependencies
    // MARK: - Private state
    // MARK: - Init
    // MARK: - Intents (public funcs the view calls)
    // MARK: - Private
}
```

Views: `body` first, then `@ViewBuilder` sub-views as private computed properties, then helpers.
Prefer extracting a sub-view **struct** when a section has its own state or exceeds ~30 lines.

## Comments

- `///` on every type and on protocol requirements. Explain the *why* and the *invariants*
  ("Generation token guards against stale results that finished decoding after cancellation").
- Inline `//` only for non-obvious lines. No commented-out code. No TODOs without an owner and a
  README mention.
- Every `try?` has a trailing comment: `// best-effort: names fall back to search seed`.
- Every `@unchecked Sendable`/`nonisolated(unsafe)` (tests only) has a justification comment.

## SwiftUI specifics

- `@State` only for view-local UI state (expanded/collapsed). Domain state lives in ViewModels.
- Inject dependencies with `@Environment(AppDependencies.self)` at screen roots; components take
  plain values.
- `#Preview` for every screen state using `AppDependencies.preview()`; previews must compile
  (they are part of the build in CI via `xcodebuild build`... they are not, but keep them healthy).
- No `GeometryReader` unless unavoidable; use `Layout`/`ViewThatFits`/`containerRelativeFrame`.
- Prefer `Button(role:)`, `Label`, `ContentUnavailableView`, `.searchable`, `.badge`, `.swipeActions`
  — system components carry accessibility for free.

## Forbidden

`!` unwrap · `try!` · `as!` · `fatalError` on data · `print` · `DispatchQueue` · `Combine` ·
`ObservableObject`/`@Published` · `Task.detached` · `@unchecked Sendable` (app code) ·
`AnyView` · `UserDefaults` for domain data · string-built URLs with user input · `Date()` in
logic without injection (use `Date.now` via injected `() -> Date` where testing needs control —
`savedAt` only, so a default parameter `now: Date = .now` suffices).

## Review checklist (run before each commit; the agent must self-report against it)

Correctness
- [ ] Builds with zero warnings (`xcodebuild build -quiet` shows none).
- [ ] All tests green (`xcodebuild test`).
- [ ] Forbidden-pattern grep clean (see 11).
- [ ] Requirement IDs touched by this change are listed in the commit body.

Design
- [ ] New type is in the right layer (Core / Domain / Data / Features / UI).
- [ ] No layer-violation imports (Domain imports Foundation only; Features never import SwiftData).
- [ ] Every new dependency is a protocol + injected.
- [ ] No duplicated logic (search `rg` for a similar function before adding one).

Concurrency
- [ ] No new warnings; no `@unchecked`; heavy work `@concurrent`.
- [ ] Tasks stored & cancelled; `.cancelled` never surfaces.

UI & a11y
- [ ] Labels on all controls; Dynamic Type preview at `.accessibility3` looks right; dark preview fine.
- [ ] Strings localized (en + ar entries present in catalog).

Tests
- [ ] New logic has tests; fixture-based where JSON is involved.
- [ ] No sleeps; deterministic.

Docs
- [ ] `///` on new public-ish types; README decision log updated if a decision was made.
- [ ] AI_NOTES running log updated (prompt used, correction made) — see `15_DELIVERABLES.md`.

## Git conventions (D2)

- Branch: `main` only (small solo task). Optionally short-lived feature branches merged fast-forward.
- Conventional commits, imperative, ≤ 72 chars subject, body explains *why* + requirement IDs:

```
feat(search): debounce queries and drop stale results

Cancels the in-flight task on every keystroke and guards result
application with a generation token, so a slow response for an old
query can never overwrite results of the newer one.

Refs: R1.1, R1.2, R1.3
```

Types: `feat`, `fix`, `test`, `refactor`, `perf`, `docs`, `chore`, `a11y`, `l10n`.

- One logical step per commit (see the 20-ish commit plan in `13_IMPLEMENTATION_PLAN.md`).
- Never commit: `xcuserdata/`, `.DS_Store`, `DerivedData`, `*.xcuserstate`. `.gitignore` is part of
  Phase 0.
- Commit **tests with the code they test**, not in a separate "add tests" commit at the end
  (reviewers read history; "tests written alongside" is a senior signal).
- Don't rewrite history after pushing.

## Definition of Done (per phase)

A phase is done when: the build is warning-free, tests pass, previews compile, the review checklist
above is ticked, the commit is made with a conventional message, and any decision/assumption is
recorded in the README draft and AI_NOTES log.
