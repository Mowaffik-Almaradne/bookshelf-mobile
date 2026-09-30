import Foundation

/// One entry of a work's `authors` array.
///
/// Current payloads nest the id as `{ "author": { "key" } }`. Older records
/// put the id on the entry itself as `{ "key" }`. Both have to produce a key
/// or the details screen would drop authors that the API did return.
nonisolated struct AuthorRefDTO: Decodable, Sendable {
    let key: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try container.decodeIfPresent(TypeRefDTO.self, forKey: .author) {
            key = nested.key
        } else {
            key = try container.decodeIfPresent(String.self, forKey: .key)
        }
    }

    nonisolated private enum CodingKeys: String, CodingKey {
        case author
        case key
    }
}
