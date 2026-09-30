import Foundation

/// Decodes a text value that Open Library sends either as a string or as
/// `{ "type", "value" }`. Description and author bios use both shapes.
nonisolated struct FlexibleText: Decodable, Sendable, Equatable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Acceptable: this branch fails when the payload is the object form.
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        let object = try container.decode(TextObject.self)
        value = object.value
    }

    /// Object form `{ "type", "value" }` used by some Open Library text fields.
    nonisolated private struct TextObject: Decodable, Sendable {
        let value: String
    }
}
