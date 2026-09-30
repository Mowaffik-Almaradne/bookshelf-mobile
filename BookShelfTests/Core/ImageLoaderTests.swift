import Foundation
import Testing
import UIKit
@testable import BookShelf

@Suite struct ImageLoaderTests {
    @Test func secondRequestForSameURL_isServedFromMemory() async throws {
        let harness = try makeHarness()
        let png = try makePNG(width: 1000, height: 1500)
        URLProtocolStub.enqueue(data: png, status: 200, id: harness.id)

        let size = CGSize(width: 60, height: 90)
        _ = try await harness.loader.image(for: harness.url, targetSize: size, scale: 3)
        _ = try await harness.loader.image(for: harness.url, targetSize: size, scale: 3)

        #expect(URLProtocolStub.requestCount(id: harness.id) == 1)
    }

    @Test func concurrentRequests_areDeduplicated() async throws {
        let harness = try makeHarness()
        let png = try makePNG(width: 1000, height: 1500)
        URLProtocolStub.enqueue(data: png, status: 200, id: harness.id)

        let size = CGSize(width: 60, height: 90)
        try await withThrowingTaskGroup(of: UIImage.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await harness.loader.image(for: harness.url, targetSize: size, scale: 2)
                }
            }
            for try await _ in group {}
        }

        #expect(URLProtocolStub.requestCount(id: harness.id) == 1)
    }

    @Test func notFound_throwsAndDoesNotCache() async throws {
        let harness = try makeHarness()
        URLProtocolStub.enqueue(data: Data("missing".utf8), status: 404, id: harness.id)
        URLProtocolStub.enqueue(data: Data("missing".utf8), status: 404, id: harness.id)

        let size = CGSize(width: 60, height: 90)
        await #expect(throws: AppError.notFound) {
            try await harness.loader.image(for: harness.url, targetSize: size, scale: 2)
        }
        await #expect(throws: AppError.notFound) {
            try await harness.loader.image(for: harness.url, targetSize: size, scale: 2)
        }

        #expect(URLProtocolStub.requestCount(id: harness.id) == 2)
    }

    @Test func downsample_producesRequestedPixelSize() async throws {
        let png = try makePNG(width: 1000, height: 1500)
        let image = try #require(
            await ImageDownsampler.downsample(png, to: CGSize(width: 180, height: 270))
        )
        let maxSide = max(
            image.size.width * image.scale,
            image.size.height * image.scale
        )
        #expect(maxSide <= 270)
    }

    @Test func differentTargetSizes_useDifferentCacheEntries() async throws {
        let harness = try makeHarness()
        let png = try makePNG(width: 1000, height: 1500)
        URLProtocolStub.enqueue(data: png, status: 200, id: harness.id)
        URLProtocolStub.enqueue(data: png, status: 200, id: harness.id)

        let row = CGSize(width: 60, height: 90)
        let detail = CGSize(width: 180, height: 270)
        _ = try await harness.loader.image(for: harness.url, targetSize: row, scale: 3)
        _ = try await harness.loader.image(for: harness.url, targetSize: detail, scale: 3)
        #expect(URLProtocolStub.requestCount(id: harness.id) == 2)

        _ = try await harness.loader.image(for: harness.url, targetSize: row, scale: 3)
        _ = try await harness.loader.image(for: harness.url, targetSize: detail, scale: 3)
        #expect(URLProtocolStub.requestCount(id: harness.id) == 2)
    }

    private func makeHarness() throws -> Harness {
        let id = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        configuration.httpAdditionalHeaders = ["X-Stub-ID": id]
        let session = URLSession(configuration: configuration)
        let url = try #require(URL(string: "https://covers.openlibrary.org/b/id/1-M.jpg"))
        return Harness(id: id, loader: ImageLoader(session: session), url: url)
    }

    private func makePNG(width: Int, height: Int) throws -> Data {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try #require(image.pngData())
    }

    private struct Harness {
        let id: String
        let loader: ImageLoader
        let url: URL
    }
}
