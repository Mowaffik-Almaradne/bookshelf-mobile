import Foundation
import Network
import Observation

/// Observes reachability for banners and to skip doomed network work.
///
/// WHY `isOnline` defaults to `true`: the first `NWPathMonitor` callback is
/// asynchronous; starting as offline would flash a false banner before we know.
/// WHY a `DispatchQueue` here: `NWPathMonitor.start(queue:)` requires one — this
/// is the single permitted `DispatchQueue` in the app. WHY the Simulator caveat:
/// on Simulator the path mirrors the Mac's connectivity, so offline demos need a
/// real device or toggling the Mac's Wi-Fi.
@MainActor
@Observable
final class ConnectivityMonitor: ConnectivityMonitoring {
    private(set) var isOnline: Bool
    private let monitor: NWPathMonitor?

    /// Live path monitoring.
    init() {
        isOnline = true
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        // NWPathMonitor requires a queue — the only DispatchQueue allowed in the app.
        monitor.start(queue: DispatchQueue(label: "com.efendi.bookshelf.connectivity"))
    }

    /// Fixed flag for `#Preview` and `AppDependencies.preview()` — no path monitor.
    init(isOnline: Bool) {
        self.isOnline = isOnline
        self.monitor = nil
    }

    deinit {
        monitor?.cancel()
    }
}
