import Foundation

/// Decision helper for whether a cover may hit the network.
///
/// Extracted from `CoverView` so offline / missing-bytes behaviour is unit-tested
/// without mounting SwiftUI. Saved books with `preloadedData` never need remote
/// bytes; when offline, missing bytes stay on the placeholder (R4.3 / O3).
nonisolated enum CoverLoadPolicy {
    /// Returns the cover id to fetch remotely, or `nil` to stay on placeholder /
    /// preloaded decode only.
    static func remoteCoverID(
        coverID: Int?,
        preloadedData: Data?,
        allowsNetwork: Bool
    ) -> Int? {
        guard allowsNetwork, preloadedData == nil, let coverID, coverID > 0 else {
            return nil
        }
        return coverID
    }
}
