# Prompt 13 — Phase 10: hardening pass

**Attach:** `@docs/10_PERFORMANCE_AND_CONCURRENCY.md @docs/11_ERROR_HANDLING_AND_LOGGING.md @docs/12_CODE_STANDARDS.md @docs/16_EVALUATION_RUBRIC.md`

**Goal:** find your own bugs before the reviewer does. Run the agent pass below, then do the
manual passes yourself — Instruments and Network Link Conditioner reveal things no static review
can.

**Commit:** 1 (`fix: hardening pass from review, profiler and link conditioner`).

---

## Part A — agent pass

```
Phase 10 of docs/13_IMPLEMENTATION_PLAN.md. Act as a HOSTILE senior reviewer whose job is to
find reasons to reject this take-home. Read all of BookShelf/ and BookShelfTests/.

STEP 1 — FINDINGS (report before changing anything)
Produce a table: # | severity (blocker / should-fix / nit) | file:line | problem | fix.
Hunt specifically for:
 1. Any crash path from network data: force unwrap, try!, as!, array[0], fatalError, integer
    overflow, unbounded array indexing, assumptions that an optional is present.
 2. @unchecked Sendable, nonisolated(unsafe), or strict-concurrency warnings silenced rather
    than solved — in app code (test doubles with a lock and a comment are allowed).
 3. Any nonisolated async function doing CPU work WITHOUT @concurrent (it would run on the
    caller's executor, i.e. the main actor). Name every JSON decode and image decode path and
    state which executor it actually runs on.
 4. Tasks that are never cancelled; Tasks that outlive their view; retain cycles via strong self
    in stored Tasks.
 5. Any path where AppError.cancelled can reach the UI, or where a cancellation is shown as an
    error.
 6. A concrete interleaving where a stale search result could still be applied (R1.3), or where
    the same page could be requested twice (R2.3), or where the list could stop paginating early
    or loop forever (R2.4).
 7. A concrete path where a saved book's details or cover would need the network (R4.3), or
    where saved state could go out of sync between screens (R4.4).
 8. Layer violations: grep the imports of every file against the rules in docs/02.
 9. Duplicated logic that should be one shared component or value type.
10. Missing accessibility labels, unlocalized literal strings, hard-coded colours/sizes.
11. Types or protocol requirements with no /// comment; /// comments that restate the code
    instead of explaining why.
12. Tests that sleep for synchronisation, depend on execution order, share mutable state, or
    assert nothing meaningful. Any test that would pass if the implementation were deleted.
13. Dead code, unused files, TODOs, leftover placeholders or stubs from earlier phases.

STEP 2 — FIX
Fix every blocker and should-fix. Do NOT add features. Do NOT restructure anything that is
merely "not how I would do it". For each fix, keep the change minimal and explain in one line
why the fix is correct (especially for concurrency fixes).

STEP 3 — REPORT
Before/after table, the exact verification output, and a list of nits you deliberately left with
the reason. Then self-score the project against docs/16_EVALUATION_RUBRIC.md section by section
with evidence, and list the top 5 remaining improvements by impact/effort.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|Task\.detached' BookShelf/ || echo "grep clean"
rg -n 'DispatchQueue' BookShelf/ | rg -v 'ConnectivityMonitor' || echo "DispatchQueue only in the monitor"
rg -n 'AsyncImage|@Query|ObservableObject|@Published|import Combine' BookShelf/ || echo "no forbidden APIs"
rg -c '' BookShelf/**/*.swift | sort -t: -k2 -n -r | head -10   # longest files, check the 250-line limit

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Never silence a warning with
  @unchecked Sendable, nonisolated(unsafe), or by lowering the language mode — fix the design.
- Never fix a failing test by deleting or weakening it.
- iOS 17.0, Apple frameworks only, no Combine.
- SCOPE: fixes only, no new features, no renames unless a name is actively misleading.
- FINISH BY: pasting exact verification output, the findings/fixes tables, the rubric self-score,
  and proposing the commit message. Do not commit yourself.
```

## Part B — manual passes (you, not the agent)

Do these on a booted simulator and, if possible, once on a real device.

| Pass | How | What to look for |
|---|---|---|
| Slow network | Simulator ▸ Settings ▸ Developer ▸ Network Link Conditioner ▸ "Very Bad Network" | Typing stays fluid; spinner appears; timeout produces Retry; no frozen UI |
| Offline | Airplane mode (device) or turn off the Mac's Wi-Fi (simulator) | Banner appears; Shelf + saved details fully usable **with covers**; unsaved details show error + Retry |
| Scroll performance | Instruments ▸ SwiftUI + Time Profiler, fling the results list 10 s | No JSONDecoder or CGImageSource frames on the main thread; no "long view body" markers |
| Memory | Scroll 300 results, push/pop details 10×, then Debug Memory Graph | No leaked ViewModels; memory returns to baseline |
| Diagnostics | Scheme ▸ Run ▸ Diagnostics: Main Thread Checker + Thread Performance Checker ON | Zero reports during a full walkthrough |
| Large text | Settings ▸ Accessibility ▸ Larger Text at maximum | No clipped titles; rows go vertical; buttons still tappable |
| VoiceOver | Turn it on, navigate Search → Details → Save → Shelf → Delete by ear only | Every element announces something meaningful |
| Arabic/RTL | Scheme ▸ Options ▸ App Language: Arabic | Mirrored layout, no clipped text, chevrons point the right way |
| Relaunch | Save 2 books, kill the app from the switcher, relaunch offline | Shelf intact with covers |

Feed each finding back with `91_FIX.md` as: *"During <pass> I observed <exact symptom>. Diagnose
the root cause in <suspected file> and fix it minimally."*

Record one or two of these findings in `docs/AI_LOG.md` — a bug you caught with Instruments that
the AI's code introduced is exactly the "AI was wrong and here's how I noticed" story that
`AI_NOTES.md` requires (D4).
