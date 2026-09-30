# Prompt 04 — Phase 2: domain models & Open Library data layer

**Attach:** `@docs/03_OPEN_LIBRARY_API_AND_DECODING.md @docs/04_NETWORKING.md @docs/09_TESTING.md @docs/12_CODE_STANDARDS.md`

**Why it matters:** this is requirement Q3-c (decoding the details response in its different
shapes) — one of the three mandated test areas. The response shapes in `docs/03` were captured
from the live API, so they are facts, not guesses.

**Commits:** 2 (`feat(domain): book models and work key`, `feat(data): Open Library catalog with tolerant decoding`).

---

```
Phase 2 of docs/13_IMPLEMENTATION_PLAN.md: domain models and the Open Library data layer.
docs/03 contains response shapes verified against the live API — follow it exactly, do not
invent field names or guess shapes.

APP FILES — Domain (pure Swift, Foundation only, all `nonisolated ... Sendable`)
- Domain/Models/WorkKey.swift — failable init validating the "/works/" prefix; `detailsPath`.
- Domain/Models/Book.swift — Identifiable by WorkKey, Hashable.
- Domain/Models/BookDetails.swift
- Domain/Models/ShelfBook.swift — details + savedAt + status + coverData.
- Domain/Models/ReadingStatus.swift — wantToRead / reading / finished, Codable by rawValue.
- Domain/Services/BookCatalog.swift — the protocol plus `SearchPage` (books, page, pageSize,
  totalCount: Int? because numFound drifts and may be absent).
- Core/Images/CoverURL.swift — size enum and builder; MUST append `?default=false`
  (verified: without it a missing cover returns HTTP 200 with a 43-byte transparent GIF, which
  would render as an invisible image instead of falling back to a placeholder). Put that fact in
  the ///.

APP FILES — Data (DTOs never escape this layer)
- Data/OpenLibrary/OpenLibraryEndpoints.swift — static factories: search(query:page:limit:) with
  the `fields=` list from docs/03, work(key:), author(key:).
- Data/OpenLibrary/DTO/FlexibleText.swift — decodes a String OR {"type","value"} object.
- Data/OpenLibrary/DTO/SearchResponseDTO.swift, WorkDTO.swift, AuthorDTO.swift, AuthorRefDTO
  tolerant to both {"author":{"key"}} and legacy {"key"} shapes.
- Data/OpenLibrary/Mapping/Book+DTO.swift — SearchDocDTO → Book? (nil when key missing or not a
  /works/ key, so bad docs are dropped instead of crashing).
- Data/OpenLibrary/Mapping/BookDetails+DTO.swift — filters covers <= 0, normalises \r\n to \n,
  defaults subjects to [], falls back to the seed title.
- Data/OpenLibrary/OpenLibraryBookCatalog.swift — `nonisolated final class`, implements
  BookCatalog using HTTPClient + JSONDecoding. Requirements:
    * search: decode + map inside the @concurrent path so the main actor only receives domain
      values (decode and map in one @concurrent function returning [Book]/SearchPage).
    * details: follow a `/type/redirect` work EXACTLY ONCE via its `location`, then stop.
    * author names: resolve with `withThrowingTaskGroup`, max 4 authors, concurrently,
      best-effort — any failure keeps the seed names from the search row. Never let author
      resolution fail the whole details call.
    * map HTTPError → AppError via the AppError initialiser; never leak HTTPError upward.

FIXTURES (BookShelfTests/Fixtures/) — real payloads, trimmed to ≤ 3 KB each
Fetch with curl (User-Agent: BookShelf/1.0) and trim, keeping real values:
  search_page1.json (20 docs; ensure one doc lacks cover_i, one lacks author_name, one lacks
  first_publish_year), search_page2_overlap.json (20 docs, 2 keys repeated from page 1),
  search_last_page.json (7 docs), search_empty.json, search_doc_missing_key.json,
  work_description_string.json (from /works/OL45804W.json — keeps the -1 entry in covers),
  work_description_object.json (from /works/OL82563W.json), work_minimal.json,
  work_legacy_authors.json, work_redirect.json, author.json (/authors/OL34184A.json),
  malformed.json (truncated JSON).
Add a header comment in Support/Fixtures.swift listing each source URL and the capture date.

TEST FILES
- Support/MockHTTPClient.swift — conforms to HTTPClient; enqueue responses matched by path
  substring; records every Endpoint sent (so tests can assert exact requests); thread-safe via a
  lock with a justification comment.
- Decoding/SearchResponseDecodingTests.swift — page decodes 20 books; optional fields map; doc
  without key is dropped; empty docs → empty page; missing numFound → totalCount nil.
- Decoding/WorkDecodingTests.swift — PARAMETRISED over both description shapes; description
  absent → nil; covers filter -1 and pick the first positive; authors nested shape; authors
  legacy shape; subjects absent → []; minimal work uses fallback title; \r\n normalised;
  malformed.json → AppError.decoding and no crash.
- Data/OpenLibraryBookCatalogTests.swift — redirect followed exactly once (assert the recorded
  endpoints); author names resolved and merged; author request failure falls back to seed names;
  search maps to SearchPage with the right page/pageSize; HTTP 500 surfaces as AppError.server.

ACCEPTANCE
- Zero force unwraps in mapping; every optional handled explicitly.
- No DTO type is referenced outside BookShelf/Data/.
- Decoding + mapping happen off the main actor (@concurrent), verified by the code path, and the
  catalog returns only Sendable domain values.

VERIFICATION
xcodebuild build -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
xcodebuild test -scheme BookShelf -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BookShelfTests -quiet
rg -n 'try!|as!|fatalError|print\(|@unchecked|nonisolated\(unsafe\)|DispatchQueue|Task\.detached' BookShelf/ || echo "grep clean"
rg -n 'DTO' BookShelf/Features BookShelf/Domain BookShelf/UI || echo "no DTO leakage"

NON-NEGOTIABLES
- Swift 6 language mode, strict concurrency, ZERO warnings. Default actor isolation is MainActor,
  approachable concurrency is ON: a plain `nonisolated async` func runs on the CALLER's executor,
  so CPU-heavy work (JSON decoding, image decoding) MUST be `@concurrent nonisolated`.
- Types used off the main actor (DTOs, domain models, clients) must be explicitly `nonisolated`
  and `Sendable`.
- iOS 17.0 deployment target. Apple frameworks only: no SPM/CocoaPods packages, no Combine,
  no ObservableObject/@Published. Use @Observable, SwiftData, Swift Testing.
- FORBIDDEN: force unwrap `!`, `try!`, `as!`, `fatalError` on runtime data, `array[0]`, `print`,
  `DispatchQueue`, `Task.detached`, `@unchecked Sendable` / `nonisolated(unsafe)` in app code,
  `AnyView`, hard-coded colours or font sizes, URLs built by string interpolation of user input.
- Layering: Views never touch URLSession/SwiftData. ViewModels never import SwiftUI or SwiftData.
  Domain imports Foundation only. DTOs never leave the Data layer.
- Every I/O dependency is a protocol injected through `init`. No singletons read from Views.
- `///` doc comments on every type and protocol requirement, explaining WHY and the invariants.
  Every `try?` gets a one-line comment saying why failure is acceptable.
- Tests: Swift Testing, deterministic, no sleeps, fixtures from real API responses. Same commit.
- SCOPE: implement exactly what this prompt lists. Do not add files, features, abstractions or
  refactors that were not requested. If something looks wrong, STOP and tell me.
- FINISH BY: running build + tests + grep, pasting the exact result lines, listing assumptions,
  and proposing commit messages. Do not commit yourself.

COMPONENT & SCALABILITY RULES
- One primary type per file; file name == type name; target ≤ 150 lines, hard limit 250.
- Mapping lives in `Type+DTO.swift` extensions, not inside the catalog class.
- Reusable decoding helpers (FlexibleText) are generic and independently tested.
- Before adding a type, grep for an existing one that does the job; report what you reused.
```
