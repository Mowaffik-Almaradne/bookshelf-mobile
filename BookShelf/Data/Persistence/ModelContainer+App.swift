import Foundation
import SwiftData

extension ModelContainer {
    /// On-disk store for the live app. Callers must fall back if this throws
    /// (corrupt store) rather than crashing at launch.
    ///
    /// The store URL, schema and CloudKit mode are all explicit: the
    /// convenience initialisers resolve the group container and CloudKit
    /// database automatically, which makes an open failure hard to diagnose.
    /// `bookshelf-v3` also abandons any store written by earlier schemas
    /// (unique `workKey`, missing container retention) instead of trying to
    /// reopen them with mismatched state.
    static func live() throws -> ModelContainer {
        let schema = Schema([SavedBookEntity.self])
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appending(path: "bookshelf-v3.store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Ephemeral store for tests, previews, and launch fallback when disk fails.
    static func inMemory() throws -> ModelContainer {
        let schema = Schema([SavedBookEntity.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
