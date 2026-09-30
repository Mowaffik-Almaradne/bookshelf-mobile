import SwiftUI

/// Subject chips via the shared flow layout, capped at 20 with a "+N more" chip.
struct SubjectsSection: View {
    let subjects: [String]

    private let visibleLimit = 20

    var body: some View {
        let visible = Array(subjects.prefix(visibleLimit))
        let overflow = subjects.count - visible.count

        FlowLayout(spacing: Spacing.small) {
            ForEach(visible, id: \.self) { subject in
                TagChip(text: subject)
            }
            if overflow > 0 {
                TagChip(text: String(localized: "+\(overflow) more"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Light") {
    SubjectsSection(subjects: [
        "Science fiction", "Desert", "Arrakis", "Empire", "Politics",
        "Ecology", "Religion", "Adventure", "Classic", "Epic",
        "Space", "Prophecy", "Spice", "Fremen", "Mentat",
        "Bene Gesserit", "House Atreides", "Sardaukar", "Worms", "Water",
        "Dune Messiah", "Children of Dune"
    ])
    .padding()
}

#Preview("Dark") {
    SubjectsSection(subjects: ["Fiction", "Classic"])
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    SubjectsSection(subjects: ["Science fiction", "Desert", "Arrakis"])
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    SubjectsSection(subjects: ["خيال علمي", "صحراء"])
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
