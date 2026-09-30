# 03 — Open Library API contracts & tolerant decoding

All shapes below were **verified against the live API on 2026-09-29** (not from memory).
Fixtures for tests must be copied from real responses (trimmed), never hand-invented.

## Common rules

- Base URL: `https://openlibrary.org`. Covers: `https://covers.openlibrary.org`.
- Always send `User-Agent: BookShelf/1.0 (<your email or repo URL>)`. Open Library asks clients
  to identify themselves and may throttle anonymous traffic.
- Always send `Accept: application/json`.
- **Never `try!`, never `!` on decoded values, never `as!`.** (Q4)
- Every DTO field that is not structurally guaranteed is `Optional` and decoded with
  `decodeIfPresent`. Only `docs` in the search response and `title`/`key` in a work are treated as
  required — and even a missing `title` maps to a localized "Untitled" rather than a failure.
- Decoding happens **off the main actor** (`@concurrent`), see `04_NETWORKING.md`.

---

## 1. Search — `GET /search.json`

Query items:

| Param | Value |
|---|---|
| `q` | user text, trimmed; URLComponents does the percent-encoding |
| `page` | 1-based |
| `limit` | `20` |
| `fields` | `key,title,author_name,first_publish_year,cover_i,edition_count` |

Live sample (`limit=2`):

```json
{
  "numFound": 4063, "start": 0, "numFoundExact": true, "num_found": 4063,
  "documentation_url": "https://openlibrary.org/dev/docs/api/search",
  "q": "harry potter", "offset": null,
  "docs": [
    { "author_name": ["J. K. Rowling"], "cover_i": 15155833, "edition_count": 400,
      "first_publish_year": 1997, "key": "/works/OL82563W",
      "title": "Harry Potter and the Philosopher's Stone" },
    { "author_name": ["J. K. Rowling"], "cover_i": 15158664, "edition_count": 306,
      "first_publish_year": 1998, "key": "/works/OL82537W",
      "title": "Harry Potter and the Chamber of Secrets" }
  ]
}
```

Known variability:

| Field | Notes |
|---|---|
| `numFound` | Can **change between pages** (index updates). Do not treat it as exact. |
| `start` | `(page-1)*limit`. Useful for sanity but not required. |
| `docs[].key` | Usually `/works/OL…W`. Occasionally missing → **drop the doc** (cannot open details). |
| `docs[].title` | Rarely missing → "Untitled". |
| `docs[].author_name` | Optional array; may be empty. Display joined with ", " or "Unknown author". |
| `docs[].first_publish_year` | Optional Int. |
| `docs[].cover_i` | Optional Int; negative/zero → treat as nil. |
| Duplicates | The same `key` can appear on two consecutive pages (index shifting). **Dedupe by key.** (R2.2) |

DTO:

```swift
nonisolated struct SearchResponseDTO: Decodable, Sendable {
    let numFound: Int?
    let start: Int?
    let docs: [SearchDocDTO]
}

nonisolated struct SearchDocDTO: Decodable, Sendable {
    let key: String?
    let title: String?
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverI: Int?
    let editionCount: Int?
}
```
Use `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` once, centrally.

Mapping (`Book+DTO.swift`): `SearchDocDTO → Book?` (nil when `key` is missing or not a
`/works/` key). Keep mapping pure so it is unit-testable.

---

## 2. Work details — `GET {key}.json` (e.g. `/works/OL45804W.json`)

Two live samples, showing **both description shapes**:

```json
// OL45804W — description is a STRING
{ "title": "Fantastic Mr Fox", "key": "/works/OL45804W",
  "authors": [{ "author": { "key": "/authors/OL34184A" }, "type": { "key": "/type/author_role" } }],
  "type": { "key": "/type/work" },
  "description": "The main character of Fantastic Mr. Fox is …",
  "covers": [6498519, 8904777, 108274, -1, 10222599],
  "subject_places": ["English countryside"],
  "subjects": ["Animals", "Hunger", "Open Library Staff Picks", …],
  "first_publish_date": "October 1, 1988" }
```

```json
// OL82563W — description is an OBJECT
{ "title": "Harry Potter and the Philosopher's Stone", "key": "/works/OL82563W",
  "description": { "type": "/type/text", "value": "Turning the envelope over, …" },
  "authors": [{ "author": { "key": "/authors/OL23919A" }, "type": { "key": "/type/author_role" } }],
  "covers": [10521270, …], "subjects": [...], "excerpts": [...], "links": [...] }
```

Variability matrix (this is exactly what Q3-c tests must cover):

| Field | Shapes seen | Handling |
|---|---|---|
| `description` | string · `{type,value}` · absent | `FlexibleText` decoder (below) → `String?` |
| `authors` | `[{author:{key}}]` · `[{key}]` (legacy) · absent | Extract author keys tolerant to both; names need a **second request** |
| `covers` | `[Int]` with `-1` entries · absent | Filter `> 0`; first valid = primary cover |
| `subjects` | `[String]` · absent | Default `[]`, cap display to ~20 |
| `title` | present · (rare) absent | fallback to title passed from search |
| `type.key` | `/type/work` · `/type/redirect` | If redirect and `location` present → follow **once** |
| `first_publish_date` | free-form string · absent | Display as-is; never parse |
| Line endings | `\r\n` inside text | Normalise to `\n` in mapper |

