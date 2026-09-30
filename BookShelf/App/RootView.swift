import SwiftUI

/// Root of the app. Two tabs stay separate so search and the saved shelf can
/// each own a navigation stack without sharing screen state.
struct RootView: View {
    let dependencies: AppDependencies
    @State private var searchViewModel: SearchViewModel
    @State private var shelfViewModel: ShelfViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _searchViewModel = State(initialValue: dependencies.makeSearchViewModel())
        _shelfViewModel = State(initialValue: dependencies.makeShelfViewModel())
    }

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(
                    viewModel: searchViewModel,
                    makeDetails: { dependencies.makeBookDetailsViewModel(book: $0) },
                    connectivity: dependencies.connectivity
                )
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            // Shelf badge + persistence alert live in this child so observing
            // `ShelfStore` does not rebuild the Search `NavigationStack` on save.
            ShelfTab(
                dependencies: dependencies,
                viewModel: shelfViewModel
            )
        }
    }
}

/// Shelf tab only. Observes `ShelfStore` for badge count and `lastError` so a
/// save from Details does not invalidate Search's navigation identity.
private struct ShelfTab: View {
    let dependencies: AppDependencies
    @State var viewModel: ShelfViewModel

    var body: some View {
        NavigationStack {
            ShelfView(
                viewModel: viewModel,
                makeDetails: { dependencies.makeBookDetailsViewModel(book: $0) },
                connectivity: dependencies.connectivity
            )
        }
        .tabItem {
            Label("Shelf", systemImage: "books.vertical")
        }
        .badge(dependencies.shelf.books.count)
        .accessibilityIdentifier("shelfTab")
        .alert(
            dependencies.shelf.lastError?.title ?? "Couldn't save",
            isPresented: Binding(
                get: { dependencies.shelf.lastError != nil },
                set: { if !$0 { dependencies.shelf.clearLastError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                dependencies.shelf.clearLastError()
            }
        } message: {
            Text(dependencies.shelf.lastError?.message ?? "Please try again.")
        }
    }
}

#Preview("Light") {
    let dependencies = AppDependencies.preview()
    RootView(dependencies: dependencies)
        .environment(\.imageLoader, dependencies.images)
}

#Preview("Dark") {
    let dependencies = AppDependencies.preview()
    RootView(dependencies: dependencies)
        .preferredColorScheme(.dark)
        .environment(\.imageLoader, dependencies.images)
}

#Preview("Accessibility") {
    let dependencies = AppDependencies.preview()
    RootView(dependencies: dependencies)
        .dynamicTypeSize(.accessibility3)
        .environment(\.imageLoader, dependencies.images)
}

#Preview("RTL") {
    let dependencies = AppDependencies.preview()
    RootView(dependencies: dependencies)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.imageLoader, dependencies.images)
}
