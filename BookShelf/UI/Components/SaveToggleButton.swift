import SwiftUI

/// App-agnostic save / remove control. Label and hint flip with `isSaved` so
/// VoiceOver announces the next action, not the current state alone.
struct SaveToggleButton: View {
    let isSaved: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isSaved ? "Remove from shelf" : "Save to shelf",
                systemImage: isSaved ? "bookmark.slash" : "bookmark"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(isSaved ? "Remove from shelf" : "Save to shelf"))
        .accessibilityHint(
            Text(
                isSaved
                    ? "Removes this book from your reading list"
                    : "Adds this book to your reading list"
            )
        )
        .accessibilityIdentifier("save")
    }
}

#Preview("Save light") {
    SaveToggleButton(isSaved: false, isEnabled: true, action: {})
        .padding()
}

#Preview("Remove dark") {
    SaveToggleButton(isSaved: true, isEnabled: true, action: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    SaveToggleButton(isSaved: false, isEnabled: true, action: {})
        .padding()
        .dynamicTypeSize(.accessibility3)
}

#Preview("RTL") {
    SaveToggleButton(isSaved: false, isEnabled: true, action: {})
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
}
