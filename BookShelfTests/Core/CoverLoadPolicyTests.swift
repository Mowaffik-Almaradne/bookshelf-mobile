import Foundation
import Testing
@testable import BookShelf

@Suite struct CoverLoadPolicyTests {
    @Test func offline_neverReturnsRemoteID() {
        let id = CoverLoadPolicy.remoteCoverID(
            coverID: 42,
            preloadedData: nil,
            allowsNetwork: false
        )
        #expect(id == nil)
    }

    @Test func preloadedBytes_skipRemoteEvenWhenOnline() {
        let id = CoverLoadPolicy.remoteCoverID(
            coverID: 42,
            preloadedData: Data([0x01]),
            allowsNetwork: true
        )
        #expect(id == nil)
    }

    @Test func onlineWithoutBytes_returnsPositiveCoverID() {
        let id = CoverLoadPolicy.remoteCoverID(
            coverID: 99,
            preloadedData: nil,
            allowsNetwork: true
        )
        #expect(id == 99)
    }

    @Test func negativeOrZeroCoverID_isIgnored() {
        #expect(
            CoverLoadPolicy.remoteCoverID(coverID: -1, preloadedData: nil, allowsNetwork: true)
                == nil
        )
        #expect(
            CoverLoadPolicy.remoteCoverID(coverID: 0, preloadedData: nil, allowsNetwork: true)
                == nil
        )
        #expect(
            CoverLoadPolicy.remoteCoverID(coverID: nil, preloadedData: nil, allowsNetwork: true)
                == nil
        )
    }
}
