import Foundation
import SwiftData
import Testing
@testable import BookShelf

@Suite
@MainActor
struct ShelfStoreTests {
    @Test func save_thenIsSavedAndListed() async throws {
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(repository: repository, images: TestImageLoader(throwsOnData: true))
        let details = BookDetails.stub()

        await store.save(details)

        #expect(store.isSaved(details.key))
        #expect(store.books.count == 1)
        #expect(store.books.first?.details.key == details.key)
    }

    @Test func save_twice_isIdempotent() async throws {
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(repository: repository, images: TestImageLoader(throwsOnData: true))
        let details = BookDetails.stub()

        await store.save(details)
        await store.save(details)

        #expect(store.books.count == 1)
        #expect(store.savedKeys.count == 1)
    }

    @Test func remove_updatesKeysAndList() async throws {
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(repository: repository, images: TestImageLoader(throwsOnData: true))
        let details = BookDetails.stub()
        await store.save(details)

        store.remove(details.key)

        #expect(store.isSaved(details.key) == false)
        #expect(store.books.isEmpty)
        #expect(store.savedKeys.isEmpty)
    }

    @Test func save_persistsCoverBytesWhenAvailable() async throws {
        let cover = Data([0x89, 0x50, 0x4E, 0x47])
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(
            repository: repository,
            images: TestImageLoader(data: cover)
        )
        let details = BookDetails.stub(coverID: 42)

        await store.save(details)

        #expect(store.books.first?.coverData == cover)
    }

    @Test func save_withoutCover_stillPersists() async throws {
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(
            repository: repository,
            images: TestImageLoader(throwsOnData: true)
        )
        let details = BookDetails.stub(coverID: 42)

        await store.save(details)

        #expect(store.isSaved(details.key))
        #expect(store.books.first?.coverData == nil)
    }

    @Test func secondRepository_overSameContainer_seesBook() async throws {
        let container = try ModelContainer.inMemory()
        let repo1 = SwiftDataShelfRepository(container: container)
        let store = ShelfStore(
            repository: repo1,
            images: TestImageLoader(throwsOnData: true)
        )
        let details = BookDetails.stub()

        await store.save(details)

        let repo2 = SwiftDataShelfRepository(container: container)
        let fetched = try repo2.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.details.key == details.key)
    }

    @Test func corruptRow_isSkippedNotCrash() async throws {
        let container = try ModelContainer.inMemory()
        let context = container.mainContext
        context.autosaveEnabled = false
        context.insert(
            SavedBookEntity(
                workKey: "not-a-valid-work-key",
                title: "Corrupt",
                authors: [],
                bookDescription: nil,
                subjects: [],
                coverID: nil,
                firstPublishYear: nil,
                firstPublishDate: nil,
                savedAt: .now,
                statusRaw: ReadingStatus.wantToRead.rawValue,
                coverData: nil
            )
        )
        try context.save()

        let repository = SwiftDataShelfRepository(container: container)
        let store = ShelfStore(
            repository: repository,
            images: TestImageLoader(throwsOnData: true)
        )

        #expect(store.books.isEmpty)
        #expect(try repository.fetchAll().isEmpty)
    }
}
