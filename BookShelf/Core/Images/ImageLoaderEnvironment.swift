import SwiftUI

/// Environment key for the cover pipeline. Default throws so `#Preview` never
/// hits the network and a missing injection fails visibly instead of downloading.
private enum ImageLoaderKey: EnvironmentKey {
    static let defaultValue: any ImageLoading = UnimplementedImageLoader()
}

extension EnvironmentValues {
    var imageLoader: any ImageLoading {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

/// Always throws. Used as the environment default and for preview composition.
nonisolated struct UnimplementedImageLoader: ImageLoading {
    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        throw AppError.unknown
    }

    func imageData(for url: URL) async throws -> Data {
        throw AppError.unknown
    }
}
