import UIKit

/// Actor-backed cover loader: memory cache, in-flight de-duplication, URLCache disk.
///
/// Cache keys include pixel size so a row thumbnail and a details hero never
/// share an entry. In-flight de-duplication is a deliberate trade-off: if the
/// first awaiter of a shared task is cancelled, other awaiters may see
/// `CancellationError` and re-request on the next `.task` — acceptable for covers.
actor ImageLoader: ImageLoading {
    private let session: URLSession
    private let memory = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage, Error>] = [:]
    private var memoryWarningTask: Task<Void, Never>?

    /// - Parameters:
    ///   - session: Dedicated covers session (large disk URLCache). Injectable for tests.
    ///   - memoryLimitBytes: NSCache cost budget; cost is decoded byte size.
    init(session: URLSession = .covers, memoryLimitBytes: Int = 64 * 1024 * 1024) {
        self.session = session
        memory.totalCostLimit = memoryLimitBytes
        // Observer must start after init: capturing `self` in a Task forbids
        // assigning isolated stored properties in the same initializer.
        Task { await self.installMemoryWarningObserver() }
    }

    deinit {
        memoryWarningTask?.cancel()
    }

    func image(for url: URL, targetSize: CGSize, scale: CGFloat) async throws -> UIImage {
        let key = cacheKey(url: url, targetSize: targetSize, scale: scale)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }

        if let running = inFlight[key] {
            return try await running.value
        }

        let task = Task<UIImage, Error> {
            let data = try await self.imageData(for: url)
            let pixelSize = CGSize(
                width: targetSize.width * scale,
                height: targetSize.height * scale
            )
            guard let image = await ImageDownsampler.downsample(data, to: pixelSize) else {
                throw AppError.decoding("image")
            }
            return image
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let image = try await task.value
        memory.setObject(image, forKey: key as NSString, cost: Self.decodedByteCost(of: image))
        return image
    }

    /// Validates HTTP success and rejects empty bodies. Open Library returns 404
    /// for missing covers when `CoverURL` appends `?default=false`.
    func imageData(for url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty
        else {
            throw AppError.notFound
        }
        return data
    }

    /// Pixel dimensions are part of the key so differently sized requests do not collide.
    private func cacheKey(url: URL, targetSize: CGSize, scale: CGFloat) -> String {
        let width = Int(targetSize.width * scale)
        let height = Int(targetSize.height * scale)
        return "\(url.absoluteString)@\(width)x\(height)"
    }

    private func installMemoryWarningObserver() {
        guard memoryWarningTask == nil else { return }
        memoryWarningTask = Task { [weak self] in
            await self?.purgeOnMemoryWarnings()
        }
    }

    private func purgeOnMemoryWarnings() async {
        let stream = NotificationCenter.default.notifications(
            named: UIApplication.didReceiveMemoryWarningNotification
        )
        for await _ in stream {
            memory.removeAllObjects()
        }
    }

    /// NSCache cost: decoded bitmap bytes (`bytesPerRow * height`).
    private nonisolated static func decodedByteCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            let pixels = image.size.width * image.scale * image.size.height * image.scale
            return Int(pixels * 4)
        }
        return cgImage.bytesPerRow * cgImage.height
    }
}
