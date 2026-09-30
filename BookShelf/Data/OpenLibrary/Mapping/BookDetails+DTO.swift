import Foundation

nonisolated extension BookDetails {
    /// Builds the screen model from a work document.
    ///
    /// Covers of `0` and below are placeholders in the API (including `-1`)
    /// and are ignored. Newlines are normalised so CRLF text does not render
    /// as a broken paragraph. A missing title uses `fallbackTitle` from the
    /// search row rather than failing the screen. Subjects default to an empty
    /// list when the field is absent.
    init(dto: WorkDTO, key: WorkKey, authors: [String], fallbackTitle: String) {
        let trimmedTitle = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String
        if let trimmedTitle, !trimmedTitle.isEmpty {
            title = trimmedTitle
        } else {
            title = fallbackTitle
        }
        self.init(
            key: key,
            title: title,
            authors: authors,
            description: Self.normalizedDescription(dto.description?.value),
            subjects: dto.subjects ?? [],
            coverID: dto.covers?.first { $0 > 0 },
            firstPublishYear: nil,
            firstPublishDate: dto.firstPublishDate
        )
    }

    private static func normalizedDescription(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.isEmpty else { return nil }
        return normalized
    }
}
