import SwiftUI

/// Compact label/value metadata row for detail screens (e.g. first published).
/// Must not know field semantics — callers pass already-formatted strings.
struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.small)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    InfoRow(label: "First published", value: "1965")
        .padding()
}

#Preview("Dark") {
    InfoRow(label: "First published", value: "1965")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    InfoRow(label: "First published", value: "1965")
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    InfoRow(label: "First published", value: "1965")
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
