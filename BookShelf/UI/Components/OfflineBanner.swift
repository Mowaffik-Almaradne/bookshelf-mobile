import SwiftUI

/// Thin strip announcing loss of connectivity.
/// Fixed copy only — must not observe network monitors or shelf state itself.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "wifi.slash")
            Text("You're offline")
                .font(.subheadline)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.small)
        .padding(.horizontal, Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("You are offline. Saved books are still available."))
    }
}

#Preview("Light") {
    OfflineBanner()
}

#Preview("Dark") {
    OfflineBanner()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    OfflineBanner()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    OfflineBanner()
        .environment(\.layoutDirection, .rightToLeft)
}
