import SwiftUI

/// Search screen: composition + navigation only. No networking or layout maths.
struct SearchView: View {
    @State private var viewModel: SearchViewModel
    let makeDetails: (Book) -> BookDetailsViewModel
    let connectivity: ConnectivityMonitor

    init(
        viewModel: SearchViewModel,
        makeDetails: @escaping (Book) -> BookDetailsViewModel = { book in
            BookDetailsViewModel(
                book: book,
                catalog: ImmediatePreviewCatalog(),
                shelf: AppDependencies.preview().shelf,
                connectivity: PreviewConnectivity()
            )
        },
        connectivity: ConnectivityMonitor = ConnectivityMonitor(isOnline: true)
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeDetails = makeDetails
        self.connectivity = connectivity
    }

    var body: some View {
        @Bindable var vm = viewModel
        VStack(spacing: 0) {
            if !connectivity.isOnline {
                OfflineBanner()
            }
            phaseContent(vm: vm)
        }
        .navigationTitle("Search")
        .searchable(
            text: $vm.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Title, author or subject"
        )
        .onSubmit(of: .search) {
            vm.submit()
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailsView(
                viewModel: makeDetails(book),
                connectivity: connectivity
            )
        }
        .onChange(of: vm.pendingResultsAnnouncementCount) { _, count in
            guard let count else { return }
            AccessibilityNotification.Announcement(
                String(localized: "\(count) results")
            ).post()
            vm.clearPendingResultsAnnouncement()
        }
        .accessibilityIdentifier("searchField")
    }

    @ViewBuilder
    private func phaseContent(vm: SearchViewModel) -> some View {
        switch vm.phase {
        case .idle:
            SearchIdleView()
        case .loading:
            SearchLoadingView()
        case .empty:
            SearchEmptyView(query: vm.query.trimmingCharacters(in: .whitespacesAndNewlines))
        case .failed(let error):
            ErrorStateView(
                title: error.title,
                message: error.message,
                systemImage: error.systemImage,
                retryTitle: error.isRetryable ? "Retry" : nil,
                retryAccessibilityLabel: error.isRetryable ? "Retry search" : nil,
                onRetry: error.isRetryable ? { vm.retry() } : nil
            )
        case .loaded(let items, let footer):
            SearchResultsList(
                items: items,
                footer: footer,
                allowsNetwork: connectivity.isOnline,
                isSaved: { vm.isSaved($0) },
                onAppearItem: { vm.loadNextPageIfNeeded(currentItem: $0) },
                onRetryPage: { vm.retryNextPage() }
            )
        }
    }
}

/// Loaded-phase list extracted so `SearchView.body` stays a thin switch.
private struct SearchResultsList: View {
    let items: [Book]
    let footer: SearchPhase.Footer
    let allowsNetwork: Bool
    let isSaved: (Book) -> Bool
    let onAppearItem: (Book) -> Void
    let onRetryPage: () -> Void

    var body: some View {
        List {
            ForEach(items) { book in
                NavigationLink(value: book) {
                    BookRow(book: book, isSaved: isSaved(book), allowsNetwork: allowsNetwork)
                }
                .onAppear { onAppearItem(book) }
            }
            LoadingFooterView(state: footerState, onRetry: onRetryPage)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private var footerState: LoadingFooterView.FooterState {
        switch footer {
        case .idle:
            .hidden
        case .loading:
            .loading
        case .failed:
            .retry("Couldn't load more · Retry")
        case .end:
            .end
        }
    }
}

#Preview("Idle") {
    NavigationStack {
        SearchView(viewModel: .preview(query: ""))
    }
}

#Preview("Loading") {
    NavigationStack {
        SearchView(viewModel: .preview(query: "harry", catalog: DelayedPreviewCatalog(delay: .seconds(60))))
    }
}

#Preview("Loaded") {
    NavigationStack {
        SearchView(viewModel: .previewLoaded())
    }
}

#Preview("Empty") {
    NavigationStack {
        SearchView(viewModel: .preview(query: "zzz", catalog: EmptyPreviewCatalog()))
    }
}

#Preview("Failed dark a11y") {
    NavigationStack {
        SearchView(viewModel: .preview(query: "harry", catalog: FailingPreviewCatalog()))
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    NavigationStack {
        SearchView(viewModel: .previewLoaded())
    }
    .environment(\.layoutDirection, .rightToLeft)
}

// MARK: - Preview dependencies

extension SearchViewModel {
    @MainActor
    static func preview(
        query: String = "",
        catalog: any BookCatalog = ImmediatePreviewCatalog()
    ) -> SearchViewModel {
        let vm = SearchViewModel(
            catalog: catalog,
            savedState: EmptySavedState(),
            connectivity: PreviewConnectivity(),
            debounce: .zero
        )
        vm.query = query
        return vm
    }

    @MainActor
    static func previewLoaded() -> SearchViewModel {
        preview(query: "dune", catalog: ImmediatePreviewCatalog())
    }
}

/// Returns one page of fixture books immediately.
nonisolated private struct ImmediatePreviewCatalog: BookCatalog {
    func search(query: String, page: Int) async throws -> SearchPage {
        SearchPage(
            books: [Book.previewFixture],
            page: page,
            pageSize: 20,
            totalCount: 1
        )
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        throw AppError.notFound
    }
}

/// Always-empty search page for the Empty `#Preview` canvas.
nonisolated private struct EmptyPreviewCatalog: BookCatalog {
    func search(query: String, page: Int) async throws -> SearchPage {
        SearchPage(books: [], page: page, pageSize: 20, totalCount: 0)
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        throw AppError.notFound
    }
}

/// Always throws `.network` so Failed `#Preview` can render `ErrorStateView`.
nonisolated private struct FailingPreviewCatalog: BookCatalog {
    func search(query: String, page: Int) async throws -> SearchPage {
        throw AppError.network
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        throw AppError.notFound
    }
}

/// Sleeps before returning so Loading `#Preview` stays on the spinner.
nonisolated private struct DelayedPreviewCatalog: BookCatalog {
    let delay: Duration

    func search(query: String, page: Int) async throws -> SearchPage {
        try await Task.sleep(for: delay)
        return SearchPage(books: [Book.previewFixture], page: page, pageSize: 20, totalCount: 1)
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        throw AppError.notFound
    }
}
