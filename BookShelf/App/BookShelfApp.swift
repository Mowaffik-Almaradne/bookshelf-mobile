import SwiftUI
import os

/// App entry. Owns `AppDependencies` for the process lifetime and hands them
/// to `RootView` so screens never construct services themselves.
@main
struct BookShelfApp: App {
    @State private var dependencies: AppDependencies
    @State private var showShelfPersistenceAlert: Bool

    init() {
        do {
            _dependencies = State(initialValue: try AppDependencies.live())
            _showShelfPersistenceAlert = State(initialValue: false)
        } catch {
            Log.persistence.error(
                "On-disk shelf unavailable, using in-memory: \(error.localizedDescription, privacy: .public)"
            )
            _dependencies = State(initialValue: AppDependencies.liveInMemory())
            _showShelfPersistenceAlert = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(\.imageLoader, dependencies.images)
                .alert(
                    "Shelf can't be saved on this device",
                    isPresented: $showShelfPersistenceAlert
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Books you add this session will disappear when you close the app.")
                }
        }
    }
}
