# Prompt 08 — Phase 5: the image pipeline

**Attach:** `@docs/07_IMAGE_LOADING.md @docs/10_PERFORMANCE_AND_CONCURRENCY.md @docs/12_CODE_STANDARDS.md`

**Carries:** R5.1 (no UI blocking, placeholder), R5.2 (never the wrong image after reuse — the
bug the task is explicitly probing), Q5 (heavy work off the main thread).

`CoverView`'s public interface was fixed in prompt 06; this phase only replaces its internals,
so no screen needs to change.

**Commit:** 1 (`feat(images): actor-based loader with downsampling and race-free RemoteImage`).

---

```
Phase 5 of docs/13_IMPLEMENTATION_PLAN.md: the image pipeline. Implement exactly docs/07.
Do not use AsyncImage anywhere — docs/07 explains why (no memory cache, no downsampling, no
in-flight de-duplication, not injectable, cannot serve persisted offline bytes).

APP FILES
- Core/Images/ImageLoading.swift
    `nonisolated protocol ImageLoading: Sendable` with
    `func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage` and
    `func imageData(for url: URL) async throws -> Data` (the second one is what the Shelf will
    use to persist offline covers).
- Core/Images/ImageDownsampler.swift
    `nonisolated enum ImageDownsampler` with
    `@concurrent static func downsample(_ data: Data, to pixelSize: CGSize) async -> UIImage?`
    using CGImageSourceCreateThumbnailAtIndex with kCGImageSourceShouldCache false,
    CreateThumbnailFromImageAlways, ShouldCacheImmediately, CreateThumbnailWithTransform and
    ThumbnailMaxPixelSize. The /// must state that @concurrent is mandatory: without it this
    nonisolated async function would inherit the caller's executor (the main actor) and decode
    images on the main thread.
- Core/Images/ImageLoader.swift
    `actor ImageLoader: ImageLoading` with: NSCache<NSString, UIImage> (totalCostLimit 64 MB,
    cost = decoded byte size), an in-flight [String: Task<UIImage, Error>] map for
    de-duplication, the dedicated `URLSession.covers`, and a memory-warning purge.
    Cache key MUST include the pixel size so a row thumbnail and a detail hero never collide.
    imageData(for:) validates the HTTP status and rejects empty bodies (a missing cover returns
    404 because CoverURL appends ?default=false).
    Document the known trade-off: if the first caller of a de-duplicated request is cancelled,
    a second awaiting caller receives CancellationError and will re-request on its next .task —
    acceptable for cover images.
- Core/Images/RemoteImage.swift
    A generic SwiftUI view `RemoteImage<Placeholder: View>` implementing the race-free design in
    docs/07: state stores the loaded image TOGETHER with the URL it belongs to, and the body
    renders it only when that URL equals the current one; `.task(id: url)` for cancellation;
    `!Task.isCancelled` checked before assigning. The /// must explain all three layers and say
    which one alone is sufficient for correctness (the url-keyed state).
- Core/Images/ImageLoaderEnvironment.swift
    An EnvironmentKey `\.imageLoader` whose default value is a no-op loader that always throws,
    so previews never hit the network and a missing injection fails visibly rather than silently
    downloading.
- UI/Components/CoverView.swift — replace the placeholder internals with RemoteImage while
  KEEPING the existing public interface (coverID, preloadedData, size, title). Order of
  resolution: preloadedData (decode via ImageDownsampler, no network — this is what makes saved
  covers work offline) → CoverURL for the coverID → CoverPlaceholder.
- App/AppDependencies.swift — own the live ImageLoader; App/BookShelfApp.swift — inject it into
  the environment.

TEST FILE — BookShelfTests/Core/ImageLoaderTests.swift
Run the REAL ImageLoader against URLProtocolStub on an ephemeral configuration. Generate test
PNG bytes in-test with UIGraphicsImageRenderer (e.g. 1000x1500).
 1. a second request for the same URL and size is served from memory → exactly 1 network hit
 2. 10 concurrent requests for the same URL → exactly 1 network hit (de-duplication)
 3. HTTP 404 → throws, and no entry is cached
 4. downsampling a 1000x1500 image to a 60x90pt @3x target produces a max side <= 270 px
 5. two different target sizes for the same URL produce two cache entries (no collision)

ACCEPTANCE
- No AsyncImage in the codebase (grep it).
- ImageDownsampler.downsample is @concurrent; no image decoding happens on the main actor.
- CoverView's call sites from Phase 4b compile unchanged.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'AsyncImage' BookShelf/ || echo "no AsyncImage"
rg -n 'UIImage\(data:' BookShelf/ || echo "no full-size decoding"
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' BookShelf/ || echo "grep clean"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor,
  approachable concurrency is ON: CPU-heavy work MUST be `@concurrent nonisolated`.
- Types used off the main actor must be explicitly `nonisolated` and `Sendable`; shared mutable
  caches are actors, never locks in app code.
- iOS 17.0 deployment target. Apple frameworks only: no packages, no Combine.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code,
  `AnyView`, AsyncImage, `UIImage(data:)` for display-sized decoding.
- Every I/O dependency is a protocol injected through init or the environment.
- `///` doc comments explaining WHY: the @concurrent requirement, the cache key composition, the
  three layers of race protection, the de-duplication trade-off.
- Tests in the same commit; deterministic; no sleeps for synchronisation; no real network.
- SCOPE: implement exactly what this prompt lists. No prefetching, no progressive JPEG, no
  custom disk cache beyond URLCache. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + greps, pasting the exact result lines, listing assumptions,
  and proposing the commit message. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- RemoteImage is generic over its placeholder and knows nothing about Book or Shelf.
- The loader is reachable only through the ImageLoading protocol; no screen references the actor
  type directly.
- One primary type per file; ≤ 150 lines target, 250 hard limit.
```
