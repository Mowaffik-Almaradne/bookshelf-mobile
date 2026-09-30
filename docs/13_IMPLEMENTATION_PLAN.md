# 13 — Implementation plan (16 h budget, phased, commit-by-commit)

Each phase = one prompt in [`prompts/`](prompts/README.md) = 1–3 commits. Track actual hours in
the table at the bottom and in [`AI_LOG.md`](AI_LOG.md); the README needs "approximate hours per
part" (D3) and honesty here scores points.

**Order rationale**: core value path first (search → details → shelf), each phase shippable and
tested, so if the 16 h cap hits, what exists is complete and the README can list the rest.

| Phase | Scope | Est. | Cum. | Commits |
|---|---|---|---|---|
| 0 | Project hygiene: deployment target 17.0, Swift 6, `.gitignore`, test target, shared scheme, folders, String Catalog, remove template code | 0.75 h | 0.75 | 2 |
| 1 | Core networking: `Endpoint`, `HTTPClient`, `URLSessionHTTPClient`, `HTTPError`, `JSONDecoding`, `AppError` + mapping, `Log` — with tests | 1.5 h | 2.25 | 2 |
| 2 | Domain + Data: models, `WorkKey`, `CoverURL`, DTOs (`FlexibleText`, `AuthorRefDTO`), mappers, `OpenLibraryBookCatalog` (search + details + author names + redirect) — with fixture tests (Q3-c) | 2.0 h | 4.25 | 2 |
| 3 | `Paginator` + tests (Q3-b) | 0.75 h | 5.0 | 1 |
| 4a | Design system: app-agnostic component kit (covers, error/loading/offline states, chips, flow layout, adaptive rows) + error copy, with previews | 0.75 h | 5.75 | 1 |
| 4b | Search feature: `SearchPhase`, `SearchViewModel` (debounce, stale guard, pagination), `SearchView`, `BookRow`, state views — with tests (Q3-a) | 1.75 h | 7.5 | 2 |
| 5 | Images: `ImageLoader` actor, downsampler, `RemoteImage`, `CoverView`, placeholder — with tests | 1.5 h | 9.0 | 1 |
| 6 | Persistence & shelf: `SavedBookEntity`, `SwiftDataShelfRepository`, `ShelfStore`, `ShelfView`, Root `TabView`, `AppDependencies` — with tests | 2.0 h | 11.0 | 2 |
| 7 | Details: `BookDetailsViewModel` (local-first, refresh, save toggle), `BookDetailsView`, connectivity monitor, offline banner — with tests | 1.5 h | 12.5 | 2 |
| 8 | Accessibility, Dynamic Type, Dark Mode, localization (ar), RTL, iPad width | 1.0 h | 13.5 | 1–2 |
| 9 | Optional O1 reading status (+ offline covers already done in 6) | 0.75 h | 14.25 | 1 |
| 10 | Hardening: Network Link Conditioner pass, Instruments pass, grep gates, edge cases found, previews | 0.75 h | 15.0 | 1 |
| 11 | README, AI_NOTES, video, final self-grade with `16_EVALUATION_RUBRIC.md` | 1.0 h | 16.0 | 1–2 |

If running over budget: drop 9 first, then shrink 8 to labels + Dynamic Type only (never drop
tests). Write leftovers in README "What's missing".

---

## Phase 0 — Project hygiene (manual + agent)

Manual in Xcode (5 min):
1. Target `BookShelf` ▸ General ▸ Minimum Deployments → **iOS 17.0** (currently 26.5 — reviewers'
   simulators may not have iOS 26.5; iOS 17 is what the task states).
2. Build Settings ▸ Swift Language Version → **Swift 6**. Keep `Default Actor Isolation = MainActor`
   and `Approachable Concurrency = Yes` (already set).
3. File ▸ New ▸ Target ▸ Unit Testing Bundle → `BookShelfTests`, Swift Testing.
4. Product ▸ Scheme ▸ Manage Schemes → tick **Shared** for `BookShelf`.
5. Set bundle identifier to something personal, e.g. `com.<you>.bookshelf` (currently `Test.BookShelf`).
6. Optional: Project ▸ Info ▸ Localizations → add Arabic.

Agent (prompt P0): `.gitignore`, folder skeleton with placeholder files removed once real ones
land, `Localizable.xcstrings`, delete `ContentView.swift`, minimal `RootView` placeholder
`TabView`, `AppDependencies` skeleton. Verify `xcodebuild build` and `xcodebuild test` (0 tests) work.

