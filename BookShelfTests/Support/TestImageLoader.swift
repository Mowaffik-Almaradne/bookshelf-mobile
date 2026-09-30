import CoreGraphics
import Foundation
import UIKit
@testable import BookShelf

/// Controllable image loader for shelf and cover tests.
nonisolated struct TestImageLoader: ImageLoading {
    var data: Data?
    var image: UIImage?
    var throwsOnData: Bool = false

    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        if let image { return image }
        throw AppError.notFound
    }

    func imageData(for url: URL) async throws -> Data {
        if throwsOnData { throw AppError.network }
        guard let data else { throw AppError.notFound }
        return data
    }
}
