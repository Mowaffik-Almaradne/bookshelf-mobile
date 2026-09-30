import Testing
@testable import BookShelf

/// The suite is synchronous on purpose: every row is pure state, so a sleep
/// or a stub would only hide a logic bug.
@Suite struct PaginatorTests {
    @Test func append_dropsRepeatedIDs_keepsFirstAndOrder() {
        var paginator = Paginator<TestItem>(pageSize: 20)
        let page1 = makePage(Array(1...20), page: 1, total: 100, tag: "first")
        let overlap = Array(19...38)
        let page2 = makePage(overlap, page: 2, total: 100, tag: "second")

        _ = paginator.append(page1)
        let fresh = paginator.append(page2)

        #expect(paginator.items.count == 38)
        #expect(paginator.items.map(\.id) == Array(1...38))
        #expect(paginator.items.prefix(20).allSatisfy { $0.tag == "first" })
        #expect(paginator.items.dropFirst(20).allSatisfy { $0.tag == "second" })
        #expect(fresh.map(\.id) == Array(21...38))
        #expect(paginator.hasMore)
    }

    @Test func append_allDuplicates_returnsEmptyAndEndsList() {
        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.append(makePage(Array(1...20), page: 1, total: 80, tag: "first"))

        let fresh = paginator.append(makePage(Array(1...20), page: 2, total: 80, tag: "second"))

        #expect(fresh.isEmpty)
        #expect(paginator.nextPage == 3)
        #expect(paginator.items.count == 20)
        #expect(paginator.items.allSatisfy { $0.tag == "first" })
        #expect(paginator.isLoading == false)
        // Full page of only known IDs must stop pagination (R2.4) — otherwise
        // prefetch loops while totalCount still looks larger.
        #expect(paginator.hasMore == false)
        #expect(paginator.beginLoadingIfNeeded() == nil)
    }

    @Test func append_allDuplicates_nilTotal_alsoEndsList() {
        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.append(makePage(Array(1...20), page: 1, total: nil, tag: "first"))

        _ = paginator.append(makePage(Array(1...20), page: 2, total: nil, tag: "replay"))

        #expect(paginator.hasMore == false)
        #expect(paginator.beginLoadingIfNeeded() == nil)
    }

    @Test func beginLoadingIfNeeded_returnsOnePage_thenNil() {
        var paginator = Paginator<TestItem>(pageSize: 20)

        let results = (0..<5).map { _ in paginator.beginLoadingIfNeeded() }

        #expect(results == [1, nil, nil, nil, nil])
        #expect(paginator.isLoading)
    }

    @Test func failLoading_retriesTheSamePage() {
        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.beginLoadingIfNeeded()
        _ = paginator.append(makePage(Array(1...20), page: 1, total: 40, tag: "first"))
        let requested = paginator.beginLoadingIfNeeded()

        paginator.failLoading()
        let retried = paginator.beginLoadingIfNeeded()

        #expect(requested == 2)
        #expect(retried == requested)
        #expect(paginator.nextPage == 2)
        #expect(paginator.items.count == 20)
        #expect(paginator.isLoading)
    }

    @Test func shortPage_endsEvenWhenTotalIsLarger() {
        let short = makePage(Array(1...7), page: 1, total: 100, tag: "only")

        #expect(Paginator<TestItem>.computeHasMore(page: short, loadedCount: 7) == false)

        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.append(short)
        #expect(paginator.hasMore == false)
        #expect(paginator.beginLoadingIfNeeded() == nil)
    }

    @Test func nilTotal_fullPage_reportsMore() {
        let full = makePage(Array(1...20), page: 1, total: nil, tag: "full")

        #expect(Paginator<TestItem>.computeHasMore(page: full, loadedCount: 20))

        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.append(full)
        #expect(paginator.hasMore)
    }

    @Test func loadedCountEqualsTotal_reportsEnd() {
        let full = makePage(Array(1...20), page: 1, total: 20, tag: "full")

        #expect(Paginator<TestItem>.computeHasMore(page: full, loadedCount: 20) == false)

        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.append(full)
        #expect(paginator.hasMore == false)
    }

    @Test func reset_restoresInitialStateIncludingSeenIDs() {
        var paginator = Paginator<TestItem>(pageSize: 20)
        _ = paginator.append(makePage(Array(1...20), page: 1, total: 100, tag: "old"))
        _ = paginator.beginLoadingIfNeeded()

        paginator.reset()

        #expect(paginator.items.isEmpty)
        #expect(paginator.nextPage == 1)
        #expect(paginator.hasMore)
        #expect(paginator.isLoading == false)
        let again = paginator.append(makePage(Array(1...20), page: 1, total: 100, tag: "new"))
        #expect(again.count == 20)
        #expect(again.allSatisfy { $0.tag == "new" })
    }

    @Test func shouldPrefetch_onlyForTheLastThresholdItems() {
        var paginator = Paginator<TestItem>(pageSize: 10)
        _ = paginator.append(makePage(Array(0..<10), page: 1, pageSize: 10, total: 30, tag: "row"))

        for id in 0..<10 {
            let item = TestItem(id: id, tag: "absent-tag")
            #expect(paginator.shouldPrefetch(after: item) == (id >= 5))
        }
        #expect(paginator.shouldPrefetch(after: TestItem(id: 8, tag: "x"), threshold: 2))
        #expect(paginator.shouldPrefetch(after: TestItem(id: 7, tag: "x"), threshold: 2) == false)
        #expect(paginator.shouldPrefetch(after: TestItem(id: 99, tag: "x")) == false)
        #expect(Paginator<TestItem>(pageSize: 20).shouldPrefetch(after: TestItem(id: 0, tag: "x")) == false)
    }

    @Test func searchPage_copiesEveryField() throws {
        let key = try #require(WorkKey(rawValue: "/works/OL1W"))
        let book = Book(
            key: key,
            title: "Title",
            authors: ["Author"],
            firstPublishYear: 1999,
            coverID: 5
        )
        let search = SearchPage(books: [book], page: 2, pageSize: 20, totalCount: nil)

        let page = search.asPage

        #expect(page.items == [book])
        #expect(page.page == 2)
        #expect(page.pageSize == 20)
        #expect(page.totalCount == nil)
    }
}

private nonisolated struct TestItem: Identifiable, Equatable, Sendable {
    let id: Int
    /// Distinguishes two copies of the same ID so "first wins" is observable.
    let tag: String
}

private nonisolated func makePage(
    _ ids: [Int],
    page: Int,
    pageSize: Int = 20,
    total: Int?,
    tag: String
) -> Page<TestItem> {
    Page(
        items: ids.map { TestItem(id: $0, tag: tag) },
        page: page,
        pageSize: pageSize,
        totalCount: total
    )
}
