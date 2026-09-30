import SwiftUI

/// Full-screen error surface with an optional Retry action.
/// Callers supply all copy and the retry label; this view must not know about
/// catalogs, view models, or which request failed.
struct ErrorStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let retryTitle: LocalizedStringKey?
    let retryAccessibilityLabel: LocalizedStringKey?
    let onRetry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let onRetry, let retryTitle {
                Button(action: onRetry) {
                    Text(retryTitle)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(retryAccessibilityLabel ?? retryTitle)
                .accessibilityHint(Text("Tries the request again"))
                .accessibilityIdentifier("retry")
            }
        }
    }
}

#Preview("Light") {
    ErrorStateView(
        title: "Connection problem",
        message: "Something went wrong with the network.",
        systemImage: "exclamationmark.icloud",
        retryTitle: "Retry",
        retryAccessibilityLabel: "Retry search",
        onRetry: {}
    )
}

#Preview("Dark") {
    ErrorStateView(
        title: "You're offline",
        message: "error.offline.message",
        systemImage: "wifi.slash",
        retryTitle: "Retry",
        retryAccessibilityLabel: "Retry search",
        onRetry: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    ErrorStateView(
        title: "Taking too long",
        message: "Open Library is slow right now.",
        systemImage: "clock.arrow.circlepath",
        retryTitle: "Retry",
        retryAccessibilityLabel: "Retry loading details",
        onRetry: {}
    )
    .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    ErrorStateView(
        title: "Something went wrong",
        message: "Please try again.",
        systemImage: "exclamationmark.triangle",
        retryTitle: "Retry",
        retryAccessibilityLabel: "Retry search",
        onRetry: {}
    )
    .environment(\.layoutDirection, .rightToLeft)
}
