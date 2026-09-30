# Prompt 11 — Phase 8: accessibility, Dynamic Type, Dark Mode, Arabic & iPad

**Attach:** `@docs/08_UI_ACCESSIBILITY_LOCALIZATION.md @docs/12_CODE_STANDARDS.md`

**Carries:** Q6, plus optional O3 (Arabic/RTL) and O4 (iPad). This is an **audit and fix** pass,
not a redesign — the components were built with these rules, so the job is proving it and
closing gaps.

**Do yourself after the agent finishes:** Accessibility Inspector audit on each screen, VoiceOver
walkthrough, Settings ▸ Accessibility ▸ Larger Text at maximum, and the scheme's App Language set
to Arabic. Feed anything you find back with `91_FIX.md`.

**Commits:** 2 (`a11y: VoiceOver labels, adaptive rows and dark mode audit`,
`l10n: Arabic strings and RTL fixes`).

---

```
Phase 8 of docs/13_IMPLEMENTATION_PLAN.md: an accessibility, Dynamic Type, Dark Mode,
localization and iPad AUDIT with minimal fixes. Do not redesign anything and do not change
behaviour — only close gaps against docs/08.

STEP 1 — AUDIT (report before fixing)
Read every file in BookShelf/Features/ and BookShelf/UI/ and produce a findings table:
file | line | rule violated | proposed fix. Check for:
 a. Controls with no accessibility label; icon-only buttons not using Label + .labelStyle(.iconOnly).
 b. Rows not combining children for VoiceOver; decorative covers not .accessibilityHidden(true).
 c. Missing accessibility hints on Save/Retry/Delete.
 d. Any hard-coded colour (Color.white/.black/hex/RGB) or font size (.system(size:)).
 e. Any fixed spacing/size number that should come from UI/Theme.
 f. lineLimit applied at accessibility sizes, or any use of minimumScaleFactor.
 g. Rows not switching to a vertical layout at accessibility sizes (AdaptiveRowLayout unused).
 h. Literal user-facing strings not in the String Catalog.
 i. left/right instead of leading/trailing; chevron.right/.left instead of .forward/.backward.
 j. Numbers formatted with grouping (years must render as 1997, never 1,997 or ١٬٩٩٧).
 k. Animations not respecting @Environment(\.accessibilityReduceMotion).
 l. Missing #Preview variants (dark, .accessibility3, RTL).

STEP 2 — FIX
Apply every finding. Additionally:
- Post an accessibility announcement when the first page of search results arrives
  (`AccessibilityNotification.Announcement`), stating the number of results.
- Add `.accessibilityIdentifier` to the search field, the retry button, the save button and the
  Shelf tab (cheap, and enables a UI smoke test later).
- Complete Resources/Localizable.xcstrings: every key has a natural Arabic translation. Use the
  examples in docs/08 as the baseline vocabulary (بحث، الرف، حفظ في الرف، إزالة من الرف،
  إعادة المحاولة، لا يوجد اتصال بالإنترنت، لا توجد نتائج لـ، نهاية النتائج). Keep Arabic short and
  idiomatic — a reviewer may be a native speaker. Flag any key you are unsure about instead of
  inventing clumsy phrasing.
- iPad: details content maxWidth 700 centred; in regular horizontal size class use ViewThatFits
  to place the cover beside the text block instead of above it. Nothing more — no NavigationSplitView.

STEP 3 — VERIFY
Re-run the build and tests, then report a final table: file | what changed | which rule it
satisfies. List anything you could NOT fix and why.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'Color\.white|Color\.black|#[0-9a-fA-F]{6}|\.font\(\.system\(size:' BookShelf/ || echo "no hard-coded styling"
rg -n '\.leading\b.*\.left|\.trailing\b.*\.right|chevron\.(right|left)' BookShelf/ || echo "no directional hard-coding"
rg -n 'minimumScaleFactor' BookShelf/ || echo "no minimumScaleFactor"
rg -n 'Text\("' BookShelf/Features BookShelf/UI || echo "review each hit: literal strings must be catalog keys"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings.
- iOS 17.0 deployment target. Apple frameworks only: no packages, no Combine.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `print`,
  `Task.detached`, `@unchecked Sendable` in app code, `AnyView`, hard-coded colours or font
  sizes, minimumScaleFactor.
- Only semantic colours and system text styles; @ScaledMetric for size constants.
- Every user-facing string localized through the String Catalog (en + ar).
- Every interactive control has an accessibility label; icon-only controls use
  `Label(...)` + `.labelStyle(.iconOnly)`.
- SCOPE: audit and fix only. Do NOT change behaviour, rename types, restructure files, add
  features or "improve" the design. If a fix would change behaviour, list it and ask first.
- FINISH BY: running build + tests + greps, pasting the exact result lines, the before/after
  findings tables, and proposing two commit messages. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- Fixes belong in the shared component, not copied into each screen. If the same gap appears in
  three screens, fix it once in UI/Components or UI/Theme and report the consolidation.
- Adding a preview variant is preferred over adding a new component.
```
