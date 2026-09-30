# Prompt 14 — Phase 11: README, AI_NOTES & submission

**Attach:** `@docs/15_DELIVERABLES.md @docs/01_TASK_SPEC.md @docs/02_ARCHITECTURE.md @docs/13_IMPLEMENTATION_PLAN.md @docs/AI_LOG.md`

**Before running:** fill in the hours table in `docs/13_IMPLEMENTATION_PLAN.md` with your real
numbers, and make sure `docs/AI_LOG.md` has your running notes. The agent cannot invent either,
and both are graded (D3, D4).

**Commits:** 2 (`docs: README with architecture, decisions and hours`, `docs: AI notes`).

---

```
Phase 11 of docs/13_IMPLEMENTATION_PLAN.md: write the two delivery documents.

RULES FOR THIS TASK
- Use ONLY facts you can verify by reading the repository, plus the hours table and AI log I
  attached. Do NOT invent hours, decisions, test counts, or performance numbers.
- Where the template asks for MY voice (hardest parts, what I learned, why I rejected something),
  write a short draft and mark it with `<!-- REWRITE IN YOUR OWN WORDS -->`. I will rewrite those
  sections by hand — a reviewer can tell AI-written reflection, and D4 grades my understanding.
- Verify every claim against the code. If the template mentions something the code does not do,
  say so instead of writing it.

DELIVERABLE 1 — README.md at the repo root, following the template in docs/15 exactly,
≤ 350 lines, sections in this order:
 1. Title + one-line description + the stack line.
 2. Run: Xcode version, scheme, ⌘R, tests via ⌘U or scripts/test.sh, "no keys, no dependencies".
 3. Demo: a placeholder link line for the video — mark it TODO for me to fill.
 4. Architecture (why): three short paragraphs + the layer diagram from docs/02. Explain MVVM +
    repository, the single ShelfStore for cross-screen sync, and the Swift 6 concurrency model
    including why CPU work is @concurrent.
 5. Key decisions and alternatives NOT chosen: the decision-log table from docs/02 plus the
    AsyncImage rejection, URLCache vs a custom cache, no automatic search retry, no Combine,
    store vs @Query. One line of justification each.
 6. How the hard requirements are met: the table from docs/15 with the real type and function
    names from the code, verified by reading it.
 7. Two hardest parts — DRAFT ONLY, marked for rewrite. Candidates from this project: Swift 6
    default MainActor isolation + SE-0461 (@concurrent), end-of-results detection with a
    drifting numFound and duplicate keys, making details work offline without a second code path.
 8. Assumptions: gather the real ones from the code and from the assumption lists the earlier
    phases reported; include the save-from-seed-data fallback, silent refresh failures, years
    without digit grouping, search results not cached offline.
 9. Testing: what is covered (name the three mandated areas explicitly), the real test count and
    runtime from an actual run, why Swift Testing, fixtures from real API responses.
10. Accessibility & localization: what was done and how to verify it.
11. Performance notes: downsampling, decoding off the main actor, cache sizes — and only the
    Instruments results I gave you, if any.
12. Time spent: the hours table I attached, with the total.
13. What's missing / what I'd do with one more day: honest, specific, from the real gaps.
14. Requirement coverage: the checklist from docs/01 with ✅ or ⚠️ per ID, each judged by reading
    the code. Anything you cannot verify gets ⚠️ and a note — do not mark ✅ optimistically.
15. A pointer to docs/ explaining that the planning documents and prompt pack are included.

DELIVERABLE 2 — AI_NOTES.md at the repo root, following the template in docs/15:
 1. Tools used and for which parts; explicitly list what was NOT AI-written.
 2. The workflow: spec → planning docs → one prompt per phase → review prompt → manual review →
    commit, with the compile-and-test gate on every phase.
 3. Three concrete prompt examples from my AI log: what I asked, what came out, what I changed.
    Use the real entries — do not fabricate.
 4. Where the AI was wrong and how I noticed — at least one, from my log. Keep the diagnosis
    technical and specific.
 5. What I learned in Swift/iOS — DRAFT ONLY, marked for rewrite.

FINALLY
Report: a list of every claim you could not verify from the code, and the exact README sections
I must rewrite by hand. Propose the two commit messages.

NON-NEGOTIABLES
- No invented facts, numbers, or decisions. No marketing language. No emoji outside the coverage
  checklist ticks.
- Markdown must render correctly: tables aligned, code fences closed, links valid.
- Keep it scannable: short paragraphs, tables over prose for enumerable facts.
- SCOPE: write only these two files. Do not modify app code, tests, or the docs/ folder.
- Do not commit yourself.
```

---

## After the agent finishes — your checklist

1. **Rewrite the marked sections** (hardest parts, what I learned, why you rejected things) in
   your own words. This is the highest-leverage 20 minutes of the whole task.
2. **Record the video** using the shot list in `docs/15_DELIVERABLES.md` (2–3 minutes: search,
   pagination, save, airplane mode, relaunch, Dark Mode/large text). Link it in the README.
3. **Verify a clean clone**:
   ```bash
   git clone <repo> /tmp/bookshelf-check && cd /tmp/bookshelf-check && ./scripts/test.sh
   ```
   It must build and pass with no manual steps (requirement X6).
4. **Read your own `git log --oneline`** — it should tell the story of the plan. No "wip", no
   single giant commit.
5. **Run `92_GRADE.md`** in two different models. Fix anything scored below full marks that is
   cheap. Stop when both agree at ≥ 98 with no blockers.
6. **Invite the reviewers** to the private repository, or produce the ZIP including `.git`.
