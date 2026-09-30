import Foundation
import Testing
@testable import BookShelf

@Suite struct AppErrorMappingTests {
    @Test(arguments: mappings)
    func httpError_mapsToAppError(input: HTTPError, expected: AppError) {
        #expect(AppError(http: input) == expected)
    }

    @Test func cancelled_isNotRetryable() {
        #expect(AppError.cancelled.isRetryable == false)
        #expect(AppError(http: .transport(.cancelled)).isRetryable == false)
    }

    @Test func notFound_isNotRetryable() {
        #expect(AppError.notFound.isRetryable == false)
        #expect(AppError(http: .badStatus(404)).isRetryable == false)
        #expect(AppError(http: .emptyBody).isRetryable == false)
    }

    @Test func otherCases_areRetryable() {
        #expect(AppError.offline.isRetryable)
        #expect(AppError.timeout.isRetryable)
        #expect(AppError.network.isRetryable)
        #expect(AppError.server.isRetryable)
        #expect(AppError.rateLimited.isRetryable)
        #expect(AppError.unknown.isRetryable)
        #expect(AppError.persistence.isRetryable)
        #expect(AppError.decoding("detail").isRetryable)
    }

    @Test func existingAppError_passesThrough() {
        let error: any Error = AppError.timeout
        #expect(AppError(error) == .timeout)
    }

    @Test func cancellationError_mapsToCancelled() {
        let error: any Error = CancellationError()
        #expect(AppError(error) == .cancelled)
    }

    @Test func urlError_usesTheSameTransportTable() {
        let error: any Error = URLError(.notConnectedToInternet)
        #expect(AppError(error) == .offline)
    }

    @Test func unrecognizedError_isUnknown() {
        struct Other: Error {}
        #expect(AppError(Other()) == .unknown)
    }
}

private nonisolated let mappings: [(HTTPError, AppError)] = [
    (.transport(.cancelled), .cancelled),
    (.transport(.notConnectedToInternet), .offline),
    (.transport(.networkConnectionLost), .offline),
    (.transport(.dataNotAllowed), .offline),
    (.transport(.internationalRoamingOff), .offline),
    (.transport(.timedOut), .timeout),
    (.transport(.cannotFindHost), .network),
    (.badStatus(404), .notFound),
    (.emptyBody, .notFound),
    (.badStatus(429), .rateLimited),
    (.badStatus(500), .server),
    (.badStatus(503), .server),
    (.badStatus(400), .unknown),
    (.invalidURL("/"), .unknown)
]