Commits:
- `chore: target iOS 17, Swift 6, add test target and shared scheme`
- `chore: project skeleton, gitignore, string catalog`

## Phase 1 — Core networking
Deliverables per `04_NETWORKING.md` + `11_ERROR_HANDLING_AND_LOGGING.md`.
Tests: `EndpointTests` (URL building, encoding of spaces/Arabic), `AppErrorMappingTests`,
`URLSessionHTTPClientTests` (via `URLProtocol` stub: 200, 500, empty body, cancelled).
Commits: `feat(core): typed HTTP client with error mapping`, `test(core): http client and error mapping`
(or one combined commit with tests — preferred).

## Phase 2 — Domain + Open Library data layer
Deliverables per `03_OPEN_LIBRARY_API_AND_DECODING.md`. Create fixtures from real responses
(`curl` them; trim to ≤ 3 KB each). Tests: `SearchResponseDecodingTests`, `WorkDecodingTests`,
`OpenLibraryBookCatalogTests` (redirect once, author names concurrent + best-effort, seed fallback).
Commits: `feat(domain): book models and work key`, `feat(data): Open Library catalog with tolerant decoding`.

## Phase 3 — Paginator
Per `05` §3. Commit: `feat(domain): generic paginator with dedupe and in-flight guard`.

## Phase 4a — Design system
Per `08` "Components" and `prompts/06_DESIGN_SYSTEM.md`. Build the app-agnostic UI kit **before**
any screen, so the components are shaped by the rules rather than by the first screen that needed
them. Verified by a grep proving nothing in `UI/` knows about `Book`, `Shelf`, networking or
persistence. Commit: `feat(ui): reusable component kit with previews`.

## Phase 4b — Search feature
Per `05` (§1, §2, §4, §5, §6, §7). `CoverView` renders the placeholder until Phase 5 swaps its
internals behind the same interface, so no screen changes later. Commits:
`feat(search): view model with debounce, stale guard and pagination`,
`feat(search): search screen with all five states`.

## Phase 5 — Images
Per `07`. Commit: `feat(images): actor-based loader with downsampling and race-free RemoteImage`.

## Phase 6 — Persistence + Shelf + composition root
Per `06` and `02` (AppDependencies). Commits: `feat(shelf): SwiftData repository and observable store`,
`feat(app): tab root, dependency container, shelf screen`.

## Phase 7 — Details + connectivity
Per `06` details flow, `08` details layout. Commits: `feat(details): local-first details with save toggle`,
`feat(core): connectivity monitor and offline banner`.

## Phase 8 — A11y / Dynamic Type / Dark / l10n / RTL / iPad
Per `08`. Commit: `a11y: VoiceOver labels, adaptive rows, dark mode audit` and `l10n: Arabic strings and RTL fixes`.

## Phase 9 — O1 reading status
Per `06` "Optional O1". Commit: `feat(shelf): reading status with filter`.

## Phase 10 — Hardening
Run: `10` verification list, `11` grep gates, `16` rubric. Fix findings. Commit: `fix: hardening from link-conditioner and instruments pass`.

## Phase 11 — Deliverables
Per `15_DELIVERABLES.md`. Commits: `docs: README with architecture, decisions, hours`, `docs: AI_NOTES`.

---

## Hours log (fill in as you go — copy to README)

| Phase | Estimated | Actual | Notes |
|---|---|---|---|
| 0 | 0.75 | | |
| 1 | 1.5 | | |
| 2 | 2.0 | | |
| 3 | 0.75 | | |
| 4a | 0.75 | | |
| 4b | 1.75 | | |
| 5 | 1.5 | | |
| 6 | 2.0 | | |
| 7 | 1.5 | | |
| 8 | 1.0 | | |
| 9 | 0.75 | | |
| 10 | 0.75 | | |
| 11 | 1.0 | | |
| **Total** | **16.0** | | |

## Risk register

| Risk | Mitigation |
|---|---|
| Swift 6 + SwiftData friction eats time | Repository is `@MainActor` on `mainContext`; keep entity simple; fall back to Swift 5 mode **only** as a last resort and document |
| Open Library slow/down during dev | Fixtures + `StubCatalog` make everything but manual QA network-independent |
| Test target setup issues | Do it first (Phase 0) so nothing else blocks |
| `NWPathMonitor` on simulator confusing | Test offline on a device or toggle Mac Wi-Fi; document |
| Over-engineering temptation | Each phase has a fixed file list; prompts forbid extras |
| AI-generated code with subtle concurrency bugs | Strict Swift 6 compile + the race tests + review checklist per commit |
