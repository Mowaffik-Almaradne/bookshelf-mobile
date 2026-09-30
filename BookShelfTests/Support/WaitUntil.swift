import Foundation
import Testing
@testable import BookShelf

/// Polls until `condition` is true. Yields so MainActor tasks can progress.
/// No sleeps used as synchronisation — only a timeout ceiling.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @MainActor () -> Bool
) async throws {
    let clock = ContinuousClock()
    let start = clock.now
    while !condition() {
        try #require(clock.now - start < timeout, "timed out waiting for condition")
        await Task.yield()
    }
}

/// Records every distinct value of an `@Observable` property via observation tracking.
@MainActor
final class PhaseRecorder<Phase: Equatable & Sendable> {
    private(set) var history: [Phase] = []

    /// Starts recursive observation. Call once; each change re-arms tracking.
    func observe(_ read: @escaping @MainActor () -> Phase) {
        let value = withObservationTracking {
            read()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Read immediately so a short-lived phase is less likely to be skipped
                // before the next withObservationTracking pass.
                let latest = read()
                if self.history.last != latest {
                    self.history.append(latest)
                }
                self.observe(read)
            }
        }
        if history.last != value {
            history.append(value)
        }
    }
}
