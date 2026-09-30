import Foundation

/// A validated `/works/OL…` path.
///
/// Details requests are built only from this type, so a search hit with a
/// missing key or an author path can never be turned into a URL.
nonisolated struct WorkKey: Hashable, Sendable, Codable {
    /// Canonical path such as `/works/OL45804W`.
    let rawValue: String

    /// Accepts values that start with `/works/` and contain a single path
    /// segment after the prefix. Anything else is not a work we can open.
    init?(rawValue: String) {
        let prefix = "/works/"
        guard rawValue.hasPrefix(prefix) else { return nil }
        let identifier = rawValue.dropFirst(prefix.count)
        guard !identifier.isEmpty, identifier.contains("/") == false else { return nil }
        self.rawValue = rawValue
    }

    /// Relative path for the work document (`/works/OL45804W.json`).
    var detailsPath: String { rawValue + ".json" }
}
