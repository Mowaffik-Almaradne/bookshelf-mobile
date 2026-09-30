import CoreGraphics
import Foundation
import UIKit

/// Injectable cover pipeline. Views and the shelf depend on this protocol, never
/// on `ImageLoader`, so previews and tests can substitute a stub and production
/// can share one actor-backed cache.
nonisolated protocol ImageLoading: Sendable {
    /// Decoded and downsampled for `targetSize` × `scale`. Cancellation-aware.
    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage

    /// Raw bytes for persisting offline shelf covers. Prefer serving from cache.
    func imageData(for url: URL) async throws -> Data
}
