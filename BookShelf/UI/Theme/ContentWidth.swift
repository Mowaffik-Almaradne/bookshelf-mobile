import CoreGraphics

/// Readable content measure for large screens. Details uses this so iPad
/// paragraphs do not stretch edge-to-edge (docs/08 O4).
nonisolated enum ContentWidth {
    /// Centred details column on regular-width devices.
    static let details: CGFloat = 700
}
