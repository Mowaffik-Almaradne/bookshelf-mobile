import SwiftUI

/// Pagination footer for infinite lists: spinner, inline retry, or end caption.
/// Renders only; callers own page state and must not push domain types in.
struct LoadingFooterView: View {
    /// Visual modes for the footer. Prefer this enum over boolean flags.
    enum FooterState {
        case hidden
        case loading
        case retry(LocalizedStringKey)
        case end
    }

    let state: FooterState
    let onRetry: () -> Void

    var body: some View {
        Group {
            switch state {
            case .hidden:
                EmptyView()
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.medium)
                    .accessibilityLabel(Text("Loading more results"))
            case .retry(let title):
                Button(action: onRetry) {
                    Text(title)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.medium)
                .accessibilityHint(Text("Tries the request again"))
                .accessibilityIdentifier("retry")
            case .end:
                Text("End of results")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.medium)
                    .accessibilityLabel(Text("End of results"))
            }
        }
    }
}

#Preview("Loading") {
    LoadingFooterView(state: .loading, onRetry: {})
}

#Preview("Retry dark") {
    LoadingFooterView(state: .retry("Couldn't load more · Retry"), onRetry: {})
        .preferredColorScheme(.dark)
}

#Preview("End accessibility") {
    LoadingFooterView(state: .end, onRetry: {})
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    LoadingFooterView(state: .retry("Couldn't load more · Retry"), onRetry: {})
        .environment(\.layoutDirection, .rightToLeft)
}
