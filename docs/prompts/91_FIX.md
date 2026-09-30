# Prompt 91 — Fix loop (build failures, test failures, runtime bugs)

Use this instead of re-running an implementation prompt. Re-running a build prompt on existing
code makes the agent rewrite files it should not touch.

---

## For a build or test failure

```
The build/test output is below. Fix the ROOT CAUSE, not the symptom.

FORBIDDEN "fixes":
- Adding @unchecked Sendable or nonisolated(unsafe).
- Lowering the Swift language mode or disabling strict concurrency.
- Deleting, disabling, or weakening a test so it passes.
- Adding try!, force unwraps, or `as!` to satisfy the type checker.
- Wrapping things in MainActor.run or Task { } just to silence an isolation error, without
  understanding why the isolation is wrong.
- Broad refactors: change the minimum number of lines.

REQUIRED:
1. State in one or two sentences what was actually wrong.
2. State why your fix is correct under Swift 6 isolation and Sendable rules (or under the
   relevant framework's rules if it is not a concurrency issue).
3. If the failure reveals that a design in docs/ is wrong, say so explicitly — I would rather
   change the plan than bolt a workaround onto it.
4. Re-run the build and the tests and paste the exact output.

OUTPUT BELOW:
<paste the full xcodebuild error or test failure here>
```

## For a runtime bug found in manual QA

```
Manual QA finding.

WHAT I DID: <exact steps, e.g. "typed 'har' then quickly 'harry' on Very Bad Network">
WHAT I EXPECTED: <e.g. "only results for 'harry' ever appear">
WHAT HAPPENED: <exact symptom, including timing and what was on screen>
ENVIRONMENT: <simulator/device, iOS version, Network Link Conditioner profile, airplane mode>

Do this:
1. Read the relevant code and give me the ROOT CAUSE as a concrete sequence of events
   (which task, which await, which state write, in which order). Do not guess — if you need more
   information, tell me exactly what to capture.
2. Propose the minimal fix, and say whether it changes any documented behaviour.
3. Write a REGRESSION TEST that fails before the fix and passes after it. If the bug cannot be
   covered by a unit test, say why and describe the manual check instead.
4. Apply the fix, run build + tests, paste the output.
5. Tell me whether this bug class could exist anywhere else in the codebase, and where.
```

## For a "the AI wrote something suspicious" review

```
Explain this code to me as if I have to defend it in an interview tomorrow:

<paste the file or function>

Cover:
1. What it does, line by line where it is non-obvious.
2. Which actor/executor each part runs on, and how you know.
3. What happens under cancellation, under a slow network, and under a malformed response.
4. What would break if I deleted it.
5. A simpler alternative, if one exists, and the trade-off against the current version.

If any part of this code is unnecessary, wrong, or cargo-culted, say so plainly — I would rather
delete it than ship code I cannot explain.
```

This last one is not optional polish. The task's only condition on AI use is that you understand
and can modify every line; run it on anything you would hesitate to explain out loud.
