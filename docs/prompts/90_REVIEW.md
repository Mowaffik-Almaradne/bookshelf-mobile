# Prompt 90 — Review loop (paste in the SAME chat, after every implementation prompt)

Run this before every commit. It costs two minutes and catches the things that would otherwise
reach the reviewer. Do not skip it because the build is green — most deductions in this task are
for design and discipline, not compile errors.

---

```
Now review the changes you just made. Be strict with yourself; assume a senior reviewer will read
this diff line by line.

PART 1 — CHECKLIST
Answer PASS or FAIL for each item, with a one-line justification naming the files. Do not write
"N/A" unless the item genuinely cannot apply to this phase.

Correctness
 1. Builds with ZERO warnings under Swift 6 strict concurrency.
 2. All tests pass; the new logic introduced in this phase has tests.
 3. The forbidden-pattern grep is clean (try!, as!, fatalError, print, @unchecked,
    nonisolated(unsafe), DispatchQueue outside ConnectivityMonitor, Task.detached).
 4. No force unwraps and no array[0] on anything derived from network or persisted data.

Design
 5. Every new type is in the correct layer (Core / Domain / Data / Features / UI).
 6. No layer-violating imports: Domain imports Foundation only; ViewModels do not import SwiftUI
    or SwiftData; Views do not import URLSession/SwiftData; DTOs stay in Data.
 7. Every new I/O dependency is a protocol injected through init.
 8. No duplicated logic — name the existing components you reused instead of rewriting.

Concurrency
 9. Each new type's isolation (MainActor / nonisolated / actor) is deliberate and justified in a
    /// comment.
10. Every CPU-heavy async function is @concurrent; state which executor each one actually runs on.
11. Tasks are stored and cancelled where they can outlive their owner; AppError.cancelled can
    never reach the UI.

Components
12. Every view body is under ~40 lines; every file is under 250 lines (list any file over 150).
13. Screens only compose and navigate; feature components take plain values and closures; UI kit
    components know nothing about Book/Shelf/networking.
14. No magic numbers for spacing, sizes or corner radii — all from UI/Theme.

UI & accessibility (skip only if this phase touched no UI)
15. Every control has an accessibility label; icon-only controls use Label + .labelStyle(.iconOnly).
16. Every user-facing string is in the String Catalog with an Arabic translation.
17. Previews exist for each new state: light, dark, .accessibility3, and RTL where directional.

Tests
18. Deterministic: no sleeps used for synchronisation, no shared mutable state, no order
    dependence.
19. Each test would FAIL if the behaviour it covers were removed — name any test that would not.

Docs
20. `///` on every new type and protocol requirement, explaining WHY and the invariants, not
    restating the code.

PART 2 — FIX
Fix every FAIL now, minimally, without adding features. Then re-run the verification commands and
paste the exact output.

PART 3 — REPORT
 a. The list of assumptions you made that are NOT written in the docs — I need to record them in
    the README.
 b. Anything in the docs that turned out to be wrong, impossible, or more expensive than
    expected, so I can update the plan.
 c. The one thing in this diff a senior reviewer is most likely to criticise, and why you left it.
 d. The final commit message(s) in the project's conventional format with the requirement IDs.
```
