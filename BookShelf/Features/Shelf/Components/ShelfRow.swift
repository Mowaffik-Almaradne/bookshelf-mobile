import SwiftUI

/// Shelf list row. Reuses `CoverView` with offline `preloadedData` and
/// `AdaptiveRowLayout` — same layout contract as search, different cover source.
struct ShelfRow: View {
    let book: ShelfBook
    /// When offline, missing cover bytes stay on the placeholder (no remote fetch).
    var allowsNetwork: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdaptiveRowLayout {
            CoverView(
                coverID: book.details.coverID,
                preloadedData: book.coverData,
                allowsNetwork: allowsNetwork,
                size: .row,
                title: book.details.title
            )
            textStack
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(composedAccessibilityLabel)
    }

    @ViewBuilder
    private var textStack: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(book.details.title)
                .font(.headline)
                .lineLimit(titleLineLimit)
            if !book.details.authors.isEmpty {
                Text(authorsJoined)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(authorsLineLimit)
            }
            if let year = book.details.firstPublishYear {
                Text(year, format: .number.grouping(.never))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(book.status.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authorsJoined: String {
        book.details.authors.joined(separator: ", ")
    }

    private var titleLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 2
    }

    private var authorsLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }

    private var composedAccessibilityLabel: Text {
        var label = Text(book.details.title)
        if !book.details.authors.isEmpty {
            label = label + Text(", ") + Text("by \(authorsJoined)")
        }
        if let year = book.details.firstPublishYear {
            label = label + Text(", ") + Text("First published") + Text(" ")
                + Text(year, format: .number.grouping(.never))
        }
        label = label + Text(", ") + Text("Saved to shelf")
        label = label + Text(", ") + Text(book.status.title)
        return label
    }
}

#Preview("Light") {
    ShelfRow(book: .previewFixture)
        .padding()
}

#Preview("Dark") {
    ShelfRow(book: .previewFixture)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    ShelfRow(book: .previewFixture)
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    ShelfRow(book: .previewFixture)
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}

extension ShelfBook {
    /// Stable fixture for `#Preview` only.
    static var previewFixture: ShelfBook {
        ShelfBook(
            details: BookDetails(
                key: Book.previewFixture.key,
                title: Book.previewFixture.title,
                authors: Book.previewFixture.authors,
                description: nil,
                subjects: [],
                coverID: Book.previewFixture.coverID,
                firstPublishYear: Book.previewFixture.firstPublishYear,
                firstPublishDate: nil
            ),
            savedAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .wantToRead,
            coverData: nil
        )
    }
}
