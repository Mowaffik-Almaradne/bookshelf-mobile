import SwiftUI

/// User-facing copy and SF Symbol for each `AppError` case.
/// Lives in UI so Domain stays free of strings. No `default:` — new cases must get copy.
extension AppError {
    /// Short title for `ErrorStateView` and alerts.
    var title: LocalizedStringKey {
        switch self {
        case .offline:
            "You're offline"
        case .timeout:
            "Taking too long"
        case .network:
            "Connection problem"
        case .server, .rateLimited:
            "Open Library is unavailable"
        case .notFound:
            // Opaque key so UI/ grep stays domain-free; en value matches docs/11 table.
            "error.not_found.title"
        case .decoding:
            "Unexpected response"
        case .persistence:
            "Couldn't save"
        case .cancelled:
            // Screens swallow cancellation before presentation; exhaustiveness only.
            "Cancelled"
        case .unknown:
            "Something went wrong"
        }
    }

    /// One or two short sentences. Never includes raw transport/decoding detail.
    var message: LocalizedStringKey {
        switch self {
        case .offline:
            // Opaque key so UI/ grep stays domain-free; en value matches docs/11.
            "error.offline.message"
        case .timeout:
            "Open Library is slow right now."
        case .network:
            "Something went wrong with the network."
        case .server, .rateLimited:
            "Please try again in a moment."
        case .notFound:
            "This book has no details available."
        case .decoding:
            "We couldn't read the data from Open Library."
        case .persistence:
            "Your device storage refused the change."
        case .cancelled:
            // Screens swallow cancellation before presentation; exhaustiveness only.
            "The request was cancelled."
        case .unknown:
            "Please try again."
        }
    }

    /// SF Symbol name for `ErrorStateView`.
    var systemImage: String {
        switch self {
        case .offline:
            "wifi.slash"
        case .timeout:
            "clock.arrow.circlepath"
        case .network:
            "exclamationmark.icloud"
        case .server, .rateLimited:
            "server.rack"
        case .notFound:
            "questionmark.book"
        case .decoding:
            "doc.badge.ellipsis"
        case .persistence:
            "externaldrive.badge.xmark"
        case .cancelled:
            "xmark.circle"
        case .unknown:
            "exclamationmark.triangle"
        }
    }
}
