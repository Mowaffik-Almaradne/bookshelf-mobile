# 10 — Performance & concurrency rules

Requirement links: Q5 (UI never freezes), R5.1, R2.3, R1.3. Also the source for the README's
"how I kept the main thread free" paragraph.

## Concurrency rules (Swift 6, default MainActor isolation)

| # | Rule | Why |
|---|---|---|
| C1 | `SWIFT_VERSION = 6.0`; build with **zero** concurrency warnings. | Compile-time data-race freedom is the whole point |
| C2 | Views, ViewModels, `ShelfStore`, `AppDependencies`, `ConnectivityMonitor` are `@MainActor` (implicit via project default). | UI state must be mutated on main |
| C3 | Domain models & DTOs: `nonisolated struct … : Sendable`. | Cross actor boundaries freely |
| C4 | Anything CPU-heavy (`JSONDecoder.decode`, `CGImageSource` decoding) is `@concurrent nonisolated`. | Under SE-0461 a plain `nonisolated async` inherits the caller's (main) executor |
| C5 | Shared mutable caches are **actors** (`ImageLoader`). | Structured thread-safety, no locks in app code |
| C6 | Every async operation started by a ViewModel is a stored `Task` that is cancelled on new input and in `deinit`-equivalent (`onDisappear` not needed with `.task`). | Cancellation = both correctness (R1.3) and battery |
| C7 | Never `Task.detached` in app code. Never `DispatchQueue.main.async`. | Loses priority/cancellation; unstructured |
| C8 | No `@unchecked Sendable`, no `nonisolated(unsafe)` in app code. Allowed in test doubles with a lock and a comment. | |
| C9 | `URLSession` calls only via `async` APIs (`data(for:)`), never delegates/callbacks. | |
| C10 | `Task.sleep(for:)` only for debounce and the single details retry — never as synchronisation. | |

Common compile errors you will hit, and the correct fix (not the escape hatch):

| Error | Correct fix |
|---|---|
| "Main actor-isolated property cannot be referenced from a nonisolated context" | The type is UI-adjacent → keep it `@MainActor` and make the *caller* `await` from main; or the type is a value type → mark it `nonisolated` |
| "Sending 'x' risks causing data races" | Make `x` a `Sendable` struct/enum; if it's a class, it's probably in the wrong layer |
| "Non-sendable type 'ModelContext'" | Don't pass contexts around; `SwiftDataShelfRepository` owns `mainContext` and is `@MainActor` |
| `Task.sleep` cancelled → `CancellationError` | `try? await Task.sleep`, then `guard !Task.isCancelled` |

## Main-thread budget

| Operation | Where | Cost target |
|---|---|---|
| JSON decode (search 20 docs) | `@concurrent` | 0 ms on main |
| JSON decode (work, up to 100 KB) | `@concurrent` | 0 ms on main |
| DTO → domain mapping | inside the same `@concurrent` function (return domain, not DTO) | 0 ms on main |
| Image decode + downsample | `@concurrent` inside actor task | 0 ms on main |
| Paginator merge (Set insert ×20) | main (µs) | negligible |
| SwiftData fetch (≤ 200 rows) | main | < 5 ms; acceptable, documented |
| SwiftData save with cover blob | main, `.externalStorage` | < 10 ms; acceptable |

Rule of thumb documented in README: *"the main actor only ever touches already-decoded value
types."*

## SwiftUI rendering performance

- `List` (not `ScrollView + VStack`) for search/shelf → cell reuse, correct a11y rotor, swipe
  actions for free.
- Stable identity: `Book: Identifiable` by `WorkKey` — never `\.self` on structs with mutable
  fields, never index-based IDs (index IDs break animations and cause wrong-image bugs).
- Row `body` is cheap: no formatters created inline. Year: `Text(verbatim: String(year))` or a
  single static `NumberFormatter`/`FormatStyle` — `FormatStyle` is value-typed & cheap; prefer
  `Text(year, format: .number.grouping(.never))`.
- ViewModels are `@Observable`: views re-render only when a **read** property changes. Keep
  `phase` as the single rendered property; avoid many independent `@State`s that fan out updates.
- Avoid `AnyView`. Use `@ViewBuilder` switch on phase.
- `.task(id:)` for anything async in views; never `onAppear { Task { … } }` without cancellation.
- Text with 20+ subject chips: `LazyVGrid`/`FlowLayout` renders only what is needed.
- Images: `.clipped()` + fixed frame → no layout thrash when image arrives; fade `.transition(.opacity)`
  only (no spring/scale — cheaper and reduce-motion friendly).

## Network performance

- `fields=` on search cuts payload ~5×.
- `limit=20`: balanced between request count and payload; page size is a `Paginator` parameter.
- Prefetch threshold 5 rows before the end → next page usually ready before the user gets there.
- URLCache: repeated queries within the session are instant; covers `.returnCacheDataElseLoad`.
- `httpMaximumConnectionsPerHost = 6` for covers; the default 4–6 is fine, but explicit is
  documented.
- Debounce 350 ms: empirically the sweet spot (300 too eager on slow typists, 500 feels laggy).

## Memory

- `NSCache` cost = `bytesPerRow * height`; limit 64 MB; purge on memory warning.
- Row thumbnails at 60×90 pt @3x = 180×270 px ≈ 190 KB each → 300 covers ≈ 57 MB max, well
  within budget and evicted under pressure.
- Details `L` covers downsampled to ~ 240×360 pt @3x.
- Persisted `coverData` is the **`M` JPEG (~20–60 KB)**, not the decoded bitmap.
- No retain cycles: `Task { [weak self] … }` in ViewModels **only where the task can outlive the
  VM** (debounce). `.task` view modifiers already tie lifetime to the view.

## Launch

- No network at launch. `AppDependencies.live()` creates the ModelContainer (~10–30 ms) and reads
  the shelf; that is it. Search tab shows `.idle` instantly.
- `ConnectivityMonitor` starts at init; first callback arrives asynchronously — default `isOnline = true`
  so the app never *starts* by claiming offline.

## Verification (do this once before the video; note results in README "performance" bullet)

1. **Instruments ▸ SwiftUI** template: scroll search results fast for 10 s → no "long view body"
   markers, `Core Animation Commits` < 8 ms.
2. **Instruments ▸ Time Profiler**: main thread during scroll shows no `JSONDecoder`/`CGImageSource` frames.
3. **Xcode ▸ Debug ▸ Thread Performance Checker** enabled in scheme diagnostics; **Main Thread Checker** on.
4. **Network Link Conditioner** (Simulator: Settings ▸ Developer ▸ Network Link Conditioner ▸
   "3G"/"Very Bad Network"): typing remains fluid; spinner appears; Retry on timeout.
5. Memory graph after scrolling 300 results and popping details ×10: no leaked ViewModels.
6. Launch → `.idle` screen visible in < 400 ms on simulator (rough eyeball, not graded).

## "Slow network" behaviours the reviewer will probe (and our answers)

| Probe | Behaviour |
|---|---|
| Type fast while first response pending | Old request cancelled; only the latest query's results appear |
| Fling to bottom during slow page 2 | Footer spinner; exactly one page-2 request; no page-3 until page-2 arrives |
| Kill connection mid-scroll | Footer shows inline Retry; loaded rows stay |
| Kill connection before searching | Full-screen error + Retry + offline banner; Shelf tab fully functional |
| Cover URL 404 | Placeholder; no retry storm |
| Very slow details (15 s+) | Timeout → error with Retry; one automatic retry attempted first |
