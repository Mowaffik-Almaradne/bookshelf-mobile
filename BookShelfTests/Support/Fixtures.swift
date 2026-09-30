import Foundation
import Testing

/// Loads trimmed JSON fixtures from the test bundle by file name, without the
/// `.json` suffix. `#require` fails the calling test when the file is missing
/// instead of decoding an empty buffer.
///
/// Captured 2026-09-29 with `User-Agent: BookShelf/1.0`. Each file is a real
/// response trimmed to the fields this app decodes, and is at most 3 KB.
///
/// - `search_page1.json` — `GET /search.json?q=tolkien&page=1&limit=20`.
///   Three docs are swapped with other live hits so the page exercises
///   omitted fields: OL1625497W (no `cover_i`, query `history`), OL16478631W
///   (no `author_name`, query `anonymous`), OL20849874W (no `first_publish_year`,
///   query `-first_publish_year:[1 TO 2100]`). `edition_count` was dropped to
///   stay under 3 KB.
/// - `search_page2_overlap.json` — page 2 of the same Tolkien search. The live
///   page shared no keys with page 1, so the first two docs are the page-1
///   documents for OL27482W and OL27513W (real values from that response).
/// - `search_last_page.json` — `q=tolkien&page=104&limit=20` (7 docs).
/// - `search_empty.json` — `q=zzzzqqqqnonexistentbookxyz` (`docs: []`, `numFound: 0`).
/// - `search_doc_missing_key.json` — the page-1 Tolkien documents for OL27482W
///   and OL27513W; the key was removed from the first because this capture
///   had no doc that omitted `key`.
/// - `work_description_string.json` — `GET /works/OL45804W.json`. Description
///   is a string containing CRLF; `covers` still includes `-1`.
/// - `work_description_object.json` — `GET /works/OL82563W.json`. Description
///   is `{type, value}`; the value is the first 500 characters of the live text.
/// - `work_minimal.json` — title and key taken from OL45804W.
/// - `work_legacy_authors.json` — title and key from OL45804W. Live samples in
///   this capture used the nested author object, so the author list is the
///   documented legacy `{ "key" }` shape with the author id that work actually
///   uses (`/authors/OL34184A`).
/// - `work_redirect.json` — `GET /works/OL45883W.json` (`location` is `/works/OL45804W`).
/// - `author.json` — `GET /authors/OL34184A.json` (name, personal name, bio prefix).
/// - `malformed.json` — the first 48 bytes of the trimmed OL45804W document.
enum Fixtures {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(
            bundle.url(forResource: name, withExtension: "json"),
            "Missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }
}

/// Anchor for `Bundle(for:)`. The fixture files live in this test target.
private final class BundleToken {}
