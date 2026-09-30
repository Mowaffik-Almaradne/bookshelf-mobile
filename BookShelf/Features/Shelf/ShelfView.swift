import SwiftUI

/// Shelf screen: list + empty state + swipe delete + reading-status filter (O1).
/// Composition only — persistence lives in `ShelfStore` via the view model.
struct ShelfView: View {
    @State private var viewModel: ShelfViewModel
    let makeDetails: (Book) -> BookDetailsViewModel
    let connectivity: ConnectivityMonitor

    init(
        viewModel: ShelfViewModel,
        makeDetails: @escaping (Book) -> BookDetailsViewModel = { book in
            BookDetailsViewModel(
                book: book,
                catalog: PreviewShelfDetailsCatalog(),
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
            shelfContent
        }
        .navigationTitle("Shelf")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Filter", selection: $vm.statusFilter) {
                        Text("All").tag(ReadingStatus?.none)
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(Optional(status))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel(Text("Filter by reading status"))
                .disabled(!vm.hasSavedBooks)
            }
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailsView(
                viewModel: makeDetails(book),
                connectivity: connectivity
            )
        }
        .accessibilityIdentifier("shelf")
    }

    @ViewBuilder
    private var shelfContent: some View {
        if !viewModel.hasSavedBooks {
            ContentUnavailableView(
                "Your shelf is empty",
                systemImage: "books.vertical",
                description: Text("Save books from Search to read them offline.")
            )
        } else if viewModel.books.isEmpty {
            ContentUnavailableView(
                "No books with this status",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Try another filter or change a book’s reading status.")
            )
        } else {
            List {
                ForEach(viewModel.books) { book in
                    NavigationLink(value: book.asBook) {
                        ShelfRow(book: book, allowsNetwork: connectivity.isOnline)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.remove(book.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .accessibilityHint(Text("Removes this book from your reading list"))
                    }
                    .contextMenu {
                        readingStatusMenu(for: book)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func readingStatusMenu(for book: ShelfBook) -> some View {
        ForEach(ReadingStatus.allCases, id: \.self) { status in
            Button {
                viewModel.setStatus(status, for: book.id)
            } label: {
                if book.status == status {
                    Label(status.title, systemImage: "checkmark")
                } else {
                    Text(status.title)
                }
            }
        }
    }
}

/// Preview-only stub so `#Preview` canvases do not hit the network.
nonisolated private struct PreviewShelfDetailsCatalog: BookCatalog {
    func search(query: String, page: Int) async throws -> SearchPage {
        SearchPage(books: [], page: page, pageSize: 20, totalCount: 0)
    }

    func details(workKey: WorkKey, seedAuthors: [String]) async throws -> BookDetails {
        throw AppError.notFound
    }
}

#Preview("Empty") {
    NavigationStack {
        ShelfView(viewModel: .preview())
    }
}

#Preview("Populated dark") {
    NavigationStack {
        ShelfView(viewModel: .previewPopulated())
    }
    .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    NavigationStack {
        ShelfView(viewModel: .previewPopulated())
    }
    .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    NavigationStack {
        ShelfView(viewModel: .previewPopulated())
    }
    .environment(\.layoutDirection, .rightToLeft)
}

extension ShelfViewModel {
    @MainActor
    static func preview() -> ShelfViewModel {
        ShelfViewModel(store: AppDependencies.preview().shelf)
    }

    @MainActor
    static func previewPopulated() -> ShelfViewModel {
        let repository = PreviewSeedShelfRepository(books: [.previewFixture])
        let store = ShelfStore(repository: repository, images: UnimplementedImageLoader())
        return ShelfViewModel(store: store)
    }
}

/// In-process fake for `#Preview` canvases — keeps previews off SwiftData and the network.
@MainActor
private final class PreviewSeedShelfRepository: ShelfRepository {
    private var storage: [WorkKey: ShelfBook]

    init(books: [ShelfBook]) {
        storage = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
    }

    func fetchAll() throws -> [ShelfBook] {
        storage.values.sorted { $0.savedAt > $1.savedAt }
    }

    func fetch(workKey: WorkKey) throws -> ShelfBook? {
        storage[workKey]
    }

    func save(_ book: ShelfBook) throws {
        storage[book.id] = book
    }

    func remove(workKey: WorkKey) throws {
        storage[workKey] = nil
    }

    func update(workKey: WorkKey, status: ReadingStatus) throws {
        guard var book = storage[workKey] else { return }
        book.status = status
        storage[workKey] = book
    }
}
