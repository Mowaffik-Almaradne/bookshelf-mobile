# Prompt 92 — Independent grading

Run this **in a different model and a fresh chat** than the one that wrote the code — a model
reviewing its own work is a weak reviewer. Run it at least twice with different models, fix what
is cheap, and stop when both agree at ≥ 98 with no blockers.

**Attach:** `@docs/01_TASK_SPEC.md @docs/16_EVALUATION_RUBRIC.md` and the whole repository.

---

```
You are the hiring panel's senior iOS reviewer for a take-home task. Grade this repository
strictly against docs/16_EVALUATION_RUBRIC.md (100 points across seven sections). The original
requirements with IDs are in docs/01_TASK_SPEC.md.

Be adversarial. Your job is to find the reasons NOT to give full marks. Read the actual code —
do not grade the README's claims. Where the README claims something, verify it in the source and
flag any mismatch as a serious finding.

SPECIFIC ATTACKS TO ATTEMPT (report the file:line evidence for each, pass or fail)
 1. Find a crash path starting from network data: a force unwrap, try!, as!, array[0], an
    optional assumed present, or a malformed payload that would trap.
 2. Construct an interleaving where a stale search result is applied after a newer query
    (R1.3). Give the exact sequence or state that it is impossible and why.
 3. Construct a scroll pattern that fires two requests for the same page, skips a page, stops
    paginating early, or loops forever (R2.2, R2.3, R2.4).
 4. Construct a cell-reuse sequence where one book's cover appears on another book's row (R5.2).
 5. Find CPU work running on the main actor: every JSON decode and image decode path — name the
    executor each actually runs on under Swift 6 with default MainActor isolation and
    approachable concurrency (remember SE-0461: nonisolated async inherits the caller's executor
    unless marked @concurrent).
 6. Find a path where a saved book's details or cover requires the network (R4.3), or where the
    saved indicator can disagree between screens (R4.4).
 7. Find an interactive control with no accessibility label, or a user-facing string not in the
    String Catalog, or a hard-coded colour/font size that breaks Dark Mode or Dynamic Type.
 8. Find a test that would still pass if the behaviour it claims to cover were deleted; a test
    that sleeps for synchronisation; a test that depends on execution order or shared state.
 9. Find a layer violation: a View touching URLSession or SwiftData, a ViewModel importing
    SwiftUI, a DTO outside the Data layer, Domain importing anything but Foundation.
10. Find duplicated logic or a component that should be shared but was copy-pasted.
11. Judge the commit history: does it show logical steps with clear messages, or one dump?
12. Judge README and AI_NOTES: are the claims specific, honest and verifiable? Do the "hardest
    parts" and "what I learned" sections read as genuine understanding or as AI filler?

OUTPUT
A. For each rubric section: score / max, the evidence you based it on (file:line), and exactly
   what would be needed for full marks.
B. The total out of 100.
C. A findings table sorted by severity: blocker / major / minor, each with file:line and the fix.
D. The top 5 fixes ranked by (marks gained ÷ effort).
E. One paragraph: would you advance this candidate? What is the single strongest and single
   weakest thing about the submission?

Do not be generous. A score above 95 must be justified by evidence, not by the absence of
obvious problems. If you cannot verify something, say "unverified" rather than assuming it works.
```

---

## Using the results

- **Blockers and majors**: fix with `91_FIX.md`, then re-grade.
- **Minors near the deadline**: do not fix them — list them in the README's "what's missing"
  section instead. Honest self-awareness scores better than a rushed change that breaks
  something the night before submission.
- **Disagreements between the two graders**: trust the one that cites `file:line`. A grader that
  makes claims without evidence is guessing.
- Record the most interesting finding in `docs/AI_LOG.md`; a grader catching something your
  implementation model missed is good material for `AI_NOTES.md`.
