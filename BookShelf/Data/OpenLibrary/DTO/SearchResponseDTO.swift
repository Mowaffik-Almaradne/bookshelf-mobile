import Foundation

/// Search index document. Every field except the response list is optional:
/// the index omits them, and a missing key is dropped at mapping time.
nonisolated struct SearchDocDTO: Decodable, Sendable {
    let key: String?
    let title: String?
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverI: Int?
    let editionCount: Int?
}

/// `GET /search.json` body. `docs` is the only required field; `numFound`
/// drifts between pages and is decoded as optional.
nonisolated struct SearchResponseDTO: Decodable, Sendable {
    let numFound: Int?
    let start: Int?
    let docs: [SearchDocDTO]
}
