import Foundation

/// Failures from the transport only. Callers map these to `AppError` so
/// `URLError` never reaches a view model. `.transport(.cancelled)` is kept
/// distinct so cancellation can be ignored instead of shown as a failure.
nonisolated enum HTTPError: Error, Sendable, Equatable {
    /// `URLComponents` could not produce a URL for this path.
    case invalidURL(String)
    /// The request failed before a usable HTTP response. The code is preserved,
    /// including `.cancelled` and `.timedOut`.
    case transport(URLError.Code)
    /// An HTTP status outside 200..<300.
    case badStatus(Int)
    /// A 2xx response with no bytes. Treated as missing data, not success.
    case emptyBody
}
