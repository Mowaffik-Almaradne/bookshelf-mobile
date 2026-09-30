import SwiftUI

/// Search / shelf list row. Takes plain values only — no view model, no network.
struct BookRow: View {
    let book: Book
    let isSaved: Bool
    /// Forwarded to `CoverView` so airplane mode does not spin on cover URLs.
    var allowsNetwork: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AdaptiveRowLayout {
            CoverView(
                coverID: book.coverID,
                preloadedData: nil,
                allowsNetwork: allowsNetwork,
                size: .row,
                title: book.title
            )
            textStack
            if isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(composedAccessibilityLabel)
    }

    @ViewBuilder
    private var textStack: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(book.title)
                .font(.headline)
                .lineLimit(titleLineLimit)
            if !book.authors.isEmpty {
                Text(authorsJoined)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(authorsLineLimit)
            }
            if let year = book.firstPublishYear {
                Text(year, format: .number.grouping(.never))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authorsJoined: String {
        book.authors.joined(separator: ", ")
    }

    private var titleLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 2
    }

    private var authorsLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }

    /// Built from parts so a missing year does not leave a dangling clause.
    private var composedAccessibilityLabel: Text {
        var label = Text(book.title)
        if !book.authors.isEmpty {
            label = label + Text(", ") + Text("by \(authorsJoined)")
        }
        if let year = book.firstPublishYear {
            label = label + Text(", ") + Text("First published") + Text(" ")
                + Text(year, format: .number.grouping(.never))
        }
        if isSaved {
            label = label + Text(", ") + Text("Saved to shelf")
        }
        return label
    }
}

#Preview("Light") {
    BookRow(book: Book.previewFixture, isSaved: true)
        .padding()
}

#Preview("Dark") {
    BookRow(book: Book.previewFixture, isSaved: false)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    BookRow(book: Book.previewFixture, isSaved: true)
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    BookRow(book: Book.previewFixture, isSaved: true)
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}

extension Book {
    /// Stable fixture for `#Preview` only. Key is a known valid `/works/` path.
    nonisolated static var previewFixture: Book {
        let key = WorkKey(rawValue: "/works/OL893415W")
            ?? WorkKey(rawValue: "/works/OL1W")
            ?? WorkKey(rawValue: "/works/OL0W")
        // Three known-valid shapes; if all fail the WorkKey parser changed.
        guard let key else {
            preconditionFailure("WorkKey preview fixture must parse")
        }
        return Book(
            key: key,
            title: "Dune",
            authors: ["Frank Herbert"],
            firstPublishYear: 1965,
            coverID: 123
        )
    }
}
