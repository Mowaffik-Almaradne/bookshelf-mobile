/// Merges pages of an identifiable list without duplicates or overlapping requests.
///
/// Pure value type: no clocks, no network, no UI. A view model decides when to
/// fetch; this type only answers "which page", "what to keep", and "is there more".
/// The first request asks for page 1, matching Open Library. After that the next
/// index always comes from the page that just landed (`page.page + 1`), so a list
/// that is not 1-based can still advance once its pages name their own index.
nonisolated struct Paginator<Item: Identifiable & Sendable>: Sendable where Item.ID: Hashable & Sendable {
    /// Size the owner asks the source for. End detection uses each page's own
    /// `pageSize`, because that is the size that page was actually fetched with.
    let pageSize: Int
    private(set) var items: [Item] = []
    /// Page number the next request should use. Unchanged until `append` accepts a page.
    private(set) var nextPage: Int = 1
    private(set) var hasMore: Bool = true
    /// True while a request started by `beginLoadingIfNeeded` has not settled.
    private(set) var isLoading: Bool = false
    /// IDs already kept. First occurrence wins; later copies are dropped.
    private var seenIDs: Set<Item.ID> = []

    init(pageSize: Int) {
        self.pageSize = pageSize
    }

    /// Drops loaded items and loading state so a new query can reuse the value.
    /// `seenIDs` is cleared too, otherwise the next query would drop keys the
    /// previous query had already shown.
    mutating func reset() {
        items = []
        nextPage = 1
        hasMore = true
        isLoading = false
        seenIDs = []
    }

    /// Page number to request, or `nil` when a request must not start.
    ///
    /// Returns a number at most once until that request settles through `append`
    /// or `failLoading`. Rapid scroll callbacks therefore cannot fire two fetches
    /// for the same page. `nil` also means the list has already ended.
    mutating func beginLoadingIfNeeded() -> Int? {
        guard hasMore, !isLoading else { return nil }
        isLoading = true
        return nextPage
    }

    /// Clears the in-flight flag without advancing `nextPage`.
    ///
    /// The next `beginLoadingIfNeeded` asks for the same page again, so a failed
    /// page can be retried and already-shown items stay put.
    mutating func failLoading() {
        isLoading = false
    }

    /// Merges `page` into `items` and returns only the items that were new.
    ///
    /// This is the only success path that clears `isLoading`. Duplicates are
    /// dropped by ID; the first occurrence stays in place and later pages keep
    /// their relative order. `nextPage` advances even when every item is a
    /// duplicate — otherwise an index shift would request the same page forever.
    ///
    /// A *full* page that contributes zero new IDs ends the list (`hasMore =
    /// false`). Otherwise prefetch would loop forever when the API replays the
    /// same window while `totalCount` still looks larger (R2.4).
    @discardableResult
    mutating func append(_ page: Page<Item>) -> [Item] {
        isLoading = false
        var fresh: [Item] = []
        fresh.reserveCapacity(page.items.count)
        for item in page.items {
            let isNew = seenIDs.insert(item.id).inserted
            if isNew {
                fresh.append(item)
            }
        }
        items.append(contentsOf: fresh)
        nextPage = page.page + 1
        if fresh.isEmpty && page.items.count >= page.pageSize {
            hasMore = false
        } else {
            hasMore = Self.computeHasMore(page: page, loadedCount: items.count)
        }
        return fresh
    }

    /// Whether another request is worth making after this page.
    ///
    /// `totalCount` drifts between responses on the real API, so it is never the
    /// only signal. A short page always ends the list, even when the reported
    /// total is still larger. Otherwise a known total continues while
    /// `loadedCount < totalCount`. With no total, a non-empty full page is
    /// treated as "probably more"; an empty payload is the end.
    ///
    /// Callers that also drop duplicates must end the list when a full page
    /// yields no fresh IDs — see `append`, which applies that rule before this
    /// helper. This function alone does not see the fresh count.
    static func computeHasMore(page: Page<Item>, loadedCount: Int) -> Bool {
        if page.items.count < page.pageSize { return false }
        if let total = page.totalCount { return loadedCount < total }
        return !page.items.isEmpty
    }

    /// True when `item` sits in the trailing window that should start the next fetch.
    ///
    /// Triggering from the last few rows loads the next page before the user hits
    /// the bottom. An item that is not in `items` returns false so a stale row
    /// cannot start a fetch.
    func shouldPrefetch(after item: Item, threshold: Int = 5) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let remaining = items.distance(from: index, to: items.endIndex)
        return remaining <= threshold
    }
}
