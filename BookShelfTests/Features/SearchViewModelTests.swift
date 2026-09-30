import Foundation
import Testing
@testable import BookShelf

@Suite
@MainActor
struct SearchViewModelTests {
    @Test func idle_whenQueryShorterThanThree() async throws {
        let catalog = StubCatalog()
        let vm = makeViewModel(catalog: catalog)

        vm.query = "ha"

        #expect(vm.phase == .idle)
        #expect(catalog.callCount == 0)
    }

    @Test func loading_thenLoaded() async throws {
        let catalog = StubCatalog()
        catalog.stub(
            query: "harry",
            page: 1,
            result: .success(.stub(ids: ["OL1W"], page: 1, total: 1)),
            // Keep `.loading` long enough for a yield-based poll to observe it.
            delay: .milliseconds(30)
        )
        let vm = makeViewModel(catalog: catalog)
        var seen: [SearchPhase] = [vm.phase]

        vm.query = "harry"

        try await waitUntil {
            if seen.last != vm.phase {
                seen.append(vm.phase)
            }
            if case .loaded = vm.phase { return true }
            return false
        }
        if seen.last != vm.phase {
            seen.append(vm.phase)
        }

        #expect(seen.contains(.loading))
        #expect(seen.contains { phase in
            if case .loaded = phase { return true }
            return false
        })
        let loadingIndex = try #require(seen.firstIndex(of: .loading))
        let loadedIndex = try #require(seen.firstIndex(where: {
            if case .loaded = $0 { return true }
            return false
        }))
        #expect(loadingIndex < loadedIndex)
    }

    @Test func empty_onZeroDocs() async throws {
        let catalog = StubCatalog()
        catalog.stub(
            query: "zzzz",
            page: 1,
            result: .success(.stub(ids: [], page: 1, total: 0))
        )
        let vm = makeViewModel(catalog: catalog)

        vm.query = "zzzz"

        try await waitUntil { vm.phase == .empty }
        #expect(vm.phase == .empty)
    }

    @Test func failed_onError_thenRetrySucceeds() async throws {
        let catalog = StubCatalog()
        catalog.stub(query: "harry", page: 1, result: .failure(.network))
        let vm = makeViewModel(catalog: catalog)

        vm.query = "harry"
        try await waitUntil {
            if case .failed = vm.phase { return true }
            return false
        }

        catalog.stub(
            query: "harry",
            page: 1,
            result: .success(.stub(ids: ["OL1W"], page: 1, total: 1))
        )
        vm.retry()

        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }
        #expect(vm.phase.items.map(\.key.rawValue) == ["/works/OL1W"])
    }

    @Test func staleResultsNeverShown_slowerHarrDoesNotOverwriteHarry() async throws {
        let catalog = StubCatalog()
        let harrBooks = SearchPage.stub(ids: ["OL_HARR"], page: 1, total: 1)
        let harryBooks = SearchPage.stub(ids: ["OL_HARRY"], page: 1, total: 1)
        catalog.stub(query: "harr", page: 1, result: .success(harrBooks), delay: .milliseconds(300))
        catalog.stub(query: "harry", page: 1, result: .success(harryBooks), delay: .milliseconds(10))

        let vm = makeViewModel(catalog: catalog)
        let recorder = PhaseRecorder<SearchPhase>()
        recorder.observe { vm.phase }

        vm.query = "harr"
        vm.query = "harry"

        try await waitUntil(timeout: .seconds(3)) {
            if case .loaded(let items, _) = vm.phase {
                return items.map(\.key.rawValue) == ["/works/OL_HARRY"]
            }
            return false
        }

        #expect(vm.phase.items.map(\.key.rawValue) == ["/works/OL_HARRY"])
        let harrEverShown = recorder.history.contains { phase in
            phase.items.contains { $0.key.rawValue == "/works/OL_HARR" }
        }
        #expect(harrEverShown == false)
    }

    @Test func whitespaceChangeDoesNotRefetch() async throws {
        let catalog = StubCatalog()
        catalog.stub(
            query: "harry",
            page: 1,
            result: .success(.stub(ids: ["OL1W"], page: 1, total: 1))
        )
        let vm = makeViewModel(catalog: catalog)

        vm.query = "harry"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }
        #expect(catalog.callCount == 1)

        vm.query = "harry "
        await Task.yield()
        await Task.yield()

        #expect(catalog.callCount == 1)
        #expect(vm.phase.items.map(\.key.rawValue) == ["/works/OL1W"])
    }

    @Test func nextPage_appendsWithoutDuplicates_andDetectsEnd() async throws {
        let catalog = StubCatalog()
        let page1IDs = (1...20).map { "OL\($0)W" }
        let page2IDs = (19...30).map { "OL\($0)W" }
        catalog.stub(
            query: "saga",
            page: 1,
            result: .success(.stub(ids: page1IDs, page: 1, total: 30))
        )
        catalog.stub(
            query: "saga",
            page: 2,
            result: .success(.stub(ids: page2IDs, page: 2, pageSize: 20, total: 30))
        )
        let vm = makeViewModel(catalog: catalog)

        vm.query = "saga"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }

        let trigger = try #require(vm.phase.items.dropLast(4).last)
        vm.loadNextPageIfNeeded(currentItem: trigger)

        try await waitUntil {
            if case .loaded(_, .end) = vm.phase { return true }
            return false
        }

        #expect(vm.phase.items.count == 30)
        #expect(Set(vm.phase.items.map(\.id)).count == 30)
        #expect(vm.phase.footer == .end)
    }

    @Test func nextPage_failureKeepsItems_showsFooterRetry() async throws {
        let catalog = StubCatalog()
        let page1IDs = (1...20).map { "OL\($0)W" }
        catalog.stub(
            query: "saga",
            page: 1,
            result: .success(.stub(ids: page1IDs, page: 1, total: 40))
        )
        catalog.stub(query: "saga", page: 2, result: .failure(.timeout))
        let vm = makeViewModel(catalog: catalog)

        vm.query = "saga"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }

        let trigger = try #require(vm.phase.items.dropLast(4).last)
        vm.loadNextPageIfNeeded(currentItem: trigger)

        try await waitUntil {
            if case .loaded(_, .failed) = vm.phase { return true }
            return false
        }

        #expect(vm.phase.items.count == 20)
        #expect(vm.phase.footer == .failed(.timeout))

        catalog.stub(
            query: "saga",
            page: 2,
            result: .success(.stub(ids: (21...40).map { "OL\($0)W" }, page: 2, total: 40))
        )
        let callsBeforeRetry = catalog.callCount
        vm.retryNextPage()

        try await waitUntil {
            if case .loaded(_, .end) = vm.phase { return true }
            return false
        }

        let page2Calls = catalog.calls.filter { $0.query == "saga" && $0.page == 2 }
        #expect(page2Calls.count == 2)
        #expect(catalog.calls[callsBeforeRetry].page == 2)
        #expect(vm.phase.items.count == 40)
    }

    @Test func cancelledErrorIsSilent() async throws {
        let catalog = StubCatalog()
        catalog.stub(
            query: "harry",
            page: 1,
            result: .success(.stub(ids: ["OL1W"], page: 1, total: 1))
        )
        let vm = makeViewModel(catalog: catalog)

        vm.query = "harry"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }

        catalog.stub(query: "harry", page: 1, result: .failure(.cancelled))
        vm.retry()

        try await waitUntil { catalog.callCount == 2 }
        await Task.yield()
        await Task.yield()

        // retry moved to .loading; cancelled must not become .failed or hang on spinner.
        #expect(vm.phase != .failed(.cancelled))
        if case .failed = vm.phase {
            Issue.record("cancelled must not surface as failed")
        }
        if case .loading = vm.phase {
            Issue.record("cancelled must not leave an eternal loading spinner")
        }
    }

    @Test func whitespaceDuringPageLoad_doesNotStickPagination() async throws {
        let catalog = StubCatalog()
        let page1IDs = (1...20).map { "OL\($0)W" }
        catalog.stub(
            query: "saga",
            page: 1,
            result: .success(.stub(ids: page1IDs, page: 1, total: 40))
        )
        catalog.stub(
            query: "saga",
            page: 2,
            result: .success(.stub(ids: (21...40).map { "OL\($0)W" }, page: 2, total: 40)),
            delay: .milliseconds(200)
        )
        let vm = makeViewModel(catalog: catalog)

        vm.query = "saga"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }

        let trigger = try #require(vm.phase.items.dropLast(4).last)
        vm.loadNextPageIfNeeded(currentItem: trigger)
        try await waitUntil {
            if case .loaded(_, .loading) = vm.phase { return true }
            return false
        }

        // Cancels pageTask + bumps generation, then early-returns (same normalized query).
        vm.query = "saga "
        await Task.yield()
        await Task.yield()

        #expect(vm.phase.footer == .idle || vm.phase.footer == .end)
        #expect(catalog.calls.filter { $0.page == 2 }.count == 1)

        catalog.stub(
            query: "saga",
            page: 2,
            result: .success(.stub(ids: (21...40).map { "OL\($0)W" }, page: 2, total: 40))
        )
        vm.loadNextPageIfNeeded(currentItem: trigger)

        try await waitUntil {
            if case .loaded(_, .end) = vm.phase { return true }
            return false
        }
        #expect(vm.phase.items.count == 40)
        #expect(catalog.calls.filter { $0.page == 2 }.count == 2)
    }

    @Test func savedStateReflectsShelf() async throws {
        let catalog = StubCatalog()
        let book = Book.stub(id: "OL9W")
        catalog.stub(
            query: "dune",
            page: 1,
            result: .success(
                SearchPage(books: [book], page: 1, pageSize: 20, totalCount: 1)
            )
        )
        let saved = StubSavedState()
        let vm = makeViewModel(catalog: catalog, savedState: saved)

        vm.query = "dune"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }

        #expect(vm.isSaved(book) == false)
        saved.save(book.key)
        #expect(vm.isSaved(book) == true)
    }

    /// R4.4 through the real `ShelfStore` (not a stub): save updates `savedKeys`
    /// that Search reads via `SavedStateReading`.
    @Test func savedStateReflectsShelfStoreAfterSave() async throws {
        let catalog = StubCatalog()
        let book = Book.stub(id: "OL42W")
        catalog.stub(
            query: "dune",
            page: 1,
            result: .success(
                SearchPage(books: [book], page: 1, pageSize: 20, totalCount: 1)
            )
        )
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(
            repository: repository,
            images: TestImageLoader(throwsOnData: true)
        )
        let vm = SearchViewModel(
            catalog: catalog,
            savedState: store,
            connectivity: StubConnectivity(),
            debounce: .zero
        )

        vm.query = "dune"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }
        #expect(vm.isSaved(book) == false)

        await store.save(BookDetails(seed: book))
        #expect(store.isSaved(book.key))
        #expect(vm.isSaved(book) == true)

        store.remove(book.key)
        #expect(vm.isSaved(book) == false)
    }

    @Test func firstPageSuccess_setsPendingResultsAnnouncementCount() async throws {
        let catalog = StubCatalog()
        catalog.stub(
            query: "dune",
            page: 1,
            result: .success(.stub(ids: ["OL1W", "OL2W"], page: 1, total: 42))
        )
        let vm = makeViewModel(catalog: catalog)

        vm.query = "dune"
        try await waitUntil {
            if case .loaded = vm.phase { return true }
            return false
        }

        #expect(vm.pendingResultsAnnouncementCount == 42)
        vm.clearPendingResultsAnnouncement()
        #expect(vm.pendingResultsAnnouncementCount == nil)
    }

    private func makeViewModel(
        catalog: StubCatalog,
        savedState: StubSavedState = StubSavedState(),
        connectivity: StubConnectivity = StubConnectivity()
    ) -> SearchViewModel {
        SearchViewModel(
            catalog: catalog,
            savedState: savedState,
            connectivity: connectivity,
            debounce: .zero
        )
    }
}
