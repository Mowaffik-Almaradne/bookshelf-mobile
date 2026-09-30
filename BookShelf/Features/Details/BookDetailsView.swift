import SwiftUI

/// Details screen: composition + navigation only. No networking or error-copy strings.
struct BookDetailsView: View {
    @State private var viewModel: BookDetailsViewModel
    let connectivity: ConnectivityMonitor

    init(
        viewModel: BookDetailsViewModel,
        connectivity: ConnectivityMonitor = ConnectivityMonitor(isOnline: true)
    ) {
        _viewModel = State(initialValue: viewModel)
        self.connectivity = connectivity
    }

    var body: some View {
        VStack(spacing: 0) {
            if !connectivity.isOnline {
                OfflineBanner()
            }
            phaseContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text("Loading details"))
        case .loaded(let details, let source):
            loadedScroll(details: details, source: source)
        case .failed(let error):
            failedContent(error: error)
        }
    }

    private func loadedScroll(details: BookDetails, source: BookDetailsViewModel.Source) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                DetailsHeaderView(
                    title: details.title,
                    authors: details.authors,
                    coverID: details.coverID,
                    coverData: viewModel.coverData,
                    allowsNetwork: connectivity.isOnline,
                    firstPublishYear: details.firstPublishYear,
                    firstPublishDate: details.firstPublishDate
                )

                if source == .local {
                    Text("Showing saved copy")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SaveToggleButton(
                    isSaved: viewModel.isSaved,
                    isEnabled: true,
                    action: { Task { await viewModel.toggleSaved() } }
                )

                if let description = details.description, !description.isEmpty {
                    DescriptionSection(text: description)
                }

                if !details.subjects.isEmpty {
                    SubjectsSection(subjects: details.subjects)
                }
            }
            .padding(Spacing.large)
            .frame(maxWidth: ContentWidth.details)
            .frame(maxWidth: .infinity)
        }
    }

    private func failedContent(error: AppError) -> some View {
        VStack(spacing: Spacing.xLarge) {
            ErrorStateView(
                title: error.title,
                message: error.message,
                systemImage: error.systemImage,
                retryTitle: error.isRetryable ? "Retry" : nil,
                retryAccessibilityLabel: error.isRetryable ? "Retry loading details" : nil,
                onRetry: error.isRetryable
                    ? { Task { await viewModel.load() } }
                    : nil
            )

            SaveToggleButton(
                isSaved: viewModel.isSaved,
                isEnabled: true,
                action: { Task { await viewModel.toggleSaved() } }
            )
            .padding(.horizontal, Spacing.large)
        }
        .frame(maxWidth: ContentWidth.details)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Loaded") {
    let deps = AppDependencies.preview()
    NavigationStack {
        BookDetailsView(viewModel: .previewLoaded(), connectivity: deps.connectivity)
    }
    .environment(\.imageLoader, deps.images)
}

#Preview("Failed offline") {
    NavigationStack {
        BookDetailsView(
            viewModel: .previewFailedOffline(),
            connectivity: ConnectivityMonitor(isOnline: false)
        )
    }
}

#Preview("Dark a11y") {
    let deps = AppDependencies.preview()
    NavigationStack {
        BookDetailsView(viewModel: .previewLoaded(), connectivity: deps.connectivity)
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
    .environment(\.imageLoader, deps.images)
}

#Preview("RTL") {
    let deps = AppDependencies.preview()
    NavigationStack {
        BookDetailsView(viewModel: .previewLoaded(), connectivity: deps.connectivity)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.imageLoader, deps.images)
}

extension BookDetailsViewModel {
    @MainActor
    static func previewLoaded() -> BookDetailsViewModel {
        let deps = AppDependencies.preview()
        let book = Book.previewFixture
        let details = BookDetails(
            key: book.key,
            title: book.title,
            authors: book.authors,
            description: String(repeating: "A long description of Arrakis and the spice. ", count: 10),
            subjects: ["Science fiction", "Desert", "Empire", "Politics", "Ecology"],
            coverID: book.coverID,
            firstPublishYear: book.firstPublishYear,
            firstPublishDate: nil
        )
        let vm = BookDetailsViewModel(
            book: book,
            catalog: PreviewDetailsCatalog(details: details),
            shelf: deps.shelf,
            connectivity: PreviewConnectivity(isOnline: true)
        )
        return vm
    }

    @MainActor
    static func previewFailedOffline() -> BookDetailsViewModel {
        let deps = AppDependencies.preview()
        return BookDetailsViewModel(
            book: Book.previewFixture,
            catalog: PreviewDetailsCatalog(error: .offline),
            shelf: deps.shelf,
            connectivity: PreviewConnectivity(isOnline: false)
        )
    }
}

/// Preview-only catalog that returns a fixed details result or error.
nonisolated private struct PreviewDetailsCatalog: BookCatalog {
    var details: BookDetails?
    var error: AppError

    init(details: BookDetails) {
        self.details = details
        self.error = .notFound
    }

    init(error: AppError) {
        self.details = nil
        self.error = error
    }

    func search(query: String, page: Int) async throws -> SearchPage {
        SearchPage(books: [], page: page, pageSize: 20, totalCount: 0)
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        if let details { return details }
        throw error
    }
}
