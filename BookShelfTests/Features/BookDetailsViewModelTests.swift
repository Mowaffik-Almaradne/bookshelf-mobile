import Foundation
import Testing
@testable import BookShelf

@Suite
@MainActor
struct BookDetailsViewModelTests {
    @Test func savedBook_offline_showsLocalWithoutNetwork() async throws {
        let catalog = StubCatalog()
        catalog.stubDetails(.success(.stub(title: "Remote Should Not Load")))
        let shelf = makeShelf()
        let local = BookDetails.stub(title: "Local Copy", description: "Saved offline")
        await shelf.save(local)
        let connectivity = StubConnectivity(isOnline: false)
        let vm = BookDetailsViewModel(
            book: Book.stub(),
            catalog: catalog,
            shelf: shelf,
            connectivity: connectivity
        )

        await vm.load()

        guard case .loaded(let details, let source) = vm.phase else {
            Issue.record("Expected loaded phase, got \(vm.phase)")
            return
        }
        #expect(source == .local)
        #expect(details.title == "Local Copy")
        #expect(details.description == "Saved offline")
        #expect(catalog.detailsCallCount == 0)
    }

    @Test func savedBook_online_refreshesAndUpdates() async throws {
        let catalog = StubCatalog()
        let refreshed = BookDetails.stub(
            title: "Refreshed Title",
            description: "Fresh from network",
            subjects: ["Updated"]
        )
        catalog.stubDetails(.success(refreshed))
        let shelf = makeShelf()
        let local = BookDetails.stub(title: "Stale Title", description: "Old")
        await shelf.save(local)
        let vm = BookDetailsViewModel(
            book: Book.stub(),
            catalog: catalog,
            shelf: shelf,
            connectivity: StubConnectivity(isOnline: true)
        )

        await vm.load()

        guard case .loaded(let details, let source) = vm.phase else {
            Issue.record("Expected loaded phase, got \(vm.phase)")
            return
        }
        #expect(source == .remote)
        #expect(details.title == "Refreshed Title")
        #expect(details.description == "Fresh from network")
        #expect(catalog.detailsCallCount == 1)
        #expect(shelf.saved(local.key)?.details.title == "Refreshed Title")
        #expect(shelf.saved(local.key)?.details.subjects == ["Updated"])
    }

    @Test func unsavedBook_offline_failsWithOfflineError() async throws {
        let catalog = StubCatalog()
        catalog.stubDetails(.success(.stub()))
        let vm = BookDetailsViewModel(
            book: Book.stub(),
            catalog: catalog,
            shelf: makeShelf(),
            connectivity: StubConnectivity(isOnline: false)
        )

        await vm.load()

        guard case .failed(let error) = vm.phase else {
            Issue.record("Expected failed phase, got \(vm.phase)")
            return
        }
        #expect(error == .offline)
        #expect(error.isRetryable)
        #expect(catalog.detailsCallCount == 0)
    }

    @Test func toggleSaved_fromLoaded_savesFullDetails() async throws {
        let catalog = StubCatalog()
        let full = BookDetails.stub(
            title: "Full Details",
            description: "Complete description",
            subjects: ["Fiction", "Adventure"]
        )
        catalog.stubDetails(.success(full))
        let shelf = makeShelf()
        let vm = BookDetailsViewModel(
            book: Book.stub(title: "Seed Title"),
            catalog: catalog,
            shelf: shelf,
            connectivity: StubConnectivity(isOnline: true)
        )

        await vm.load()
        await vm.toggleSaved()

        let saved = try #require(shelf.saved(full.key))
        #expect(saved.details.title == "Full Details")
        #expect(saved.details.description == "Complete description")
        #expect(saved.details.subjects == ["Fiction", "Adventure"])
    }

    @Test func failedLoad_stillAllowsSavingFromSeed() async throws {
        let catalog = StubCatalog()
        catalog.stubDetails(.failure(.network))
        let shelf = makeShelf()
        let seed = Book.stub(title: "Seed Only", authors: ["Seed Author"], coverID: 99)
        let vm = BookDetailsViewModel(
            book: seed,
            catalog: catalog,
            shelf: shelf,
            connectivity: StubConnectivity(isOnline: true)
        )

        await vm.load()
        guard case .failed = vm.phase else {
            Issue.record("Expected failed phase, got \(vm.phase)")
            return
        }

        await vm.toggleSaved()

        let saved = try #require(shelf.saved(seed.key))
        #expect(saved.details.title == "Seed Only")
        #expect(saved.details.authors == ["Seed Author"])
        #expect(saved.details.coverID == 99)
        #expect(saved.details.description == nil)
        #expect(saved.details.subjects.isEmpty)
    }

    private func makeShelf() -> ShelfStore {
        ShelfStore(
            repository: InMemoryShelfRepository(),
            images: TestImageLoader(throwsOnData: true)
        )
    }
}
