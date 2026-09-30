# Shared rule blocks

These two blocks are already inlined at the bottom of every prompt in this folder. This file is
the single source of truth — if you change a rule here, update the prompts (or tell the agent
"apply the rules in `@docs/prompts/00_SHARED_RULES.md`" instead of pasting).

---

## Block A — Non-negotiables

```
NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor,
  approachable concurrency is ON: a plain `nonisolated async` func runs on the CALLER's executor,
  so CPU-heavy work (JSON decoding, image decoding) MUST be `@concurrent nonisolated`.
- Types used off the main actor (DTOs, domain models, clients, static lets in extensions) must be
  explicitly `nonisolated` and `Sendable`.
- iOS 17.0 deployment target. Apple frameworks only: no SPM/CocoaPods packages, no Combine,
  no ObservableObject/@Published. Use @Observable, SwiftData, Swift Testing.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code,
  `AnyView`, hard-coded colours or font sizes, URLs built by string interpolation of user input.
- Layering: Views never touch URLSession/SwiftData. ViewModels never import SwiftUI or SwiftData.
  Domain imports Foundation only. DTOs never leave the Data layer.
- Every I/O dependency is a protocol injected through `init`. No singletons read from Views.
- Every user-facing string is localized through the String Catalog (en + ar).
- Every interactive control has an accessibility label; icon-only controls use
  `Label(...)` + `.labelStyle(.iconOnly)`.
- `///` doc comments on every type and protocol requirement, explaining WHY and the invariants,
  not restating the code. Every `try?` gets a one-line comment saying why failure is acceptable.
- Tests: Swift Testing, deterministic, no sleeps for synchronisation, fixtures from real API
  responses. Write tests in the same commit as the code they test.
- SCOPE: implement exactly what this prompt lists. Do not add files, features, abstractions or
  refactors that were not requested. If something in the docs looks wrong, STOP and tell me
  instead of improvising.
- FINISH BY: running build + tests + the forbidden-pattern grep, pasting the exact result lines,
  listing any assumption you made, and proposing the commit message(s). Do not commit yourself.
```

---

## Block B — Component & scalability rules

```
COMPONENT & SCALABILITY RULES
- One primary type per file; file name == type name; target ≤ 150 lines, hard limit 250.
  If a view body exceeds ~40 lines, extract a child View struct (not a computed property).
- Three kinds of view types, never mixed:
  1. SCREEN (Features/<Feature>/<Name>View.swift): owns a ViewModel, does navigation, composes
     sections. No layout maths, no formatting, no business logic.
  2. SECTION (Features/<Feature>/Components/): feature-specific, takes plain values + closures.
  3. COMPONENT (UI/Components/): app-agnostic, knows nothing about Book/Shelf/networking. Inputs
     are primitives or generics + closures. Reusable in any screen.
- Components are PURE: no @Environment dependency on app services except the injected image
  loader, no ViewModel references, no Task started inside except via an injected loader, no
  navigation. State in, callbacks out.
- Prefer generics/closures over booleans-with-meaning. No `isShelfMode: Bool` style flags.
- Every component and every screen state gets a `#Preview` (light, dark, `.accessibility3`,
  and RTL where layout is directional). Previews use fixture/preview dependencies, never live network.
- Reusable logic goes to a small value type with tests (like `Paginator`), not into a ViewModel.
- Spacing, corner radii and cover sizes come from `UI/Theme` constants, never magic numbers
  scattered in views.
- Before adding a type, grep the repo for an existing one that does the job; extend it instead of
  duplicating. Report what you reused.
```

---

## Block C — Commit message format (for the agent's suggestions)

```
<type>(<scope>): <imperative subject ≤ 72 chars>

<why this change exists, what problem it solves, any trade-off — wrapped at 80 cols>

Refs: <requirement IDs from docs/01_TASK_SPEC.md>
```

Types: `feat`, `fix`, `test`, `refactor`, `perf`, `docs`, `chore`, `a11y`, `l10n`.

---

## Block D — Verification commands (agent must run and paste output)

```bash
xcodebuild build -scheme BookShelf \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet

xcodebuild test -scheme BookShelf \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet

rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' \
  BookShelf/ || echo "grep clean"
```
