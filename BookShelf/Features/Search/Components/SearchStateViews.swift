import SwiftUI

/// Idle hint before the user types a long enough query.
struct SearchIdleView: View {
    var body: some View {
        ContentUnavailableView(
            "Find your next book",
            systemImage: "books.vertical",
            description: Text("Search for a title, author or subject")
        )
    }
}

/// First-page spinner. Centered; no skeleton yet.
struct SearchLoadingView: View {
    var body: some View {
        ProgressView("Searching…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(Text("Searching"))
    }
}

/// Zero docs for a valid query. Catalog key keeps Arabic idiomatic (docs/08).
struct SearchEmptyView: View {
    let query: String

    var body: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No results for \"\(query)\"")
        }
    }
}

#Preview("Idle light") {
    SearchIdleView()
}

#Preview("Idle dark") {
    SearchIdleView()
        .preferredColorScheme(.dark)
}

#Preview("Idle accessibility") {
    SearchIdleView()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Loading") {
    SearchLoadingView()
}

#Preview("Empty") {
    SearchEmptyView(query: "xyz")
}

#Preview("Empty dark a11y") {
    SearchEmptyView(query: "xyz")
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Empty RTL") {
    SearchEmptyView(query: "كثيب")
        .environment(\.layoutDirection, .rightToLeft)
}

