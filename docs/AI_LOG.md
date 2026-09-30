# AI running log

Fill this in **as you work**, right after each prompt. It takes 60 seconds per entry and it is
the raw material for `AI_NOTES.md`, which is a graded deliverable (D4). You will not be able to
reconstruct these details at the end — especially the moments when the AI was wrong, which is
exactly what the task asks you to document.

You need, by the end: **three concrete prompt examples** and **at least one AI mistake you
caught, including how you noticed it**.

---

## Entry template

```
### Phase <n> — <name> — <date>
- Model / tool:
- Prompt used: docs/prompts/<file>  (plus any changes I made to it)
- What came out:
- What I changed by hand, and why:
- Anything the AI got wrong / suggested that I rejected:
- How I noticed (compiler, test, profiler, reasoning, review prompt):
- Time: estimated <x> h, actual <y> h
- New thing I learned:
```

---

## Entries

### Phase 0 — Project setup — <date>
- Model / tool:
- Prompt used: `docs/prompts/02_SETUP.md`
- What came out:
- What I changed by hand, and why:
- Anything the AI got wrong:
- How I noticed:
- Time: estimated 0.75 h, actual
- New thing I learned:

### Phase 1 — Core networking — <date>
- Prompt used: `docs/prompts/03_CORE_NETWORKING.md`
- …

### Phase 2 — Domain & data — <date>
- Prompt used: `docs/prompts/04_DOMAIN_AND_DATA.md`
- …

### Phase 3 — Pagination — <date>
- Prompt used: `docs/prompts/05_PAGINATION.md`
- …

### Phase 4a — Design system — <date>
- Prompt used: `docs/prompts/06_DESIGN_SYSTEM.md`
- …

### Phase 4b — Search — <date>
- Prompt used: `docs/prompts/07_SEARCH.md`
- …

### Phase 5 — Images — <date>
- Prompt used: `docs/prompts/08_IMAGES.md`
- …

### Phase 6 — Persistence & shelf — <date>
- Prompt used: `docs/prompts/09_PERSISTENCE_SHELF.md`
- …

### Phase 7 — Details & connectivity — <date>
- Prompt used: `docs/prompts/10_DETAILS_CONNECTIVITY.md`
- …

### Phase 8 — Accessibility & Arabic — <date>
- Prompt used: `docs/prompts/11_ACCESSIBILITY_L10N.md`
- …

### Phase 9 — Reading status — <date>
- Prompt used: `docs/prompts/12_READING_STATUS.md`
- …

### Phase 10 — Hardening — 2026-09-29
- Model / tool: Cursor agent (Composer) as hostile senior reviewer + implementer
- Prompt used: `docs/prompts/13_HARDENING.md` (Part A agent pass; Part B manual passes still for human)
- What came out: Full findings table; fixed pagination stuck-after-cancel (R2.4), cancelled
  first-page spinner, `lastError` alert, “Showing saved copy” on failed online refresh,
  search Retry gated on `isRetryable`; regression test for whitespace-during-page-load
- What I changed by hand, and why: n/a (agent pass); you still need Part B Instruments /
  Link Conditioner / VoiceOver / Arabic passes and to feed findings via `91_FIX.md`
- Anything the AI got wrong / suggested that I rejected: first draft of page-task
  `failLoading()` on *every* gen mismatch — that would clear a *newer* in-flight page’s
  lock and allow duplicate page requests. Corrected to only clear in
  `cancelInFlightAndBumpGeneration` (sync on main) and on same-gen cancel.
- How I noticed: reasoning about interleaving (whitespace early-return vs new prefetch);
  regression test `whitespaceDuringPageLoad_doesNotStickPagination`
- Time: estimated 0.75 h, actual ~1 h agent; manual QA pending
- New thing I learned: cancelling `pageTask` + bumping generation without `paginator.reset()`
  must also release `isLoading`, or `beginLoadingIfNeeded` returns nil forever

### Phase 11 — Deliverables + grade fixes — 2026-09-29
- Prompt used: `docs/prompts/14_DELIVERABLES.md` + `92_GRADE.md` findings + `91_FIX.md`
- What came out / fixed:
  - `Paginator.append`: full page with zero fresh IDs → `hasMore = false` (R2.4)
  - `CoverView`: Data-keyed loaded state + cancel check; `CoverLoadPolicy` + `allowsNetwork` (R5.2 / R4.3)
  - Covers `URLSession`: `waitsForConnectivity = false`, 15 s request timeout
  - O1: shelf status filter + context menu; `ShelfViewModelTests`
  - Stronger R4.4 test via real `ShelfStore`; `CoverLoadPolicyTests`
  - Filled `AI_NOTES.md` / README (video link still human)
- Time: ~1.5 h
- New thing I learned: remote-path R5.2 does not imply offline-path R5.2 — preloaded decode needs the same structural bind.

---

## Candidate "the AI was wrong" moments to watch for

These are the mistakes this stack tends to produce. When one happens, write it down immediately —
with the evidence that exposed it, which is the part that earns the marks.

| Likely mistake | How you would catch it |
|---|---|
| A `nonisolated async` function claimed to run off-main, but under approachable concurrency it inherits the caller's executor | Time Profiler shows `JSONDecoder` or `CGImageSource` frames on the main thread |
| `@unchecked Sendable` proposed to silence a strict-concurrency warning | The review prompt's checklist, or the grep gate |
| `AsyncImage` suggested "because it's simpler" | Scroll jank, wrong covers on reuse, and no way to serve offline bytes |
| Hallucinated SwiftData attribute or API that does not exist | Compile error |
| End-of-results based on `numFound` alone | The pagination test with a drifting total, or an endless footer spinner in the simulator |
| Cancellation surfaced to the user as an error state | The "cancelled is silent" unit test, or a flash of the error screen while typing |
| Force unwrap on a decoded optional "because the API always sends it" | The grep gate, or the fixture with the field missing |
| A `static let` in a `URLSession` extension becoming main-actor isolated | Compile error when the actor or nonisolated client touches it |
