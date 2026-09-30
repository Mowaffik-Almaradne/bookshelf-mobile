import Foundation

/// `GET /authors/{id}.json`. Only a display name is needed; `bio` is decoded
/// so the string-or-object shape does not fail the request.
nonisolated struct AuthorDTO: Decodable, Sendable {
    let name: String?
    let personalName: String?
    let key: String?
    let bio: FlexibleText?

    /// `name` when it has text, otherwise `personal_name`. Empty strings are
    /// treated as missing so a blank field does not replace the search seeds.
    var preferredName: String? {
        if let name = trimmed(name) { return name }
        return trimmed(personalName)
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }
        return stripped
    }
}
