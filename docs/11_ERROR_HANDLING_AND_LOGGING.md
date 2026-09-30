# 11 — Error handling & logging

Requirement links: R1.5 (error + Retry), Q4 (no crash), R4.3 (offline), evaluator criterion
"handling hard cases".

## Principles

1. **One user-facing error type** (`AppError`) at the domain boundary. Transport/decoding/persistence
   details are mapped once, in one tested function, and never leak `URLError` or `DecodingError`
   into ViewModels or Views.
2. **Cancellation is not an error.** `.cancelled` is swallowed at the ViewModel; it never changes
   `phase`.
3. **Never lose data on error.** A failed page-2 keeps page-1; a failed refresh keeps the local copy.
4. **Every error state has an action** (Retry) or an explanation (offline banner) — no dead ends.
5. **No force unwraps, no `try!`, no `fatalError` reachable from runtime data.** `fatalError` is
   allowed only for programmer errors in `#Preview`/test wiring.

## `AppError`

```swift
nonisolated enum AppError: Error, Equatable, Sendable {
    case offline
    case timeout
    case network            // other transport failures
    case server             // 5xx
    case rateLimited        // 429
    case notFound           // 404 / empty body / cover missing
    case decoding(String)   // debug detail, not shown to user
    case persistence
    case cancelled
    case unknown

    /// Wrap any error thrown across the boundary.
    init(_ error: any Error) {
        if let app = error as? AppError { self = app; return }
        if error is CancellationError { self = .cancelled; return }
        if let http = error as? HTTPError { self = AppError(http: http); return }
        if let url = error as? URLError { self = AppError(http: .transport(url.code)); return }
        self = .unknown
    }

    init(http: HTTPError) {
        switch http {
        case .transport(.cancelled):                                   self = .cancelled
        case .transport(.notConnectedToInternet), .transport(.networkConnectionLost),
             .transport(.dataNotAllowed), .transport(.internationalRoamingOff): self = .offline
        case .transport(.timedOut):                                    self = .timeout
        case .transport:                                               self = .network
        case .badStatus(404), .emptyBody:                              self = .notFound
        case .badStatus(429):                                          self = .rateLimited
        case .badStatus(let code) where code >= 500:                   self = .server
        case .badStatus, .invalidURL:                                  self = .unknown
        }
    }

    var isRetryable: Bool { self != .cancelled && self != .notFound }
}
```

## User-facing copy (`AppError+Presentation.swift`, in Features or UI layer, localized)

| Case | Title | Message | Icon |
|---|---|---|---|
| `.offline` | You're offline | Check your connection. Your Shelf is still available. | `wifi.slash` |
| `.timeout` | Taking too long | Open Library is slow right now. | `clock.arrow.circlepath` |
| `.network` | Connection problem | Something went wrong with the network. | `exclamationmark.icloud` |
| `.server`, `.rateLimited` | Open Library is unavailable | Please try again in a moment. | `server.rack` |
| `.notFound` | Book not found | This book has no details available. | `questionmark.book` |
| `.decoding` | Unexpected response | We couldn't read the data from Open Library. | `doc.badge.ellipsis` |
| `.persistence` | Couldn't save | Your device storage refused the change. | `externaldrive.badge.xmark` |
| `.unknown` | Something went wrong | Please try again. | `exclamationmark.triangle` |

Keep messages ≤ 2 short sentences; never show raw error descriptions to users. The `decoding`
payload goes to logs only.

## Where each error surfaces

| Situation | Surface |
|---|---|
| First search page fails | Full-screen `ErrorStateView` + Retry (R1.5) |
| Next page fails | Inline footer row "Couldn't load more · Retry" (items kept) |
| Details fail, not saved | Full-screen error + Retry; Save still offered with seed data |
| Details refresh fails, saved | Silent (local copy shown) + "Showing saved copy" caption |
| Cover fails | Placeholder, silent |
| Save/remove fails | Non-blocking `alert` bound to `store.lastError` (auto-clears) |
| Offline (any screen) | `OfflineBanner` |
| Persistence container fails at launch | In-memory fallback + one-time alert "Your shelf can't be saved on this device" |

## Retry semantics

- `retry()` re-runs the **same** `activeQuery`/page with a new generation; it does not re-debounce.
- Retry buttons are disabled while a request is in flight (prevents double taps → duplicate pages).
- Details: 1 automatic retry on `.timeout`/`.server` after 1 s, then surfaced.

## Logging — `os.Logger`

```swift
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "BookShelf"
    static let network     = Logger(subsystem: subsystem, category: "network")
    static let decoding    = Logger(subsystem: subsystem, category: "decoding")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let images      = Logger(subsystem: subsystem, category: "images")
    static let ui          = Logger(subsystem: subsystem, category: "ui")
}
```

Rules:
- Log **once** at the boundary where the error is mapped (catalog/repository), at `.error` for
  failures, `.debug` for request start/finish with duration. Never log in Views.
- Use privacy annotations: `\(url, privacy: .public)` for API URLs (no user data other than the
  query — log the query as `.private`).
- Never `print`. Never log full response bodies (size; privacy). Log `data.count` and status.
- Logging must not be a dependency for correctness (no logic in log statements).

## Defensive decoding guarantees (Q4 — "no crash")

- All DTO properties optional except arrays we default to `[]` in mapping.
- `WorkKey(rawValue:)` is failable; malformed keys are dropped at mapping time.
- Array indices never accessed with `[0]`; use `.first`.
- `URL(string:)` results are always guarded; static URLs are built via `URLComponents` or checked
  once in a unit test.
- `try?` is allowed **only** for best-effort side paths (author names, cover bytes, background
  refresh), with a comment stating why failure is acceptable.
- Integer fields from the API are validated where they matter (`coverID > 0`, `page >= 1`).

## Grep gates (run before every commit — also in 12_CODE_STANDARDS)

```bash
rg -n '!\.|!\)|try!|as!|fatalError|print\(' BookShelf/ --glob '!*Preview*' \
  | rg -v '!=|// preview-only' && echo "❌ forbidden pattern found" || echo "✅ clean"
```
(Manually review any hit; `!` in `!isOnline` is fine — the pattern above is tuned to catch
`value!`, `value!)`, `try!`, `as!`.)
