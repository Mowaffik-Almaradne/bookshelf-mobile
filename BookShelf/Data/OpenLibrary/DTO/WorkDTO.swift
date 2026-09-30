import Foundation

/// `GET /works/{id}.json`. Nothing here is required: a redirect body has no
/// title, and a thin work may have only `key`. Missing pieces are filled by
/// the mapper, not by failing the decode.
nonisolated struct WorkDTO: Decodable, Sendable {
    let key: String?
    let title: String?
    let description: FlexibleText?
    let covers: [Int]?
    let subjects: [String]?
    let authors: [AuthorRefDTO]?
    let firstPublishDate: String?
    let type: TypeRefDTO?
    /// Set on `/type/redirect` documents. Not followed unless the type says so.
    let location: String?
}
