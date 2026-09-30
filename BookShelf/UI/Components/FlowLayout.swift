import SwiftUI

/// Wraps subviews onto multiple lines with a fixed spacing.
/// Used for subject chips and similar flows. Handles zero subviews, a child
/// wider than the container, and proposals with a nil width. Knows nothing
/// about books or domains — only geometry.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.small

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).containerSize
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for index in subviews.indices {
            let frame = result.frames[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private struct Arrangement {
        var frames: [CGRect] = []
        var containerSize: CGSize = .zero
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> Arrangement {
        guard !subviews.isEmpty else { return Arrangement() }

        let maxWidth = proposal.width ?? .infinity
        var arrangement = Arrangement()
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var containerWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let placeWidth = min(size.width, maxWidth.isFinite ? maxWidth : size.width)

            if origin.x > 0, origin.x + placeWidth > maxWidth {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            let frameSize = CGSize(width: placeWidth, height: size.height)
            arrangement.frames.append(CGRect(origin: origin, size: frameSize))
            rowHeight = max(rowHeight, size.height)
            origin.x += placeWidth + spacing
            containerWidth = max(containerWidth, origin.x - spacing)
        }

        arrangement.containerSize = CGSize(
            width: proposal.width ?? containerWidth,
            height: origin.y + rowHeight
        )
        return arrangement
    }
}

#Preview("Light") {
    FlowLayoutPreviewHost()
        .padding()
}

#Preview("Dark") {
    FlowLayoutPreviewHost()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    FlowLayoutPreviewHost()
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    FlowLayoutPreviewHost()
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}

private struct FlowLayoutPreviewHost: View {
    private let chips = [
        "Science fiction", "Desert", "Arrakis", "Empire", "Politics",
        "Ecology", "Religion", "Adventure", "Classic", "Epic",
        "Space", "Prophecy", "Spice", "Fremen", "Mentat",
        "Bene Gesserit", "House Atreides", "Sardaukar", "Worms", "Water",
        "Dune Messiah", "Children of Dune", "God Emperor", "Heretics", "Chapterhouse"
    ]

    var body: some View {
        FlowLayout(spacing: Spacing.small) {
            ForEach(chips, id: \.self) { chip in
                TagChip(text: chip)
            }
        }
    }
}
