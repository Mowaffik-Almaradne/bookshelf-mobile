import Foundation

/// The only error type that crosses into view models. Transport and decoding
/// detail is mapped here so screens never branch on `URLError` or `HTTPError`.
/// `.cancelled` is not a failure the user should see.
nonisolated enum AppError: Error, Equatable, Sendable {
    case offline
    case timeout
    case network
    case server
    case rateLimited
    case notFound
    /// Debug detail for logs. Not shown to the user.
    case decoding(String)
    case persistence
    case cancelled
    case unknown

    /// Maps an unknown thrown error. Existing `AppError` values pass through,
    /// and task cancellation becomes `.cancelled` rather than `.unknown`.
    init(_ error: any Error) {
        if let app = error as? AppError {
            self = app
            return
        }
        if error is CancellationError {
            self = .cancelled
            return
        }
        if let http = error as? HTTPError {
            self = AppError(http: http)
            return
        }
        if let url = error as? URLError {
            self = AppError(http: .transport(url.code))
            return
        }
        self = .unknown
    }

    /// Mapping table for the HTTP client. Status and transport codes that the
    /// UI treats alike share a case so screens do not re-interpret status codes.
    init(http: HTTPError) {
        switch http {
        case .transport(.cancelled):
            self = .cancelled
        case .transport(.notConnectedToInternet), .transport(.networkConnectionLost),
             .transport(.dataNotAllowed), .transport(.internationalRoamingOff):
            self = .offline
        case .transport(.timedOut):
            self = .timeout
        case .transport:
            self = .network
        case .badStatus(404), .emptyBody:
            self = .notFound
        case .badStatus(429):
            self = .rateLimited
        case .badStatus(let code) where code >= 500:
            self = .server
        case .badStatus, .invalidURL:
            self = .unknown
        }
    }

    /// Whether a Retry button should be offered. Cancellation is silent, and a
    /// missing book will not appear on a second attempt.
    var isRetryable: Bool {
        self != .cancelled && self != .notFound
    }
}
