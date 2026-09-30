# Prompt 02 — Phase 0: project setup & skeleton

**Attach:** `@docs/02_ARCHITECTURE.md @docs/12_CODE_STANDARDS.md @docs/13_IMPLEMENTATION_PLAN.md`

**Do these in Xcode yourself first** (5 minutes, the agent cannot):

1. Target `BookShelf` ▸ General ▸ Minimum Deployments → **iOS 17.0** (currently 26.5).
2. Build Settings ▸ Swift Language Version → **Swift 6**. Leave *Default Actor Isolation =
   MainActor* and *Approachable Concurrency = Yes* as they are.
3. File ▸ New ▸ Target ▸ **Unit Testing Bundle** → name `BookShelfTests`, Testing System
   **Swift Testing**, Target to be Tested `BookShelf`.
4. Product ▸ Scheme ▸ Manage Schemes → tick **Shared** for `BookShelf`.
5. Signing & Capabilities ▸ Bundle Identifier → `com.<yourname>.bookshelf` (currently `Test.BookShelf`).

**Commits:** 2 (`chore: target iOS 17…`, `chore: project skeleton…`).

---

```
Phase 0 of docs/13_IMPLEMENTATION_PLAN.md.

PRECONDITION CHECK (do this first)
Read BookShelf.xcodeproj/project.pbxproj and report a table of: IPHONEOS_DEPLOYMENT_TARGET,
SWIFT_VERSION, SWIFT_DEFAULT_ACTOR_ISOLATION, SWIFT_APPROACHABLE_CONCURRENCY,
PRODUCT_BUNDLE_IDENTIFIER, whether a BookShelfTests target exists, and whether a shared scheme
exists at BookShelf.xcodeproj/xcshareddata/xcschemes/. Expected: 17.0, 6.0, MainActor, YES,
com.<name>.bookshelf, test target present, shared scheme present. If anything differs, STOP and
tell me exactly what to fix in Xcode. Never edit project.pbxproj yourself.

DELIVERABLES
1. `.gitignore` at repo root covering: DerivedData/, build/, *.xcuserstate, xcuserdata/,
   .DS_Store, *.ipa, *.dSYM.zip, .swiftpm/, timeline.xctimeline, *.moved-aside.
   Then run `git rm -r --cached BookShelf.xcodeproj/xcuserdata` if it is tracked, and report
   `git status --short`.
2. Delete `BookShelf/ContentView.swift`.
3. Create the folder layout from docs/02 "Folder structure". Create ONLY these real files now —
   do not create empty placeholder files for future phases:
   - `BookShelf/App/BookShelfApp.swift` — @main, no boilerplate header comment, renders RootView.
   - `BookShelf/App/RootView.swift` — TabView with two tabs ("Search", "Shelf") each showing
     `ContentUnavailableView` placeholders, using `Label(_:systemImage:)` tab items
     ("magnifyingglass", "books.vertical"), wrapped in NavigationStack.
   - `BookShelf/App/AppDependencies.swift` — `@MainActor @Observable final class AppDependencies`
     with no dependencies yet, a `static func preview() -> AppDependencies`, and a `///` comment
     stating it is the composition root and will own the catalog, shelf, images and connectivity.
   - `BookShelf/Core/Logging/Log.swift` — `nonisolated enum Log` with os.Logger categories
     network, decoding, persistence, images, ui (subsystem from Bundle.main.bundleIdentifier with
     a non-crashing fallback).
   - `BookShelf/UI/Theme/Spacing.swift` and `BookShelf/UI/Theme/CoverSize.swift` — `nonisolated
     enum` namespaces of constants (spacing scale 4/8/12/16/24; cover sizes row 60x90, detail
     180x270 as CGSize) with `///` explaining that no view may hard-code these numbers.
4. `BookShelf/Resources/Localizable.xcstrings` — String Catalog with `en` as source language and
   an `ar` locale, containing every string used so far (tab titles, the two placeholder empty
   states). Write valid .xcstrings JSON (version "1.0", sourceLanguage "en", strings object with
   localizations per language, stringUnit with state "translated").
5. Remove the Xcode template header comments ("//  Created by … on …") from every remaining file.
6. `scripts/test.sh` — executable bash script, `set -euo pipefail`, runs the xcodebuild test
   command below.

VERIFY AND REPORT
Run the three commands in the VERIFICATION block, paste the exact summary lines, then propose the
two commit messages in the format of docs/12 "Git conventions".

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' BookShelf/ || echo "grep clean"

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
- `///` doc comments on every type and protocol requirement, explaining WHY and the invariants.
- SCOPE: implement exactly what this prompt lists. Do not add files, features, abstractions or
  refactors that were not requested. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + grep, pasting the exact result lines, listing assumptions,
  and proposing commit messages. Do not commit yourself.
```
