# 15 — Deliverables: README, AI_NOTES, video, repository

Requirement links: D1–D5, X4, X5. The evaluation is explicitly "based on what you deliver" —
these documents carry as much weight as the code.

## Repository (D1, D2)

- Private GitHub/GitLab repo, reviewers invited (or ZIP with `.git`).
- `main` contains ~20 conventional commits (see 13). Check with `git log --oneline` that the story
  reads like a plan: hygiene → core → data → pagination → search → images → shelf → details →
  a11y/l10n → optional → hardening → docs.
- Root layout:
  ```
  README.md  AI_NOTES.md  BookShelf.xcodeproj/  BookShelf/  BookShelfTests/  docs/  scripts/test.sh  .gitignore
  ```
- Keep `docs/` in the repo: it demonstrates planning and AI-workflow discipline (grader criterion 7).
  Add one line in README pointing to it. Remove `docs/مهمة-عملية-iOS.md` if you consider the task
  text confidential; otherwise keep (assumption: fine to keep private repo).
- Verify from a **clean clone** on another folder: `xcodebuild build` and `xcodebuild test` succeed
  with no manual steps (X6).

## README.md template (D3) — keep ≤ 350 lines, scannable

```markdown
# The Shelf (الرف) — BookShelf

Native iOS app: search Open Library, view details, save books to an offline-first reading shelf.
SwiftUI · Swift 6 · SwiftData · iOS 17+ · Apple frameworks only · Swift Testing.

## Run
- Xcode 26.x, iOS 17+ simulator or device. Open `BookShelf.xcodeproj`, scheme `BookShelf`, ⌘R.
- Tests: ⌘U or `scripts/test.sh`.
- No API keys, no dependencies, no setup.

## Demo
<link to 2–3 min video>  — search, pagination, save, airplane mode, Dynamic Type/Dark Mode.

## Architecture (why)
<3 short paragraphs from docs/02: MVVM + repository, layering, single ShelfStore for cross-screen sync, Swift 6 concurrency model with @concurrent for CPU work. Include the layer diagram.>

## Key decisions & alternatives not chosen
<the decision-log table from docs/02, plus: AsyncImage rejected (07), URLCache vs custom cache, no automatic search retry, no Combine>

## How the hard requirements are met
| Requirement | Where | How |
|---|---|---|
| Debounce/min length (R1.1–2) | SearchViewModel.queryDidChange | Task.sleep + cancel, injected Duration |
| Stale results (R1.3) | SearchViewModel.performSearch | cancellation + generation token |
| Pagination no dupes / no double request / end (R2) | Paginator | Set<ID>, isLoading guard, short-page ∧ total |
| Offline shelf & details (R4.3) | ShelfStore, BookDetailsViewModel.load | full details + cover bytes persisted; local-first |
| Cross-screen sync (R4.4) | ShelfStore.savedKeys (@Observable) | single source of truth |
| Wrong image on reuse (R5.2) | RemoteImage | image stored with its url; rendered only if url matches; .task(id: url) cancellation |
| Main thread free (Q5) | JSONDecoding.decode, ImageDownsampler | @concurrent |

## Two hardest parts (in my words)
<!-- Write these yourself. Candidates: (1) Swift 6 default-MainActor isolation + SE-0461 — discovering that nonisolated async
inherits the caller's executor and that @concurrent is needed; (2) end-of-results detection with drifting numFound and
duplicate keys; (3) making details work offline without a second code path. -->

## Assumptions
- Save button lives on Details (spec); Search rows show a saved indicator only.
- A book can be saved even if the details request failed (seed data from search), so users on bad networks aren't blocked.
- Details refresh for saved books is silent; local copy is authoritative when offline.
- Author names come from search results first; work → author lookups are best-effort.
- Search results are not cached offline (O2 not implemented) — Shelf is the offline surface.
- Years shown without digit grouping in all locales.
- <add yours>

## Testing
<what is covered (the three mandated areas + more), how to run, why Swift Testing; fixtures from real responses; ~N tests in ~X s>

## Accessibility & localization
<VoiceOver labels, Dynamic Type adaptive rows, Dark Mode, Arabic + RTL, iPad width>

## Performance notes
<downsampling, decode off main, URLCache sizes, Instruments pass results in one sentence>

## Time spent (≈ 16 h)
<hours table from docs/13 with actuals>

## What's missing / next day
<O2 stale search cache, O4 full iPad split view, UI tests, CI, background refresh of shelf, … plus anything cut>

## Requirement coverage
<checklist from docs/01 with ✅/⚠️>

## AI usage
See AI_NOTES.md. Planning docs in `docs/`.
```

## AI_NOTES.md template (D4)

