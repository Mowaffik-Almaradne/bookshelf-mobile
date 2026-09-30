import SwiftUI

/// Decorative fallback art when a cover is missing or still loading.
/// Must not know about books, networking, or image pipelines — only a title letter and a size.
struct CoverPlaceholder: View {
    let title: String
    let size: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color(.tertiarySystemFill))

            VStack(spacing: Spacing.xSmall) {
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(letter)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private var letter: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }
}

#Preview("Light") {
    CoverPlaceholder(title: "Dune", size: CoverSize.row.baseSize)
        .padding()
}

#Preview("Dark") {
    CoverPlaceholder(title: "Dune", size: CoverSize.detail.baseSize)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    CoverPlaceholder(title: "Dune", size: CoverSize.row.baseSize)
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    CoverPlaceholder(title: "كثيب", size: CoverSize.row.baseSize)
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
