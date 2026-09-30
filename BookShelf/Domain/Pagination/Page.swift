/// One fetched window of a list.
///
/// Generic so search, a shelf, or any later list can share `Paginator` without
/// the engine learning about a particular model. `page` is whatever index the
/// source used for this window; the paginator does not reinterpret it.
nonisolated struct Page<Item: Identifiable & Sendable>: Sendable {
    let items: [Item]
    /// Index reported by the source for this window. Advancement is `page + 1`.
    let page: Int
    /// Size that was requested. A shorter `items` array means the source ran out.
    let pageSize: Int
    /// Source-reported total, when it has one. Callers may pass `nil` when the
    /// number is missing or not trustworthy on its own.
    let totalCount: Int?
}