```markdown
# AI notes

## Tools
- Cursor (Agent mode, model <X>) — planning docs, scaffolding, first drafts of each layer, test scaffolds.
- <ChatGPT/Claude/…> — independent code review/grading pass (docs/14 Prompt G).
- Xcode predictive completion — small completions.
Parts NOT written by AI: <e.g. final wording of README/AI_NOTES, manual Xcode configuration, Instruments/Link Conditioner QA, decisions in docs/02 decision log>.

## Workflow
Spec → planning docs (docs/01–13) → one prompt per phase (docs/14) → review prompt → manual review + fixes → commit.
Every phase was compiled under Swift 6 strict concurrency and tests were run before commit.

## Three prompts that mattered
### 1. <e.g. "Paginator with dedupe and in-flight guard" (docs/14 P3)>
Prompt: <1–3 lines summary or link to docs/14>
Output: <what came out>
What I changed: <e.g. computeHasMore originally trusted numFound only; I added the short-page rule after seeing drift>

### 2. <Search ViewModel stale-result guard (P4)>
…
### 3. <Image loader / RemoteImage (P5)>
…

## Where the AI was wrong (and how I noticed)
- <e.g. It wrote `nonisolated func decode(...) async` and claimed it runs off-main. Under approachable concurrency
  (SE-0461) it inherits the caller's executor; Time Profiler showed JSONDecoder on the main thread. Fixed with @concurrent.>
- <e.g. It suggested `@unchecked Sendable` on the HTTP client to silence a warning; rejected — made the class nonisolated
  final with immutable stored properties instead.>
- <e.g. Suggested AsyncImage; rejected for lack of cache/downsampling/testability.>
- <e.g. Hallucinated a SwiftData API / wrong @Attribute option; caught at compile time.>

## What I learned (Swift / iOS)
<!-- Your words. E.g. default MainActor isolation + @concurrent; typed throws; Swift Testing parametrised tests;
SwiftData externalStorage/unique upsert; ImageIO downsampling; ContentUnavailableView; .task(id:) semantics;
Open Library quirks (description shapes, -1 covers, default=false). -->
```

**Running log** — keep `docs/AI_LOG.md` (or a notes file outside the repo) during work with one
bullet per prompt: phase, what you asked, surprises, corrections. This is the raw material; the
AI_NOTES above is the curated version. Without a running log you will not remember the "AI was
wrong" moments — and D4 requires at least one.

## Video (D5) — 2–3 minutes, one take is fine

Prep: simulator iPhone 17, light mode, fresh install (shelf empty), Network Link Conditioner off.
Record with QuickTime (File ▸ New Screen Recording) or `xcrun simctl io booted recordVideo demo.mp4`.

| Time | Action | Shows |
|---|---|---|
| 0:00 | Launch → Search tab idle state | R1.5 idle, launch speed |
| 0:05 | Type "har" slowly → results appear only after pause; type more → results replace | R1.1, R1.2, R1.3 |
| 0:25 | Scroll fast to bottom → footer spinner → more pages → keep going to end ("End of results") | R2.1–R2.4 |
| 0:50 | Tap a book → details (cover, authors, description, subjects) → Save | R3 |
| 1:05 | Back → row shows bookmark; Shelf tab badge = 1 | R4.4 |
| 1:10 | Save one more; go to Shelf; swipe-delete one | R4.1 |
| 1:25 | Enable airplane mode (device) / turn off Mac Wi-Fi (simulator) → offline banner | offline UX |
| 1:30 | Search → error + Retry; Shelf → works; open saved book → full details **with cover**, no spinner | R4.3, O3 |
| 1:50 | Kill app (swipe up), relaunch still offline → shelf persists | R4.2 |
| 2:00 | Toggle Dark Mode (⇧⌘A) + Settings large text (or Environment Overrides) → rows adapt | Q6 |
| 2:20 | Optional: Arabic language → RTL; reading status filter | O1/O3 |
| 2:40 | End | |

Narration optional; if you speak, name the requirement you are demonstrating. Upload as unlisted
YouTube/Drive and link in README; also commit nothing binary.

## Final pre-submission checklist

- [ ] Clean clone builds and tests green in one command.
- [ ] `git log` tells the story; no "wip"/"fix stuff" messages; no giant final commit.
- [ ] README sections all present; hours table filled; assumptions listed; missing items honest.
- [ ] AI_NOTES has 3 prompt examples + ≥ 1 mistake + learnings — in your own words.
- [ ] Video linked and playable; covers the 4 demanded things (search, scroll, save, airplane).
- [ ] No secrets, no personal data, `.gitignore` effective (`git status` clean).
- [ ] Reviewers invited to the private repo.
