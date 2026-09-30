import Foundation
import Observation
import SwiftData

/// Composition root. Screens receive services by injection; nothing reads singletons.
@MainActor
@Observable
final class AppDependencies {
    let catalog: any BookCatalog
    /// Single source of truth for saved state (R4.4). Also satisfies `SavedStateReading`.
    let shelf: ShelfStore
    /// Concrete so SwiftUI Observation tracks path flips for offline banners.
    let connectivity: ConnectivityMonitor
    let images: any ImageLoading

    init(
        catalog: any BookCatalog,
        shelf: ShelfStore,
        connectivity: ConnectivityMonitor,
        images: any ImageLoading
    ) {
        self.catalog = catalog
        self.shelf = shelf
        self.connectivity = connectivity
        self.images = images
    }

    /// Production wiring. Throws when the on-disk `ModelContainer` cannot open;
    /// the app entry falls back to `liveInMemory()` instead of crashing.
    static func live() throws -> AppDependencies {
        makeLive(container: try ModelContainer.live())
    }

    /// Same live network stack with an ephemeral shelf — launch fallback.
    static func liveInMemory() -> AppDependencies {
        let container: ModelContainer
        do {
            container = try ModelContainer.inMemory()
        } catch {
            // Schema is fixed at compile time; failure means the process cannot host SwiftData.
            preconditionFailure("In-memory ModelContainer must open: \(error)")
        }
        return makeLive(container: container)
    }

    /// Preview and offline canvas: stub catalog, in-memory shelf, no network images.
    static func preview() -> AppDependencies {
        let container: ModelContainer
        do {
            container = try ModelContainer.inMemory()
        } catch {
            preconditionFailure("In-memory ModelContainer must open: \(error)")
        }
        let images = UnimplementedImageLoader()
        let repository = SwiftDataShelfRepository(container: container)
        let shelf = ShelfStore(repository: repository, images: images)
        return AppDependencies(
            catalog: PreviewSearchCatalog(),
            shelf: shelf,
            connectivity: ConnectivityMonitor(isOnline: true),
            images: images
        )
    }

    func makeSearchViewModel(debounce: Duration = .milliseconds(350)) -> SearchViewModel {
        SearchViewModel(
            catalog: catalog,
            savedState: shelf,
            connectivity: connectivity,
            debounce: debounce
        )
    }

    func makeShelfViewModel() -> ShelfViewModel {
        ShelfViewModel(store: shelf)
    }

    func makeBookDetailsViewModel(book: Book) -> BookDetailsViewModel {
        BookDetailsViewModel(
            book: book,
            catalog: catalog,
            shelf: shelf,
            connectivity: connectivity
        )
    }

    private static func makeLive(container: ModelContainer) -> AppDependencies {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        guard let baseURL = components.url else {
            preconditionFailure("Open Library base URL must form from scheme+host")
        }
        let http = URLSessionHTTPClient(
            baseURL: baseURL,
            session: .openLibrary,
            userAgent: "BookShelf/1.0 (com.efendi.bookshelf)"
        )
        let images = ImageLoader()
        let repository = SwiftDataShelfRepository(container: container)
        let shelf = ShelfStore(repository: repository, images: images)
        return AppDependencies(
            catalog: OpenLibraryBookCatalog(http: http),
            shelf: shelf,
            connectivity: ConnectivityMonitor(),
            images: images
        )
    }
}

/// Tiny catalog for `AppDependencies.preview()` canvases.
nonisolated private struct PreviewSearchCatalog: BookCatalog {
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
