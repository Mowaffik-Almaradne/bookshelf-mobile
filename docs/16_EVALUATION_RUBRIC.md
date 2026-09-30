# 16 — Evaluation rubric (100 points) & self-grading

Mirrors the seven grader criteria in `01_TASK_SPEC.md`. Use it three times: (1) as the definition
of "done" while building, (2) with Prompt G (`14_PROMPTS.md`) on two different AI models,
(3) yourself, honestly, before submitting. A 100 here means "no reviewer can find a legitimate
deduction", not "everything is fancy".

## A. App works and is stable — 15

| Pts | Check | Evidence |
|---|---|---|
| 3 | Clean clone builds with zero warnings on Xcode 26, iOS 17 target | `xcodebuild build` |
| 3 | No crash paths from network data: no `!`, `try!`, `as!`, `[0]`, `fatalError` on data | grep gate |
| 3 | Search → details → save → shelf → delete → relaunch works, incl. offline | video |
| 3 | Slow network (Link Conditioner "Very Bad") never freezes UI; timeouts surface with Retry | manual pass noted in README |
| 3 | Malformed/partial API payloads handled (missing fields, description object, -1 covers, redirect) | fixture tests |

## B. iOS & Swift understanding — 15

| Pts | Check |
|---|---|
| 4 | Correct Swift 6 concurrency: isolation chosen deliberately per type; `@concurrent` for CPU work; no escape hatches |
| 3 | Structured concurrency: task groups for author names, cancellation propagation, no detached tasks |
| 3 | SwiftUI idioms: `@Observable`, `.task(id:)`, `ContentUnavailableView`, `.searchable`, `NavigationStack` values, `Layout` |
| 3 | SwiftData used correctly: unique upsert, external storage, in-memory tests, main-context isolation explained |
| 2 | Platform details: URLCache policies, ImageIO downsampling, NWPathMonitor semantics, String Catalog |

## C. Architecture & code quality — 20

| Pts | Check |
|---|---|
| 5 | Clear layering (Presentation → Domain ← Data); no layer-violating imports; Views never touch I/O |
| 4 | Protocol boundaries for every I/O (HTTP, catalog, shelf, images, connectivity) with constructor injection |
| 3 | Single source of truth for saved state; no duplicated state machines |
| 3 | Small, cohesive files; consistent naming; `///` docs explaining *why*; no dead code |
| 3 | Reusable generic parts (`Paginator`, `RemoteImage`, `HTTPClient`, `FlexibleText`) without over-engineering |
| 2 | README explains the pattern choice and rejected alternatives convincingly |

## D. Hard cases: slow network, errors, offline, pagination — 15

| Pts | Check |
|---|---|
| 3 | Stale results impossible (cancellation + generation), proven by a test |
| 3 | Pagination: no dupes, no double in-flight, correct end detection with drifting totals — tests |
| 3 | Page-N failure keeps items with inline retry; first-page failure full-screen retry |
| 3 | Offline: shelf + saved details incl. covers fully functional; unsaved details fail gracefully with banner |
| 3 | Cancellation never shown as error; timeouts short and explained; one details auto-retry |

## E. Tests — 15

| Pts | Check |
|---|---|
| 3 | Search screen states tested (Q3-a) — incl. race and whitespace no-refetch |
| 3 | Pagination logic tested (Q3-b) — all 8 edge cases |
| 3 | Details decoding shapes tested (Q3-c) — string/object/absent, authors both shapes, covers -1, redirect, malformed |
| 3 | ViewModels/Store tested through protocols with in-memory persistence; image loader tested with URLProtocol |
| 3 | Suite is fast (< 5 s), deterministic (no sleeps), runs from a clean clone with one command; fixtures are real payloads |

## F. UI & accessibility — 10

| Pts | Check |
|---|---|
| 3 | All five search states + details states + shelf empty state are distinct and clear |
| 2 | VoiceOver: every control labelled; rows combined; covers hidden; announcements on results |
| 2 | Dynamic Type up to AX5 without truncation/clipping; adaptive row axis |
| 2 | Dark Mode correct everywhere (semantic colours) |
| 1 | RTL/Arabic and iPad width sanity |

## G. AI usage quality, learning speed, communication — 10

| Pts | Check |
|---|---|
| 3 | AI_NOTES: three concrete prompts with outputs and *your* modifications |
| 3 | ≥ 1 real AI mistake caught, with *how* you noticed (compiler, profiler, test, reasoning) |
| 2 | Evidence of process: planning docs, per-phase prompts, review loop, commit history matches plan |
| 2 | README/AI_NOTES clear, honest (hours, missing items), in your own voice |

---

## Common deductions we are pre-empting (the "why not 100" list)

| Typical deduction | Our guard |
|---|---|
| `AsyncImage` with wrong image on reuse | `RemoteImage` with url-keyed state + `.task(id:)` (07) |
| Decoding on main thread | `@concurrent` (04, 10) + Time Profiler check |
| `numFound`-only end detection → infinite footer spinner | short-page ∧ total rule (05) |
| Duplicate rows crash `ForEach` (duplicate IDs) | `Paginator` dedupe by `WorkKey` (05) |
| Old query results flashing | generation token + cancellation + test (05) |
| Force unwraps in DTO mapping | all optionals + `WorkKey?` + grep gate (03, 11) |
| Offline details spinner forever | local-first + `waitsForConnectivity=false` + banner (06, 04) |
| Saved state not updated in search after saving | `ShelfStore.savedKeys` observable (06) |
| Icon-only buttons without labels | `Label + iconOnly` rule (08) |
| Hard-coded colours/fonts breaking Dark Mode/Dynamic Type | semantic-only rule + previews (08) |
| Tests that hit the network or sleep | protocol doubles, `URLProtocol` stub, `waitUntil` (09) |
| One giant commit | 20-commit plan (13) |
| README missing hours/assumptions/missing items | template (15) |
| AI_NOTES generic ("AI helped a lot") | running log + template (15) |
| Swift 6 warnings silenced with `@unchecked Sendable` | forbidden in app code (12) |
| `description` object shape crashes decoding | `FlexibleText` + parametrised test (03, 09) |
| Blank cover images (transparent 1×1 gif) | `?default=false` (03) |
| 60 s default timeout feels frozen | 15 s + Retry (04) |

## Self-grade sheet (fill before submitting)

| Section | Max | Self | Model 1 | Model 2 | Gaps |
|---|---|---|---|---|---|
| A Stability | 15 | | | | |
| B Platform understanding | 15 | | | | |
| C Architecture & quality | 20 | | | | |
| D Hard cases | 15 | | | | |
| E Tests | 15 | | | | |
| F UI & a11y | 10 | | | | |
| G AI usage & communication | 10 | | | | |
| **Total** | **100** | | | | |

Stop iterating when two independent model graders and your own honest pass agree on ≥ 98 with
no blocker-level findings. Then record the video and submit.
