//
//  ServerProviderSearchAPILiveTransportBoundaryTests.swift
//  kAirTests
//
//  A144 Search API live transport boundary tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPILiveTransportBoundaryTests: XCTestCase {

    func test_planningDocumentPinsRequiredChainAndReadinessChecklist() {
        let document = ServerProviderSearchAPILiveTransportBoundary.planningDocument()

        assertSendable(document)
        assertSendable(document.safeCopy)
        XCTAssertEqual(document.id, "a144-search-api-live-transport-boundary")
        XCTAssertEqual(document.state, .a144PlanningOnly)
        XCTAssertEqual(
            document.upstreamChain.map(\.checkpoint),
            ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain
        )
        XCTAssertEqual(
            document.upstreamChain.map(\.rank),
            Array(1...ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain.count)
        )
        XCTAssertEqual(
            document.readinessChecklist.map(\.item),
            ServerProviderSearchAPILiveTransportReadinessItem.requiredSet
        )
        XCTAssertEqual(
            document.safeCopy.upstreamCheckpointIDs,
            ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain.map(\.rawValue)
        )
        XCTAssertEqual(
            document.safeCopy.readinessItemIDs,
            ServerProviderSearchAPILiveTransportReadinessItem.requiredSet.map(\.rawValue)
        )
    }

    func test_boundaryIsPlanningOnlyAndNotCallable() {
        let document = ServerProviderSearchAPILiveTransportBoundary.planningDocument()

        XCTAssertNil(document.runtimeEntryPointName)
        XCTAssertFalse(document.state.isRuntimeCallable)
        XCTAssertFalse(document.isRuntimeCallable)
        XCTAssertFalse(document.safeCopy.isRuntimeCallable)
        XCTAssertTrue(document.statusLine.contains("value-only planning boundary"))
        XCTAssertTrue(document.statusLine.contains("no remote provider path is callable"))
        XCTAssertEqual(
            document.description,
            "ServerProviderSearchAPILiveTransportBoundaryDocument(id: a144-search-api-live-transport-boundary, state: a144PlanningOnly, upstream: 11, checklist: 12, callable: false)"
        )
    }

    func test_safeCopyAndReviewerCopyStayFreeOfLiveMaterial() throws {
        let document = ServerProviderSearchAPILiveTransportBoundary.planningDocument()
        let encodedSafeCopy = try JSONEncoder().encode(document.safeCopy)
        let safeCopyText = try XCTUnwrap(String(data: encodedSafeCopy, encoding: .utf8))
        let reviewerText = (
            [document.statusLine, document.description, document.safeCopy.description]
                + document.upstreamChain.map(\.reviewerCopy)
                + document.readinessChecklist.map(\.reviewerCopy)
        )
        .joined(separator: "\n")
        let joined = [safeCopyText, reviewerText].joined(separator: "\n")

        for fragment in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                joined.localizedCaseInsensitiveContains(fragment),
                "Boundary copy leaked forbidden fragment: \(fragment)"
            )
        }
    }

    func test_documentIsDeterministicAndCodable() throws {
        let first = ServerProviderSearchAPILiveTransportBoundary.planningDocument()
        let second = ServerProviderSearchAPILiveTransportBoundary.planningDocument()

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.safeCopy, second.safeCopy)

        let encoded = try JSONEncoder().encode(first)
        let decoded = try JSONDecoder().decode(
            ServerProviderSearchAPILiveTransportBoundaryDocument.self,
            from: encoded
        )
        XCTAssertEqual(decoded, first)
        XCTAssertEqual(decoded.safeCopy, first.safeCopy)
    }

    private func forbiddenLiveMaterialFragments() -> [String] {
        [
            "http" + "://",
            "https" + "://",
            "end" + "point",
            "api" + "Key",
            "O" + "Auth",
            "URL" + "Session",
            "S" + "DK",
            "cred" + "ential",
            "client" + "Handle",
            "raw" + "Query",
            "raw" + "Page",
            "provider" + "Payload",
            "pay" + "ment",
            "book" + "ing",
            "ord" + "er",
            "crawl" + "er",
            "M" + "CP",
            "Ga" + "ode",
            "Goo" + "gle",
            "hidden app" + "-control",
            "exec" + "ution",
            "exec" + "ute",
            "complete" + "d",
            "comple" + "tion",
        ]
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
        XCTAssertTrue(true, file: file, line: line)
    }
}
