# BookShelf ("The Shelf" / الرف) — Engineering docs

Planning and specification set for the take-home task in `مهمة-عملية-iOS.md`. Written **before**
implementation so that every phase of AI-assisted coding follows the same architecture, standards
and acceptance criteria. Read `01` first, then `02`; the rest are referenced from the prompts.

## Index

| # | Doc | Purpose |
|---|---|---|
| 01 | [Task spec](01_TASK_SPEC.md) | Clean English requirements with IDs (R/Q/O/D/X) and acceptance checklist |
| 02 | [Architecture](02_ARCHITECTURE.md) | MVVM + repository, layering, concurrency model, folder layout, contracts, decision log |
| 03 | [Open Library API & decoding](03_OPEN_LIBRARY_API_AND_DECODING.md) | Verified response shapes, DTOs, tolerant decoding, domain models, fixtures |
| 04 | [Networking](04_NETWORKING.md) | `HTTPClient`, `Endpoint`, sessions, `@concurrent` decoding, error mapping, retry policy |
| 05 | [Search & pagination](05_SEARCH_AND_PAGINATION.md) | State machine, debounce, stale-result guard, generic `Paginator`, tests |
| 06 | [Persistence & offline](06_PERSISTENCE_AND_OFFLINE.md) | SwiftData model, repository, `ShelfStore`, offline-first details, connectivity |
| 07 | [Image loading](07_IMAGE_LOADING.md) | Actor loader, caches, ImageIO downsampling, race-free `RemoteImage` |
| 08 | [UI, a11y, l10n](08_UI_ACCESSIBILITY_LOCALIZATION.md) | Screens, components, VoiceOver, Dynamic Type, Dark Mode, Arabic/RTL, iPad |
| 09 | [Testing](09_TESTING.md) | Swift Testing strategy, doubles, full test inventory |
| 10 | [Performance & concurrency](10_PERFORMANCE_AND_CONCURRENCY.md) | Swift 6 rules, main-thread budget, memory, verification |
| 11 | [Error handling & logging](11_ERROR_HANDLING_AND_LOGGING.md) | `AppError`, user copy, surfaces, `os.Logger`, grep gates |
| 12 | [Code standards](12_CODE_STANDARDS.md) | Non-negotiables, naming, review checklist, git conventions |
| 13 | [Implementation plan](13_IMPLEMENTATION_PLAN.md) | 12 phases, 16 h budget, commit plan, hours log, risks |
| 14 | [Prompt playbook](14_PROMPTS.md) | Overview of the prompt flow (the prompts themselves live in [`prompts/`](prompts/README.md)) |
| 15 | [Deliverables](15_DELIVERABLES.md) | README/AI_NOTES templates, video script, submission checklist |
| 16 | [Evaluation rubric](16_EVALUATION_RUBRIC.md) | 100-point rubric, pre-empted deductions, self-grade sheet |
| — | [**prompts/**](prompts/README.md) | **One copy-paste prompt per implementation step** — this is what you actually run |
| — | [AI_LOG.md](AI_LOG.md) | Running log to fill in as you work; raw material for the graded `AI_NOTES.md` |

## Workflow

```
01 spec ──▶ 02–12 design & rules ──▶ prompts/01 architecture review ──▶ fix docs
   ──▶ for each step: prompts/02…12  ─▶  prompts/90 review  ─▶  build/test/grep  ─▶  commit  ─▶  AI_LOG.md
   ──▶ prompts/13 hardening + manual Instruments / Link-Conditioner / VoiceOver passes
   ──▶ prompts/92 grade on two different models until rubric 16 is stable at ≥ 98
   ──▶ prompts/14 README + AI_NOTES ──▶ video ──▶ submit
```

Each prompt is self-contained: open a new chat, attach the docs it lists, paste it whole.

## Current project facts (verified 2026-09-29)

| Fact | Value | Action |
|---|---|---|
| Xcode | 26.6 | — |
| Deployment target | **26.5** | Lower to **17.0** (Phase 0) — task says iOS 17 |
| Swift language mode | 5 | Set to **6** (Phase 0) |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | Keep |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Keep — implies `@concurrent` needed for CPU work |
| Project format | `objectVersion 77`, file-system-synchronized groups | New files auto-included; no pbxproj edits |
| Test target | none | Add `BookShelfTests` (Swift Testing) — Phase 0 |
| Shared scheme | none | Share `BookShelf` scheme — Phase 0 |
| `.gitignore` | none | Add — Phase 0 (`xcuserdata/` is currently untracked noise) |
| Bundle ID | `Test.BookShelf` | Personalise |
| Sources | template `ContentView.swift` | Delete in Phase 0 |

## Principles in one breath

Small and complete beats big and half-done · every I/O behind a protocol · state machines are
explicit enums · cancellation and stale-guards are tested, not assumed · CPU work is `@concurrent`
· nothing force-unwrapped · system UI components carry accessibility · every decision has a
"why" the README can quote · commit history tells the story.
