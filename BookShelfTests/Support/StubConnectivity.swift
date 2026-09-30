import Foundation
@testable import BookShelf

/// Mutable online flag for view-model tests.
@MainActor
final class StubConnectivity: ConnectivityMonitoring {
    var isOnline: Bool

    init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }
}
