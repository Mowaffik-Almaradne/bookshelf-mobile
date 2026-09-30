import Foundation
import Testing
@testable import BookShelf

@Suite struct WorkDecodingTests {
    @Test(arguments: [
        ("work_description_string", "The main character of Fantastic Mr. Fox"),
        ("work_description_object", "Turning the envelope over")
    ])
    func description_decodesBothShapes(fixture: String, prefix: String) async throws {
        let details = try await mapped(fixture, fallbackTitle: "Seed Title")
        let description = try #require(details.description)
        #expect(description.hasPrefix(prefix))
    }

    @Test func description_absent_isNil() async throws {
        let details = try await mapped("work_minimal", fallbackTitle: "Seed Title")
        #expect(details.description == nil)
    }

    @Test func covers_filterNegativeAndPickFirst() async throws {
        let data = try Fixtures.data("work_description_string")
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let covers = try #require(object["covers"] as? [Int])
        #expect(covers.contains(-1))

        var leadingNegative = object
        leadingNegative["covers"] = [-1, 0, 6498519, 8904777]
        let rewritten = try JSONSerialization.data(withJSONObject: leadingNegative)
        let dto = try await JSONDecoding.decode(WorkDTO.self, from: rewritten)
        let key = try #require(WorkKey(rawValue: "/works/OL45804W"))
        let details = BookDetails(dto: dto, key: key, authors: [], fallbackTitle: "Seed Title")

        #expect(details.coverID == 6498519)
    }

    @Test func authors_nestedShape_extractsKeys() async throws {
        let dto = try await work("work_description_string")
        #expect(dto.authors?.compactMap(\.key) == ["/authors/OL34184A"])
    }

    @Test func authors_legacyShape_extractsKeys() async throws {
        let dto = try await work("work_legacy_authors")
        #expect(dto.authors?.compactMap(\.key) == ["/authors/OL34184A"])
    }

    @Test func subjects_absent_isEmptyArray() async throws {
        let details = try await mapped("work_minimal", fallbackTitle: "Seed Title")
        #expect(details.subjects.isEmpty)
    }

    @Test func minimalWork_usesFallbackTitle() async throws {
        let original = try Fixtures.data("work_minimal")
        let object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var stripped = object
        stripped.removeValue(forKey: "title")
        let data = try JSONSerialization.data(withJSONObject: stripped)
        let dto = try await JSONDecoding.decode(WorkDTO.self, from: data)
        let key = try #require(WorkKey(rawValue: "/works/OL45804W"))

        let details = BookDetails(dto: dto, key: key, authors: [], fallbackTitle: "Seed Title")

        #expect(details.title == "Seed Title")
        #expect(details.key == key)
    }

    @Test func crlf_isNormalizedToLF() async throws {
        let details = try await mapped("work_description_string", fallbackTitle: "Seed Title")
        let description = try #require(details.description)

        #expect(description.contains("\r") == false)
        #expect(description.contains("\n"))
    }

    @Test func malformedJSON_throwsDecodingError_noCrash() async throws {
        let data = try Fixtures.data("malformed")

        do {
            _ = try await JSONDecoding.decode(WorkDTO.self, from: data)
            Issue.record("malformed JSON should fail decoding")
        } catch let error as AppError {
            guard case .decoding = error else {
                Issue.record("expected .decoding, got \(String(describing: error))")
                return
            }
        }
    }

    private func work(_ name: String) async throws -> WorkDTO {
        try await JSONDecoding.decode(WorkDTO.self, from: try Fixtures.data(name))
    }

    private func mapped(_ name: String, fallbackTitle: String) async throws -> BookDetails {
        let dto = try await work(name)
        let raw = try #require(dto.key)
        let key = try #require(WorkKey(rawValue: raw))
        return BookDetails(dto: dto, key: key, authors: [], fallbackTitle: fallbackTitle)
    }
}
