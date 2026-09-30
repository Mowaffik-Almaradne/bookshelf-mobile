import Foundation
import Observation

/// Local-first details machine. UI-free so tests assert R4.3 without SwiftUI.
///
/// `@MainActor`: phase and shelf writes are observed by SwiftUI; keeping the
/// machine on the main actor avoids hopping for every `phase` assignment.
///
/// WHY local-first: a saved book must render with zero network calls; the catalog
/// is consulted only for an optional online refresh. WHY silent refresh failure:
/// the user already has a usable copy — a spinner or error would be worse than
/// stale data. WHY one automatic retry on `.timeout` / `.server`: transient Open
/// Library blips are common; a single delayed retry avoids bouncing the user to
/// Retry for a one-second hiccup. WHY save-from-seed: a failed details fetch must
/// not block saving the book the user already found in search.
@MainActor
@Observable
final class BookDetailsViewModel {
    /// Screen states. `loaded` carries provenance so the UI can show “saved copy”
    /// without a second boolean.
    enum Phase: Equatable {
        case loading
        case loaded(BookDetails, source: Source)
        case failed(AppError)
    }

    /// Where the currently displayed details came from. Local wins first paint;
    /// remote replaces it only after a successful refresh.
    enum Source: Equatable {
        case local
        case remote
    }

    let book: Book
    private(set) var phase: Phase = .loading

    var isSaved: Bool { shelf.isSaved(book.key) }
    var isOffline: Bool { !connectivity.isOnline }

    /// Offline cover bytes when the book is already on the shelf.
    var coverData: Data? { shelf.saved(book.key)?.coverData }

    private let catalog: any BookCatalog
    private let shelf: ShelfStore
    private let connectivity: any ConnectivityMonitoring

    init(
        book: Book,
        catalog: any BookCatalog,
        shelf: ShelfStore,
        connectivity: any ConnectivityMonitoring
    ) {
        self.book = book
        self.catalog = catalog
        self.shelf = shelf
        self.connectivity = connectivity
    }

    /// Loads details. Saved books paint from the shelf immediately; unsaved books
    /// fetch (with one timeout/server retry) or fail offline without touching the network.
    func load() async {
        if let local = shelf.saved(book.key) {
            phase = .loaded(local.details, source: .local)
            guard connectivity.isOnline else { return }
            // Refresh is best-effort; keep the local copy on any failure.
            guard let fresh = try? await fetchDetails() else { return }
            guard !Task.isCancelled else { return }
            phase = .loaded(fresh, source: .remote)
            shelf.refreshDetails(fresh)
            return
        }

        guard connectivity.isOnline else {
            phase = .failed(.offline)
            return
        }

        phase = .loading
        do {
            let details = try await fetchDetails()
            guard !Task.isCancelled else { return }
            phase = .loaded(details, source: .remote)
        } catch {
            let appError = AppError(error)
            // `.cancelled` must never become `.failed` (R11). Leaving `.loading`
            // is safe because the screen's `.task` is cancelled only as the view
            // tears down — there is no idle phase to snap back to on Details.
            if appError == .cancelled { return }
            guard !Task.isCancelled else { return }
            phase = .failed(appError)
        }
    }

    /// Removes when saved; otherwise persists loaded details, or the seed book when
    /// details never loaded — so a bad network never blocks saving.
    func toggleSaved() async {
        if isSaved {
            shelf.remove(book.key)
            return
        }
        if case .loaded(let details, _) = phase {
            await shelf.save(details)
        } else {
            // Assumption: seed fields are enough for an offline shelf row when
            // the details endpoint is down (description/subjects stay empty).
            await shelf.save(BookDetails(seed: book))
        }
    }

    /// One automatic retry after 1 s on `.timeout` / `.server`, skipped when cancelled.
    private func fetchDetails() async throws -> BookDetails {
        do {
            return try await catalog.details(workKey: book.key, seedAuthors: book.authors)
        } catch {
            let appError = AppError(error)
            if appError == .cancelled { throw appError }
            guard appError == .timeout || appError == .server else { throw appError }
            guard !Task.isCancelled else { throw AppError.cancelled }
            // Sleep cancellation is acceptable — we re-check before the second attempt.
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { throw AppError.cancelled }
            return try await catalog.details(workKey: book.key, seedAuthors: book.authors)
        }
    }
}
