import SwiftUI

/// Shared adaptive axis for every list row: horizontal at normal sizes,
/// vertical when Dynamic Type is an accessibility size.
/// `AnyLayout` is the Layout API's intended erasure — not a View type-erasure escape hatch.
/// Must not know about row content semantics (covers, titles, shelf state).
struct AdaptiveRowLayout<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var spacing: CGFloat = Spacing.medium
    @ViewBuilder var content: () -> Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
        layout {
            content()
        }
    }
}

#Preview("Light") {
    AdaptiveRowLayout {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(Color(.tertiarySystemFill))
            .frame(width: CoverSize.row.baseWidth, height: CoverSize.row.baseSize.height)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Dune").font(.headline)
            Text("Frank Herbert").font(.subheadline).foregroundStyle(.secondary)
        }
    }
    .padding()
}

#Preview("Dark") {
    AdaptiveRowLayout {
        Text("Cover")
        Text("Title stack")
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    AdaptiveRowLayout {
        Text("Cover")
        Text("Title stacks under the cover at accessibility sizes")
    }
    .padding()
    .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    AdaptiveRowLayout {
        Text("Cover")
        Text("Title")
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}
