# Prompt 01 — Architecture review (no code)

**Attach:** `@docs/01_TASK_SPEC.md @docs/02_ARCHITECTURE.md @docs/03_OPEN_LIBRARY_API_AND_DECODING.md @docs/04_NETWORKING.md @docs/05_SEARCH_AND_PAGINATION.md @docs/06_PERSISTENCE_AND_OFFLINE.md @docs/07_IMAGE_LOADING.md @docs/10_PERFORMANCE_AND_CONCURRENCY.md`

**Goal:** find design flaws while they are still free to fix. Output is a findings list, not code.

**After:** apply the accepted findings to the docs yourself, then start prompt 02.

---

```
You are a principal iOS engineer reviewing an architecture BEFORE implementation.
Do NOT write app code. Do NOT edit files. Produce a findings list only.

CONTEXT
A 16-hour take-home task; the requirements with IDs are in docs/01_TASK_SPEC.md. The design lives
in docs/02–07 and 10. The real project: Xcode 26, Swift 6 language mode,
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, SWIFT_APPROACHABLE_CONCURRENCY = YES, iOS 17.0
deployment target, SwiftUI + SwiftData, Apple frameworks only, file-system-synchronized project
groups (objectVersion 77).

REVIEW FOR
1. Requirement coverage: for each R*/Q* ID in 01, is it satisfied by a named type in 02–07? List
   any ID with no clear owner, and any place where the design is MORE complex than the ID needs.
2. Swift 6 concurrency correctness under default MainActor isolation:
   - isolation choice per type (MainActor / nonisolated / actor) — is each one justified?
   - SE-0461: which functions need `@concurrent` to actually leave the main actor?
   - Sendable boundaries: anything crossing an actor that is not a value type?
   - `static let` in extensions of imported types (URLSession) — isolation trap?
   - cancellation propagation and the generation-token stale guard in 05: can a stale result still
     be applied under any interleaving? Give a concrete sequence if yes.
3. SwiftData under Swift 6: mainContext on a @MainActor repository, @Attribute(.unique) as upsert,
   .externalStorage for cover blobs, in-memory container for tests, autosave disabled. Any trap?
4. Image pipeline (07): is url-keyed state + .task(id:) provably free of the wrong-image-on-reuse
   bug (R5.2)? Any case where the in-flight de-duplication propagates a cancellation to an
   innocent second caller, and does it matter?
5. Pagination (05): end detection with a drifting `numFound` and duplicate keys across pages. Can
   the list ever stop early, loop forever, or request the same page twice?
6. Offline behaviour (06): is there any path where a saved book's details or cover need the
   network? Any path where the UI can hang waiting on connectivity?
7. Effort: flag anything that will cost more than the estimates in docs/13 and propose the
   simpler alternative that still satisfies the requirement.
8. Component separation: does the structure in 02 + 08 give small, reusable, testable pieces, or
   will one screen end up a 300-line view? Name the files you expect to bloat.

OUTPUT FORMAT
A numbered table: # | severity (blocker / should-fix / nit) | doc + section | problem (1–2 lines)
| concrete change. Then a short verdict: "approved as-is" or "approved with changes: <#list>".
Finally: the 3 riskiest parts of this plan for a 16-hour budget.

CONSTRAINTS
Do not propose third-party libraries, extra modules, Combine, or new architectural layers.
Prefer deleting complexity over adding it. If the design is already right, say so plainly
instead of inventing findings.
```
