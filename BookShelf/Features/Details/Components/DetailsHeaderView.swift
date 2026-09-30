import SwiftUI

/// Cover hero plus title, authors, and first-published metadata for details.
/// Plain values only — no view model or networking.
/// On regular width, `ViewThatFits` prefers cover beside text so iPad paragraphs
/// stay readable; compact width always stacks.
struct DetailsHeaderView: View {
    let title: String
    let authors: [String]
    let coverID: Int?
    let coverData: Data?
    var allowsNetwork: Bool = true
    let firstPublishYear: Int?
    let firstPublishDate: String?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.xLarge) {
                        cover
                        textBlock(alignment: .leading, multiline: .leading)
                    }
                    stacked
                }
            } else {
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(spacing: Spacing.medium) {
            cover
            textBlock(alignment: .center, multiline: .center)
        }
    }

    private var cover: some View {
        CoverView(
            coverID: coverID,
            preloadedData: coverData,
            allowsNetwork: allowsNetwork,
            size: .detail,
            title: title
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private func textBlock(
        alignment: HorizontalAlignment,
        multiline: TextAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: Spacing.small) {
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(multiline)
                .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))

            if !authors.isEmpty {
                Text(authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(multiline)
                    .frame(maxWidth: .infinity, alignment: frameAlignment(alignment))
            }

            if let yearText {
                InfoRow(label: "First published", value: yearText)
            }
        }
    }

    private func frameAlignment(_ alignment: HorizontalAlignment) -> Alignment {
        switch alignment {
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }

    private var yearText: String? {
        if let firstPublishYear {
            return firstPublishYear.formatted(.number.grouping(.never))
        }
        if let firstPublishDate, !firstPublishDate.isEmpty {
            return firstPublishDate
        }
        return nil
    }
}

#Preview("Light") {
    DetailsHeaderView(
        title: "Dune",
        authors: ["Frank Herbert"],
        coverID: 42,
        coverData: nil,
        firstPublishYear: 1965,
        firstPublishDate: nil
    )
    .padding()
}

#Preview("Dark a11y") {
    DetailsHeaderView(
        title: "Dune",
        authors: ["Frank Herbert"],
        coverID: nil,
        coverData: nil,
        firstPublishYear: 1965,
        firstPublishDate: nil
    )
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    DetailsHeaderView(
        title: "كثيب",
        authors: ["فرانك هربرت"],
        coverID: nil,
        coverData: nil,
        firstPublishYear: 1965,
        firstPublishDate: nil
    )
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}
