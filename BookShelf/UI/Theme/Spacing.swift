import CoreGraphics

/// Spacing scale in points. Views use these names so layout stays consistent
/// and no screen hard-codes 4, 8, 12, 16, or 24.
nonisolated enum Spacing {
    /// Tight inset, 4 pt.
    static let xSmall: CGFloat = 4
    /// Compact gap, 8 pt.
    static let small: CGFloat = 8
    /// Default gap, 12 pt.
    static let medium: CGFloat = 12
    /// Screen padding, 16 pt.
    static let large: CGFloat = 16
    /// Section break, 24 pt.
    static let xLarge: CGFloat = 24
}
