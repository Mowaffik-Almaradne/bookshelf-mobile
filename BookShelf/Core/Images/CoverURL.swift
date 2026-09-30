import Foundation

/// Builds cover image URLs.
///
/// A missing cover id returns HTTP 200 with a 43-byte transparent GIF unless
/// `default=false` is set, which yields 404. The image loader treats that 404
/// as "no image" and shows a placeholder instead of an invisible picture.
nonisolated enum CoverURL {
    /// `S` is unused in rows; `M` is the row thumbnail source; `L` is details.
    nonisolated enum Size: String, Sendable {
        case small = "S"
        case medium = "M"
        case large = "L"
    }

    /// `nil` when `coverID` is not a positive Open Library id, or when the
    /// components cannot form a URL.
    static func url(coverID: Int, size: Size) -> URL? {
        guard coverID > 0 else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "covers.openlibrary.org"
        components.path = "/b/id/\(coverID)-\(size.rawValue).jpg"
        components.queryItems = [URLQueryItem(name: "default", value: "false")]
        return components.url
    }
}