`FlexibleText` — the reusable "string or `{value}` object" decoder:

```swift
nonisolated struct FlexibleText: Decodable, Sendable, Equatable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
            return
        }
        let object = try container.decode(TextObject.self)
        value = object.value
    }

    private struct TextObject: Decodable { let value: String }
}
```

Work DTO:

```swift
nonisolated struct WorkDTO: Decodable, Sendable {
    let key: String?
    let title: String?
    let description: FlexibleText?
    let covers: [Int]?
    let subjects: [String]?
    let authors: [AuthorRefDTO]?
    let firstPublishDate: String?
    let type: TypeRefDTO?
    let location: String?            // present only for redirects
}

nonisolated struct TypeRefDTO: Decodable, Sendable { let key: String? }

/// Tolerates {"author": {"key": "..."}} and legacy {"key": "..."}.
nonisolated struct AuthorRefDTO: Decodable, Sendable {
    let key: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let nested = try c.decodeIfPresent(TypeRefDTO.self, forKey: .author) {
            key = nested.key
        } else {
            key = try c.decodeIfPresent(String.self, forKey: .key)
        }
    }
    private enum CodingKeys: String, CodingKey { case author, key }
}
```

---

## 3. Author — `GET /authors/{id}.json`

```json
{ "name": "Roald Dahl", "personal_name": "Roald Dahl", "key": "/authors/OL34184A",
  "bio": { "type": "/type/text", "value": "…" }, "birth_date": "13 September 1916", … }
```

Only `name` is needed (`personal_name` as fallback). `bio` is `FlexibleText?` if ever displayed.

**Author-name resolution strategy** (details screen):
1. Seed with `author_name` from the search row (instant, offline-friendly).
2. If the work lists author keys and we are online, fetch up to **4** authors **concurrently**
   with `withThrowingTaskGroup`, best-effort: any failure keeps the seed names. Never block the
   description/subjects rendering on this — show details first, then update authors.

---

## 4. Covers — `https://covers.openlibrary.org/b/id/{cover_i}-{S|M|L}.jpg?default=false`

Verified behaviour:

| URL | Result |
|---|---|
| `…/id/99999999999-M.jpg` | **200** with a 43-byte transparent GIF (looks like "loaded" but blank) |
| `…/id/99999999999-M.jpg?default=false` | **404** |

Therefore **always append `?default=false`** so a missing cover becomes an error → placeholder,
instead of an invisible image. Sizes: `S` (~40px wide) for nothing, `M` (~180px) for rows,
`L` (~500px) for details. Rows use `M`, details use `L`; both are downsampled to the display size.

Cover URL building lives in one place:

```swift
nonisolated enum CoverURL {
    enum Size: String { case small = "S", medium = "M", large = "L" }
    static func url(coverID: Int, size: Size) -> URL? {
        guard coverID > 0 else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-\(size.rawValue).jpg?default=false")
    }
}
```

---

## 5. Domain models (what the UI sees)

```swift
nonisolated struct WorkKey: Hashable, Sendable, Codable {
    let rawValue: String                 // "/works/OL45804W"
    init?(rawValue: String)              // validates prefix "/works/"
    var detailsPath: String { rawValue + ".json" }
}

nonisolated struct Book: Identifiable, Hashable, Sendable {
    var id: WorkKey { key }
    let key: WorkKey
    let title: String
    let authors: [String]
    let firstPublishYear: Int?
    let coverID: Int?
}

nonisolated struct BookDetails: Hashable, Sendable {
    let key: WorkKey
    let title: String
    let authors: [String]
    let description: String?
    let subjects: [String]
    let coverID: Int?
    let firstPublishYear: Int?
    let firstPublishDate: String?
}

nonisolated struct ShelfBook: Identifiable, Hashable, Sendable {
    var id: WorkKey { details.key }
    let details: BookDetails
    let savedAt: Date
    var status: ReadingStatus
    let coverData: Data?                 // for offline covers (O3)
}

nonisolated enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case wantToRead, reading, finished
}
```

## 6. Test fixtures to create (real, trimmed)

| File | Purpose |
|---|---|
| `search_page1.json` | 20 docs, mixed optional fields (one without `cover_i`, one without `author_name`, one without `first_publish_year`) |
| `search_page2_overlap.json` | 20 docs where 2 keys repeat from page 1 → dedupe test |
| `search_last_page.json` | 7 docs (< limit) → end detection |
| `search_empty.json` | `docs: []`, `numFound: 0` |
| `search_doc_missing_key.json` | doc without `key` → dropped, not crash |
| `work_description_string.json` | OL45804W trimmed |
| `work_description_object.json` | OL82563W trimmed |
| `work_minimal.json` | only `title` and `key` |
| `work_legacy_authors.json` | `authors: [{"key": "/authors/OL1A"}]` |
| `work_redirect.json` | `type.key = /type/redirect`, `location` |
| `author.json` | OL34184A trimmed |
| `malformed.json` | truncated JSON → `.decoding` error, no crash |
