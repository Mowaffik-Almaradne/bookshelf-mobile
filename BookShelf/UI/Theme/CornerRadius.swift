import CoreGraphics

/// Corner radius scale. Covers and chips use these names so no view hard-codes
/// a radius that should stay consistent across the kit.
nonisolated enum CornerRadius {
    /// Subtle rounding, 4 pt.
    static let small: CGFloat = 4
    /// Default card/cover rounding, 8 pt.
    static let medium: CGFloat = 8
    /// Emphasized rounding, 12 pt.
    static let large: CGFloat = 12
}
