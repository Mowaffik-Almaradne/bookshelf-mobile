import Foundation

/// Online / offline signal for banners and offline-first flows.
///
/// `nonisolated` + `Sendable` so the protocol can live on service graphs that
/// are not main-actor types. Reading `isOnline` is main-actor because UI and
/// view models observe it from the main actor.
nonisolated protocol ConnectivityMonitoring: Sendable {
    @MainActor var isOnline: Bool { get }
}

/// Fixed online flag for `#Preview` canvases and deterministic tests.
@MainActor
final class PreviewConnectivity: ConnectivityMonitoring {
    var isOnline: Bool

    init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }
}
