import ImageIO
import UIKit

/// ImageIO thumbnail decode at a target pixel size.
///
/// `@concurrent` is mandatory: without it this `nonisolated async` function
/// would inherit the caller's executor (typically the main actor under
/// approachable concurrency) and decode bitmaps on the UI thread.
nonisolated enum ImageDownsampler {
    /// Returns a downsampled image, or `nil` when ImageIO cannot read `data`.
    @concurrent
    static func downsample(_ data: Data, to pixelSize: CGSize) async -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }
        let maxPixel = max(pixelSize.width, pixelSize.height)
        let thumbOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
