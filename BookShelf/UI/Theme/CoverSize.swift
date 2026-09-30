import CoreGraphics

/// Cover frame roles. Base points feed `@ScaledMetric` so thumbnails and heroes
/// grow with Dynamic Type without each screen hard-coding 60×90 or 180×270.
nonisolated enum CoverSize: Sendable {
    /// Search and shelf row cover.
    case row
    /// Details screen cover.
    case detail

    /// Unscaled width in points (aspect 2:3).
    var baseWidth: CGFloat {
        switch self {
        case .row: 60
        case .detail: 180
        }
    }

    /// Unscaled size in points (aspect 2:3).
    var baseSize: CGSize {
        CGSize(width: baseWidth, height: baseWidth * 3 / 2)
    }
}
