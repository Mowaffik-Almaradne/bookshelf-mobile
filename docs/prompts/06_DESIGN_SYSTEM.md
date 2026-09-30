# Prompt 06 — Phase 4a: the design system (reusable components)

**Attach:** `@docs/08_UI_ACCESSIBILITY_LOCALIZATION.md @docs/11_ERROR_HANDLING_AND_LOGGING.md @docs/12_CODE_STANDARDS.md`

**Why before the screens:** if you build the Search screen first and extract components later,
you get components shaped by one screen. Building the kit first, with previews only and no
feature dependencies, is what makes Search, Shelf and Details thin.

Every component here is **app-agnostic**: it must not know what a `Book` is, must not call a
ViewModel, and must not perform I/O. That constraint is the whole point of the phase.

**Commit:** 1 (`feat(ui): reusable component kit with previews`).

---

```
Phase 4a of docs/13_IMPLEMENTATION_PLAN.md: build the reusable UI component kit BEFORE any
screen. These components are app-agnostic: they take primitives, enums and closures, and they
know nothing about Book, Shelf, networking or persistence. Follow docs/08 for the accessibility
and Dynamic Type rules.

APP FILES — BookShelf/UI/
Theme/
- Theme/Spacing.swift, Theme/CoverSize.swift — extend the namespaces created in Phase 0 if
  anything is missing (spacing scale, cover sizes, corner radius scale). No view may hard-code
  a number that belongs here.

Components/ (each file: one struct, previews at the bottom)
1. CoverPlaceholder.swift
   Inputs: `title: String`, `size: CGSize`. Rounded rect in Color(.tertiarySystemFill) with
   `Image(systemName: "book.closed")` and the first character of the title. Decorative:
   `.accessibilityHidden(true)`.
2. CoverView.swift
   Inputs: `coverID: Int?`, `preloadedData: Data?`, `size: CoverSize` (enum: .row, .detail),
   `title: String` (for the placeholder letter only). For now it renders CoverPlaceholder always
   — prompt 08 replaces the internals with RemoteImage. Define the public interface now and do
   NOT change it later: this is the seam between the UI kit and the image pipeline.
   `@ScaledMetric(relativeTo: .body)` width so covers grow with Dynamic Type.
3. ErrorStateView.swift
   Inputs: `title: LocalizedStringKey`, `message: LocalizedStringKey`, `systemImage: String`,
   `retryTitle: LocalizedStringKey?`, `onRetry: (() -> Void)?`. Built on ContentUnavailableView
   with a bordered-prominent retry button when a closure is supplied. Retry button must have an
   accessibility label supplied by the caller (parameter `retryAccessibilityLabel`).
4. LoadingFooterView.swift
   Inputs: an enum `FooterState { case hidden, loading, retry(LocalizedStringKey), end }` and
   `onRetry: () -> Void`. Renders a centered ProgressView with accessibility label
   "Loading more results", an inline retry row, or an end caption. No business logic.
5. OfflineBanner.swift
   Input: none (fixed copy) — a thin bar with `wifi.slash`, localized text, semantic colours,
   accessibility label per docs/08.
6. InfoRow.swift
   Inputs: `label: LocalizedStringKey`, `value: String`. A small reusable label/value row for
   details metadata (first published, etc.), combining children for VoiceOver.
7. FlowLayout.swift
   A `Layout` conformance that wraps subviews onto multiple lines with a spacing parameter.
   Used later for subject chips. Must handle: zero subviews, a subview wider than the container,
   and proposals with nil width. Include a preview with 25 chips of varied length.
8. TagChip.swift
   Inputs: `text: String`. Capsule background, `.caption` font, semantic colours, truncation at
   one line, `.accessibilityLabel(text)`.
9. AdaptiveRowLayout.swift
   A tiny wrapper returning `AnyLayout(HStackLayout(...))` normally and
   `AnyLayout(VStackLayout(...))` when `dynamicTypeSize.isAccessibilitySize`, so every list row
   in the app gets the same adaptive behaviour from one place. (AnyLayout is the one permitted
   type-erasure — it is the Layout API's intended usage, not AnyView.)

PRESENTATION MAPPING — BookShelf/UI/Presentation/AppError+Presentation.swift
Extension on AppError giving `title`, `message`, `systemImage` exactly per the table in docs/11,
all localized. This lives in UI (not Domain) so the Domain stays free of copy. No `default:` case
in the switch — the compiler must force us to write copy for any new error.

LOCALIZATION
Add every new string to Resources/Localizable.xcstrings with natural Arabic translations
(use the examples in docs/08). No literal user-facing English anywhere in the component bodies
except as the source key.

PREVIEWS (mandatory, this is how we verify without screens)
For each component a `#Preview` group covering: light, dark (`.preferredColorScheme(.dark)`),
`.dynamicTypeSize(.accessibility3)`, and RTL (`.environment(\.layoutDirection, .rightToLeft)`)
for anything directional. Previews must use literal sample data — no dependencies, no network.

ACCEPTANCE
- `rg -n "Book|Shelf|Catalog|ViewModel|URLSession|SwiftData" BookShelf/UI/` returns nothing.
  The kit is app-agnostic; report the output of this grep.
- No component starts a Task, holds @State that outlives one interaction, or does navigation.
- Every component ≤ 150 lines including previews.
- All strings localized; all icon-only controls labelled.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'Color\.white|Color\.black|#[0-9a-fA-F]{6}|\.font\(\.system\(size:' BookShelf/UI/ || echo "no hard-coded styling"
rg -n 'Book|Shelf|Catalog|ViewModel|URLSession|SwiftData' BookShelf/UI/ || echo "kit is app-agnostic"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor.
- iOS 17.0 deployment target. Apple frameworks only. No Combine.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError`, `print`, `DispatchQueue`,
  `Task.detached`, `@unchecked Sendable`, `AnyView` (AnyLayout is allowed and required in
  AdaptiveRowLayout), hard-coded colours, hard-coded font sizes, magic spacing numbers.
- Only semantic colours (.primary, .secondary, Color(.systemBackground), .tint) and system text
  styles. No minimumScaleFactor. No lineLimit at accessibility sizes.
- Every user-facing string localized through the String Catalog (en + ar).
- Every interactive control has an accessibility label; icon-only controls use
  `Label(...)` + `.labelStyle(.iconOnly)`.
- `///` doc comments on every component: what it is for, what it must NOT know about.
- SCOPE: implement exactly the nine components + theme + error presentation listed. No screens,
  no ViewModels, no extra "nice to have" components. If something looks wrong, STOP and tell me.
- FINISH BY: running build + the two greps, pasting the exact result lines, listing assumptions,
  and proposing the commit message. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- Components are PURE: state in, callbacks out. No ViewModel references, no I/O, no navigation.
- Prefer enums and closures over boolean flags with hidden meaning.
- If a component needs feature knowledge to be useful, it belongs in Features/<X>/Components/,
  not here — say so instead of weakening the boundary.
- Reusable layout behaviour (adaptive rows, flow) lives in ONE place used by every screen.
```
