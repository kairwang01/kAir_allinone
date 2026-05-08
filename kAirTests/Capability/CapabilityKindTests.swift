//
//  CapabilityKindTests.swift
//  kAirTests
//
//  Cardinality + mapping enforcement for the frozen capability
//  vocabulary per
//  Contracts/capability-registry-and-adapter-contract-v1.md §3.
//

import XCTest
@testable import kAir

final class CapabilityKindTests: XCTestCase {
    // MARK: - Cardinality (§3.3 closed-set)

    func test_capabilityKind_hasTenCases() throws {
        XCTAssertEqual(CapabilityKind.allCases.count, 10)
    }

    func test_capabilityKind_shippedSubset_hasThreeCases() throws {
        let shipped = CapabilityKind.allCases.filter { $0.isShippedInV1 }
        XCTAssertEqual(shipped.count, 3)
        XCTAssertEqual(
            Set(shipped),
            Set([.aiCompletion, .threadLookup, .localStoreLookup])
        )
    }

    func test_capabilityKind_reservedSubset_hasSevenCases() throws {
        let reserved = CapabilityKind.allCases.filter { !$0.isShippedInV1 }
        XCTAssertEqual(reserved.count, 7)
        XCTAssertEqual(
            Set(reserved),
            Set([
                .placeSearch, .routePlanning, .musicPlayback,
                .videoPlayback, .healthRead, .healthWrite, .webSearch
            ])
        )
    }

    // MARK: - Surface family mapping (§3 table)

    func test_surfaceFamily_returnsValueInAllCases() throws {
        let allSurfaces = Set(SurfaceKind.allCases)
        for kind in CapabilityKind.allCases {
            XCTAssertTrue(
                allSurfaces.contains(kind.surfaceFamily),
                "\(kind).surfaceFamily must be a member of SurfaceKind.allCases"
            )
        }
    }

    func test_surfaceFamily_matchesContractTable() throws {
        // §3.1 shipped
        XCTAssertEqual(CapabilityKind.aiCompletion.surfaceFamily, .ai)
        XCTAssertEqual(CapabilityKind.threadLookup.surfaceFamily, .chat)
        XCTAssertEqual(CapabilityKind.localStoreLookup.surfaceFamily, .store)
        // §3.2 reserved
        XCTAssertEqual(CapabilityKind.placeSearch.surfaceFamily, .maps)
        XCTAssertEqual(CapabilityKind.routePlanning.surfaceFamily, .maps)
        XCTAssertEqual(CapabilityKind.musicPlayback.surfaceFamily, .music)
        XCTAssertEqual(CapabilityKind.videoPlayback.surfaceFamily, .video)
        XCTAssertEqual(CapabilityKind.healthRead.surfaceFamily, .health)
        XCTAssertEqual(CapabilityKind.healthWrite.surfaceFamily, .health)
        XCTAssertEqual(CapabilityKind.webSearch.surfaceFamily, .search)
    }

    // MARK: - Primary object kind mapping (§3 table)

    func test_primaryObjectKind_returnsValueInAllCases() throws {
        let allObjectKinds = Set(MatchingObjectKind.allCases)
        for kind in CapabilityKind.allCases {
            XCTAssertTrue(
                allObjectKinds.contains(kind.primaryObjectKind),
                "\(kind).primaryObjectKind must be a member of MatchingObjectKind.allCases"
            )
        }
    }

    func test_primaryObjectKind_matchesContractTable() throws {
        // §3.1 shipped
        XCTAssertEqual(CapabilityKind.aiCompletion.primaryObjectKind, .answerCard)
        XCTAssertEqual(CapabilityKind.threadLookup.primaryObjectKind, .thread)
        XCTAssertEqual(CapabilityKind.localStoreLookup.primaryObjectKind, .toolEntry)
        // §3.2 reserved
        XCTAssertEqual(CapabilityKind.placeSearch.primaryObjectKind, .place)
        XCTAssertEqual(CapabilityKind.routePlanning.primaryObjectKind, .route)
        XCTAssertEqual(CapabilityKind.musicPlayback.primaryObjectKind, .song)
        XCTAssertEqual(CapabilityKind.videoPlayback.primaryObjectKind, .video)
        XCTAssertEqual(CapabilityKind.healthRead.primaryObjectKind, .answerCard)
        XCTAssertEqual(CapabilityKind.healthWrite.primaryObjectKind, .answerCard)
        XCTAssertEqual(CapabilityKind.webSearch.primaryObjectKind, .searchResult)
    }
}
