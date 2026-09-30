import Foundation

/// Explicit search UI state. Prefer one enum over boolean flags so every
/// screen surface (idle / spinner / list / empty / error) is unreachable to skip.
/// `nonisolated` + `Sendable` so Equatable is not MainActor-isolated under
/// InferIsolatedConformances (test recorders require a Sendable Phase).
nonisolated enum SearchPhase: Equatable, Sendable {
    /// Query shorter than the minimum, or nothing started yet.
    case idle
    /// First page in flight; nothing safe to show yet.
    case loading
    /// At least one result. Footer carries pagination status without dropping items.
    case loaded(items: [Book], footer: Footer)
    /// Valid query returned zero docs.
    case empty
    /// First page failed. Full-screen error + Retry; pagination must not wipe this.
    case failed(AppError)

    /// Pagination chrome under a loaded list. Failures keep the items above.
    nonisolated enum Footer: Equatable, Sendable {
        case idle
        case loading
        case failed(AppError)
        case end
    }

    /// Items when loaded; empty otherwise so list builders need no switch.
    var items: [Book] {
        if case .loaded(let items, _) = self { return items }
        return []
    }

    /// True only for a first-page failure (refetch same query is allowed).
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Footer when loaded; `nil` in every other phase.
    var footer: Footer? {
        if case .loaded(_, let footer) = self { return footer }
        return nil
    }
}
