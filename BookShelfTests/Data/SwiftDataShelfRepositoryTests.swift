import Foundation
import SwiftData
import Testing
@testable import BookShelf

@Suite
@MainActor
struct SwiftDataShelfRepositoryTests {
    @Test func save_upsertsUniqueWorkKey() throws {
        let container = try ModelContainer.inMemory()
        let repository = SwiftDataShelfRepository(container: container)
        let first = ShelfBook.stub(title: "First", savedAt: Date(timeIntervalSince1970: 100))
        let second = ShelfBook.stub(title: "Second", savedAt: Date(timeIntervalSince1970: 200))

        try repository.save(first)
        try repository.save(second)

        let all = try repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.details.title == "Second")
    }

    @Test func fetchAll_sortsBySavedAtDescending() throws {
        let container = try ModelContainer.inMemory()
        let repository = SwiftDataShelfRepository(container: container)
        let older = ShelfBook.stub(
            id: "OL1W",
            title: "Older",
            savedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = ShelfBook.stub(
            id: "OL2W",
            title: "Newer",
            savedAt: Date(timeIntervalSince1970: 200)
        )

        try repository.save(older)
        try repository.save(newer)

        let all = try repository.fetchAll()
        #expect(all.map(\.details.title) == ["Newer", "Older"])
    }

    @Test func update_status_persists() throws {
        let container = try ModelContainer.inMemory()
        let repository = SwiftDataShelfRepository(container: container)
        let book = ShelfBook.stub()
        try repository.save(book)

        try repository.update(workKey: book.id, status: .finished)

        let fetched = try repository.fetch(workKey: book.id)
        #expect(fetched?.status == .finished)
    }

    /// Regression: the app crashed on the first save while the in-memory tests
    /// stayed green. An on-disk store runs SwiftData's own coordinator queues, so
    /// it is the only configuration that catches isolation mistakes on
    /// `SavedBookEntity` (the target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
    @Test func onDiskStore_saveThenFetch_doesNotTrap() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "shelf-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let container = try ModelContainer(
            for: Schema([SavedBookEntity.self]),
            configurations: [ModelConfiguration(url: url)]
        )
        let repository = SwiftDataShelfRepository(container: container)
        let book = ShelfBook.stub(id: "OL16262891W", title: "On Disk")

        try repository.save(book)
        try repository.save(book)

        let all = try repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.details.title == "On Disk")
    }

    /// Regression for the simulator save crash: the repository used to keep only
    /// `mainContext`, so when the caller's `ModelContainer` left scope the next
    /// `fetch` trapped with `EXC_BREAKPOINT`. Retaining the container inside the
    /// repository must keep fetch/save alive after that scope ends.
    @Test func repository_survivesCallerDroppingContainer() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "shelf-retain-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let repository: SwiftDataShelfRepository = try {
            let container = try ModelContainer(
                for: Schema([SavedBookEntity.self]),
                configurations: [ModelConfiguration(url: url)]
            )
            return SwiftDataShelfRepository(container: container)
        }()

        let book = ShelfBook.stub(id: "OL16262891W", title: "Retained")
        try repository.save(book)
        try repository.save(book)

        let all = try repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.details.title == "Retained")
    }

    @Test func remove_missingKey_doesNotThrow() throws {
        let container = try ModelContainer.inMemory()
        let repository = SwiftDataShelfRepository(container: container)
        guard let missing = WorkKey(rawValue: "/works/OL999W") else {
            preconditionFailure("fixture key must parse")
        }

        try repository.remove(workKey: missing)
        #expect(try repository.fetchAll().isEmpty)
    }
}

extension ShelfBook {
    static func stub(
        id: String = "OL1W",
        title: String = "Stub Book",
        savedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        status: ReadingStatus = .wantToRead,
        coverData: Data? = nil
    ) -> ShelfBook {
        ShelfBook(
            details: .stub(id: id, title: title),
            savedAt: savedAt,
            status: status,
            coverData: coverData
        )
    }
}
