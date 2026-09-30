import SwiftUI

/// Race-free remote cover view (R5.2).
///
/// Three layers protect against showing the wrong image after cell reuse:
/// 1. **Structural (sufficient alone):** state stores the image *with* the URL it
///    belongs to; the body renders it only when that URL equals the current one.
/// 2. **Cancellation:** `.task(id: url)` cancels the previous load when the URL changes.
/// 3. **Post-await:** `!Task.isCancelled` before assigning avoids writing a stale result.
///
/// Layer 1 alone is enough for correctness; 2 and 3 save bandwidth and wasted work.
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    let targetSize: CGSize
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.imageLoader) private var loader
    @Environment(\.displayScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Image paired with the URL it was loaded for — the structural race guard.
    @State private var loaded: Loaded?

    /// Pairs bytes with the request URL so a reused cell cannot show a neighbour’s cover.
    private struct Loaded {
        let url: URL
        let image: UIImage
    }

    private var displayedImage: UIImage? {
        guard let loaded, loaded.url == url else { return nil }
        return loaded.image
    }

    var body: some View {
        ZStack {
            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .frame(width: targetSize.width, height: targetSize.height)
        .clipped()
        .animation(reduceMotion ? nil : .easeIn(duration: 0.2), value: displayedImage != nil)
        .task(id: url) {
            guard let url else { return }
            // Failure → keep placeholder; cancellation is not a user-visible error.
            if let image = try? await loader.image(for: url, targetSize: targetSize, scale: scale),
               !Task.isCancelled {
                loaded = Loaded(url: url, image: image)
            }
        }
    }
}
