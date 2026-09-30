import SwiftUI

/// Description body with selection and a local "Read more" expander.
/// The expanded flag is view-local `@State` — presentation only, not domain state.
struct DescriptionSection: View {
    let text: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isExpanded = false

    /// Rough threshold for ~8 body lines; exact line count needs layout measurement.
    private let expandThreshold = 280
    private let collapsedLineLimit = 8

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(effectiveLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsToggle {
                Button(isExpanded ? "Show less" : "Read more") {
                    isExpanded.toggle()
                }
                .font(.subheadline)
                .accessibilityLabel(Text(isExpanded ? "Show less" : "Read more"))
            }
        }
    }

    /// Accessibility sizes never truncate — the expander would only hide content.
    private var effectiveLineLimit: Int? {
        if dynamicTypeSize.isAccessibilitySize || isExpanded || !showsToggle {
            return nil
        }
        return collapsedLineLimit
    }

    private var showsToggle: Bool {
        guard !dynamicTypeSize.isAccessibilitySize else { return false }
        return text.count > expandThreshold || isExpanded
    }
}

#Preview("Light") {
    DescriptionSection(
        text: String(repeating: "A long description of Arrakis and the spice. ", count: 12)
    )
    .padding()
}

#Preview("Dark") {
    DescriptionSection(text: "Short description.")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    DescriptionSection(
        text: String(repeating: "A long description of Arrakis and the spice. ", count: 12)
    )
    .padding()
    .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    DescriptionSection(text: "وصف طويل للكتاب يكفي لعدة أسطر عند العرض.")
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
