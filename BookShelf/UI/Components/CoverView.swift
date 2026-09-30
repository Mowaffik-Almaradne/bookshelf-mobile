import SwiftUI

/// Cover image surface shared by every list row and details hero.
/// Resolution order: `preloadedData` (offline decode, no network) → remote
/// `coverID` via `RemoteImage` (only when `allowsNetwork`) → `CoverPlaceholder`.
///
/// Preloaded path mirrors `RemoteImage`'s race guard: state stores the image
/// *with* the `Data` it was decoded from, and the body renders only on a match
/// (R5.2). `.task(id:)` cancels work on change; post-await checks cancellation.
struct CoverView: View {
    let coverID: Int?
    let preloadedData: Data?
    /// When false (airplane mode / offline banner), never start a remote cover
    /// request — even if `coverID` is set and offline bytes are missing.
    var allowsNetwork: Bool = true
    let size: CoverSize
    let title: String

    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .body) private var rowWidth = CoverSize.row.baseWidth
    @ScaledMetric(relativeTo: .body) private var detailWidth = CoverSize.detail.baseWidth

    /// Image paired with the bytes it was decoded from — structural race guard.
    @State private var loaded: Loaded?

    private struct Loaded {
        let data: Data
        let image: UIImage
    }

    private var displayedPreloaded: UIImage? {
        guard let loaded, let preloadedData, loaded.data == preloadedData else {
            return nil
        }
        return loaded.image
    }

    var body: some View {
        Group {
            if let image = displayedPreloaded {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: scaledSize.width, height: scaledSize.height)
                    .clipped()
            } else if let url = remoteURL {
                RemoteImage(url: url, targetSize: scaledSize) {
                    CoverPlaceholder(title: title, size: scaledSize)
                }
            } else {
                CoverPlaceholder(title: title, size: scaledSize)
            }
        }
        .accessibilityHidden(true)
        .task(id: preloadedData) {
            guard let preloadedData else {
                loaded = nil
                return
            }
            let pixelSize = CGSize(
                width: scaledSize.width * displayScale,
                height: scaledSize.height * displayScale
            )
            // Corrupt persisted bytes → placeholder; never block the row on failure.
            let image = await ImageDownsampler.downsample(preloadedData, to: pixelSize)
            guard !Task.isCancelled, let image else { return }
            loaded = Loaded(data: preloadedData, image: image)
        }
    }

    private var scaledWidth: CGFloat {
        switch size {
        case .row: rowWidth
        case .detail: detailWidth
        }
    }

    private var scaledSize: CGSize {
        CGSize(width: scaledWidth, height: scaledWidth * 3 / 2)
    }

    /// Skips the network when offline bytes exist, or when `allowsNetwork` is false.
    private var remoteURL: URL? {
        guard let id = CoverLoadPolicy.remoteCoverID(
            coverID: coverID,
            preloadedData: preloadedData,
            allowsNetwork: allowsNetwork
        ) else { return nil }
        let apiSize: CoverURL.Size = size == .row ? .medium : .large
        return CoverURL.url(coverID: id, size: apiSize)
    }
}

#Preview("Light") {
    CoverView(coverID: 42, preloadedData: nil, size: .row, title: "Dune")
        .padding()
}

#Preview("Dark") {
    CoverView(coverID: nil, preloadedData: nil, size: .detail, title: "Dune")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    CoverView(coverID: 1, preloadedData: nil, size: .row, title: "Dune")
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    CoverView(coverID: nil, preloadedData: nil, size: .row, title: "كثيب")
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Offline no bytes") {
    CoverView(
        coverID: 42,
        preloadedData: nil,
        allowsNetwork: false,
        size: .row,
        title: "Dune"
    )
    .padding()
}
