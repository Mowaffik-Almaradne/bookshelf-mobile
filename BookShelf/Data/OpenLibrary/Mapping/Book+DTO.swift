import Foundation

nonisolated extension Book {
    /// `nil` when `key` is missing or is not a `/works/` path. The caller drops
    /// that document instead of crashing or opening a details screen it cannot load.
    init?(doc: SearchDocDTO) {
        guard let rawKey = doc.key, let key = WorkKey(rawValue: rawKey) else {
            return nil
        }
        let coverID: Int?
        if let cover = doc.coverI, cover > 0 {
            coverID = cover
        } else {
            coverID = nil
        }
        let trimmedTitle = doc.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String
        if let trimmedTitle, !trimmedTitle.isEmpty {
            title = trimmedTitle
        } else {
            title = Book.missingTitle
        }
        self.init(
            key: key,
            title: title,
            authors: doc.authorName ?? [],
            firstPublishYear: doc.firstPublishYear,
            coverID: coverID
        )
    }
}
