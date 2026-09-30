import SwiftUI

/// Single-line capsule chip for free-form tags (subjects, categories).
/// Must not know domain models — only displays the string it is given.
struct TagChip: View {
    let text: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .accessibilityLabel(text)
    }
}

#Preview("Light") {
    TagChip(text: "Science fiction")
        .padding()
}

#Preview("Dark") {
    TagChip(text: "Science fiction")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    TagChip(text: "Science fiction with a very long subject name")
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    TagChip(text: "خيال علمي")
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
