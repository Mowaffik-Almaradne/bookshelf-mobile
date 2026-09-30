import Foundation

/// A `{ "key" }` reference, used for a work's type and for a nested author.
nonisolated struct TypeRefDTO: Decodable, Sendable {
    let key: String?
}
