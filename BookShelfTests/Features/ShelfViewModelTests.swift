import Foundation
import Testing
@testable import BookShelf

@Suite
@MainActor
struct ShelfViewModelTests {
    @Test func statusFilter_hidesOtherStatuses() async throws {
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(
            repository: repository,
            images: TestImageLoader(throwsOnData: true)
        )
        let want = BookDetails.stub(id: "OL1W", title: "Want")
        let reading = BookDetails.stub(id: "OL2W", title: "Reading")
        await store.save(want)
        await store.save(reading)
        store.setStatus(.reading, for: reading.key)

        let vm = ShelfViewModel(store: store)
        #expect(vm.books.count == 2)

        vm.statusFilter = .reading
        #expect(vm.books.map(\.details.title) == ["Reading"])
        #expect(vm.hasSavedBooks)

        vm.statusFilter = .finished
        #expect(vm.books.isEmpty)
        #expect(vm.hasSavedBooks)
    }

    @Test func setStatus_updatesStoreAndFilterResults() async throws {
        let repository = InMemoryShelfRepository()
        let store = ShelfStore(
            repository: repository,
            images: TestImageLoader(throwsOnData: true)
        )
        let details = BookDetails.stub(id: "OL3W")
        await store.save(details)
        let vm = ShelfViewModel(store: store)

        vm.setStatus(.finished, for: details.key)
        vm.statusFilter = .finished
        #expect(vm.books.count == 1)
        #expect(vm.books.first?.status == .finished)
    }
}
