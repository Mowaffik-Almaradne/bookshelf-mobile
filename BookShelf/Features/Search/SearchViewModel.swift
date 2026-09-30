import Foundation
import Observation

/// Owns search query, phase, and pagination. UI-free so the same machine
/// drives previews, tests, and the screen without importing SwiftUI.
///
/// `@MainActor`: `phase` / `query` are `@Observable` UI state; generation
/// bumps and task cancellation must stay serial with those writes.
@MainActor
@Observable
final class SearchViewModel {
    /// Bound to the search field. Every edit cancels in-flight work and bumps
    /// the generation token before deciding whether to schedule a new search.
    var query: String = "" {
        didSet { queryDidChange() }
    }

    private(set) var phase: SearchPhase = .idle

    /// Hit count from the latest successful first-page search (`numFound` when
    /// known). The view posts a VoiceOver announcement, then clears this.
    private(set) var pendingResultsAnnouncementCount: Int?

    var isOnline: Bool { connectivity.isOnline }

    /// Clears the one-shot announcement token after the view has posted it.
    func clearPendingResultsAnnouncement() {
        pendingResultsAnnouncementCount = nil
    }

    private let catalog: any BookCatalog
    private let savedState: any SavedStateReading
    private let connectivity: any ConnectivityMonitoring
    private let debounce: Duration
    private let minimumQueryLength: Int

    private var paginator = Paginator<Book>(pageSize: 20)
    private var searchTask: Task<Void, Never>?
    private var pageTask: Task<Void, Never>?
    /// Normalized query the current `phase` / paginator contents belong to.
    private var activeQuery: String = ""
    /// Monotonic token compared after every `await`. Cancellation alone is not
    /// enough: a response may already be decoding when the task is cancelled.
    private var generation = 0

    init(
        catalog: any BookCatalog,
        savedState: any SavedStateReading,
        connectivity: any ConnectivityMonitoring,
        debounce: Duration = .milliseconds(350),
        minimumQueryLength: Int = 3
    ) {
        self.catalog = catalog
        self.savedState = savedState
        self.connectivity = connectivity
        self.debounce = debounce
        self.minimumQueryLength = minimumQueryLength
    }

    func isSaved(_ book: Book) -> Bool {
        savedState.isSaved(book.key)
    }

    /// Keyboard Search: skip debounce and run immediately for the current query.
    func submit() {
        cancelInFlightAndBumpGeneration()

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= minimumQueryLength else {
            activeQuery = ""
            paginator.reset()
            pendingResultsAnnouncementCount = nil
            phase = .idle
            return
        }
        guard normalized != activeQuery || phase.isFailed else { return }

        let gen = generation
        searchTask = Task { [weak self] in
            guard let self else { return }
            await self.performSearch(normalized, generation: gen)
        }
    }

    /// Re-runs page 1 for `activeQuery` after a first-page failure.
    func retry() {
        guard !activeQuery.isEmpty else { return }
        cancelInFlightAndBumpGeneration()
        let gen = generation
        let q = activeQuery
        searchTask = Task { [weak self] in
            guard let self else { return }
            await self.performSearch(q, generation: gen)
        }
    }

    /// Re-requests the same page number after a footer failure.
    func retryNextPage() {
        guard case .loaded(_, .failed) = phase else { return }
        startNextPageIfPossible()
    }

    /// Prefetch when `currentItem` is among the last five loaded rows.
    func loadNextPageIfNeeded(currentItem: Book) {
        guard case .loaded = phase,
              paginator.shouldPrefetch(after: currentItem) else { return }
        startNextPageIfPossible()
    }

    private func queryDidChange() {
        cancelInFlightAndBumpGeneration()

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= minimumQueryLength else {
            activeQuery = ""
            paginator.reset()
            pendingResultsAnnouncementCount = nil
            phase = .idle
            return
        }
        // Whitespace-only edits keep the same normalized string → no refetch.
        // A failed first page with the same query is allowed to schedule again.
        guard normalized != activeQuery || phase.isFailed else { return }

        let gen = generation
        let delay = debounce
        searchTask = Task { [weak self] in
            // sleep throws CancellationError when cancelled; try? is fine — we
            // re-check Task.isCancelled before doing work.
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(normalized, generation: gen)
        }
    }

    private func performSearch(_ q: String, generation gen: Int) async {
        activeQuery = q
        paginator.reset()
        phase = .loading
        do {
            let page = try await catalog.search(query: q, page: 1)
            guard gen == generation, !Task.isCancelled else { return }
            let added = paginator.append(page.asPage)
            if added.isEmpty && paginator.items.isEmpty {
                pendingResultsAnnouncementCount = nil
                phase = .empty
            } else {
                pendingResultsAnnouncementCount = page.totalCount ?? paginator.items.count
                phase = .loaded(items: paginator.items, footer: paginator.hasMore ? .idle : .end)
            }
        } catch {
            let appError = AppError(error)
            // CancellationError and AppError.cancelled must not become .failed.
            if appError == .cancelled {
                // Same generation still owns the UI — do not leave an eternal spinner.
                guard gen == generation, case .loading = phase else { return }
                phase = .idle
                return
            }
            guard gen == generation else { return }
            phase = .failed(appError)
        }
    }

    /// Shared entry for prefetch and footer retry. `beginLoadingIfNeeded` is the
    /// in-flight guard: rapid `onAppear` callbacks cannot start a second request.
    private func startNextPageIfPossible() {
        guard let page = paginator.beginLoadingIfNeeded() else { return }
        let gen = generation
        let q = activeQuery
        phase = .loaded(items: paginator.items, footer: .loading)
        pageTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await catalog.search(query: q, page: page)
                // Stale after a generation bump: `cancelInFlightAndBumpGeneration`
                // already released `isLoading` — do not touch the paginator here.
                guard gen == generation else { return }
                paginator.append(result.asPage)
                phase = .loaded(
                    items: paginator.items,
                    footer: paginator.hasMore ? .idle : .end
                )
            } catch {
                let appError = AppError(error)
                if appError == .cancelled {
                    // Same generation still owns the list (catalog-level cancel,
                    // not a bump). Release the lock so prefetch can run again.
                    guard gen == generation else { return }
                    paginator.failLoading()
                    if case .loaded(_, .loading) = phase {
                        phase = .loaded(
                            items: paginator.items,
                            footer: paginator.hasMore ? .idle : .end
                        )
                    }
                    return
                }
                guard gen == generation else { return }
                paginator.failLoading()
                phase = .loaded(
                    items: paginator.items,
                    footer: .failed(appError)
                )
            }
        }
    }

    /// Cancels search/page tasks and bumps the generation token.
    ///
    /// WHY clear the page footer here: `submit` / whitespace-only edits cancel
    /// `pageTask` then early-return without `paginator.reset()`. Leaving
    /// `isLoading == true` permanently blocks `beginLoadingIfNeeded` (R2.4).
    private func cancelInFlightAndBumpGeneration() {
        searchTask?.cancel()
        pageTask?.cancel()
        generation += 1
        if case .loaded(_, .loading) = phase {
            paginator.failLoading()
            phase = .loaded(
                items: paginator.items,
                footer: paginator.hasMore ? .idle : .end
            )
        }
    }
}
