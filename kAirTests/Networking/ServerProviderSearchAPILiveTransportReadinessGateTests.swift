//
//  ServerProviderSearchAPILiveTransportReadinessGateTests.swift
//  kAirTests
//
//  A145 Search API live transport readiness gate tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPILiveTransportReadinessGateTests: XCTestCase {

    func test_acceptsOnlyCompleteSafeEvidenceAndNonCallableBoundary() {
        let evidence = ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
        let decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(evidence: evidence)
        )

        assertSendable(decision)
        assertSendable(decision.safeCopy)
        XCTAssertEqual(decision.state, .readyForPlanning)
        XCTAssertTrue(decision.isReadyForPlanning)
        XCTAssertNil(decision.rejection)
        XCTAssertNil(decision.runtimeEntryPointName)
        XCTAssertFalse(decision.liveProviderPathEnabled)
        XCTAssertEqual(
            decision.coveredCheckpointIDs,
            ServerProviderSearchAPILiveTransportBoundaryCheckpoint.requiredChain.map(\.rawValue)
        )
        XCTAssertEqual(
            decision.coveredReadinessItemIDs,
            ServerProviderSearchAPILiveTransportReadinessItem.requiredSet.map(\.rawValue)
        )
        XCTAssertTrue(decision.missingCheckpointIDs.isEmpty)
        XCTAssertTrue(decision.missingReadinessItemIDs.isEmpty)
        XCTAssertEqual(decision.acceptedEvidenceIDs, evidence.map(\.normalizedID))
        XCTAssertTrue(decision.safeCopy.boundaryIsCurrent)
        XCTAssertFalse(decision.safeCopy.hasRuntimeEntrypoint)
        XCTAssertFalse(decision.safeCopy.liveProviderPathEnabled)
        XCTAssertEqual(decision.safeCopy.acceptedEvidenceIDs, evidence.map(\.normalizedID))
        XCTAssertTrue(decision.statusLine.contains("planning only"))
        XCTAssertTrue(decision.statusLine.contains("live provider path remains disabled"))
    }

    func test_rejectsMissingEvidenceWithStableReasonAndMissingIDs() {
        let evidence = ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
            .filter {
                $0.target.checkpoint != .meteredEntitlement
                    && $0.target.readinessItem != .serverOwnership
            }
        let decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(evidence: evidence)
        )

        XCTAssertEqual(decision.state, .rejected)
        XCTAssertFalse(decision.isReadyForPlanning)
        XCTAssertEqual(decision.rejection, .missingEvidence)
        XCTAssertEqual(decision.missingCheckpointIDs, ["meteredEntitlement"])
        XCTAssertEqual(decision.missingReadinessItemIDs, ["serverOwnership"])
        XCTAssertTrue(decision.acceptedEvidenceIDs.isEmpty)
        XCTAssertTrue(decision.safeCopy.acceptedEvidenceIDs.isEmpty)
    }

    func test_rejectsDuplicateUnknownCallableStaleUnsafeAndLiveEnabledInputs() {
        assertRejected(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                evidence: duplicateIDSetup()
            ),
            reason: .duplicateEvidenceID,
            duplicateEvidenceID: "a145-checkpoint-meteredEntitlement"
        )
        assertRejected(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                evidence: requiredEvidence()
                    + [
                        ServerProviderSearchAPILiveTransportReadinessEvidence(
                            id: "a145-unknown-evidence",
                            target: .unknown("a145-unknown-target")
                        ),
                    ]
            ),
            reason: .unknownEvidenceTarget,
            unknownEvidenceID: "a145-unknown-evidence"
        )
        assertRejected(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                boundaryDocument: boundary(runtimeEntryPointName: "a145-runtime-entry"),
                evidence: requiredEvidence()
            ),
            reason: .callableRuntimeEntrypoint,
            runtimeEntryPointName: "a145-runtime-entry"
        )
        assertRejected(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                boundaryDocument: boundary(id: "a145-stale-boundary"),
                evidence: requiredEvidence()
            ),
            reason: .staleBoundaryID
        )
        assertRejected(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                evidence: unsafeEvidenceSetup()
            ),
            reason: .unsafeMaterialDetected,
            unsafeEvidenceID: "a145-checkpoint-meteredEntitlement"
        )
        assertRejected(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                evidence: requiredEvidence(),
                liveProviderPathEnabled: true
            ),
            reason: .liveProviderPathEnabled,
            liveProviderPathEnabled: true
        )
    }

    func test_safeCopyContainsNoLiveMaterial() throws {
        let decisions = [
            ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(evidence: requiredEvidence())
            ),
            ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(evidence: unsafeEvidenceSetup())
            ),
            ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(
                    boundaryDocument: boundary(runtimeEntryPointName: "a145-runtime-entry"),
                    evidence: requiredEvidence()
                )
            ),
        ]

        let encodedCopies = try decisions.map { decision in
            let data = try JSONEncoder().encode(decision.safeCopy)
            return try XCTUnwrap(String(data: data, encoding: .utf8))
        }
        let joined = (
            encodedCopies
                + decisions.map(\.statusLine)
                + decisions.map(\.description)
                + decisions.map { $0.safeCopy.description }
        )
        .joined(separator: "\n")

        for fragment in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                joined.localizedCaseInsensitiveContains(fragment),
                "Readiness safe copy leaked forbidden fragment: \(fragment)"
            )
        }
    }

    func test_decisionIsDeterministicAndCodable() throws {
        let request = ServerProviderSearchAPILiveTransportReadinessRequest(evidence: requiredEvidence())
        let first = ServerProviderSearchAPILiveTransportReadinessGate.decision(request: request)
        let second = ServerProviderSearchAPILiveTransportReadinessGate.decision(request: request)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.safeCopy, second.safeCopy)

        let encoded = try JSONEncoder().encode(first)
        let decoded = try JSONDecoder().decode(
            ServerProviderSearchAPILiveTransportReadinessDecision.self,
            from: encoded
        )
        XCTAssertEqual(decoded, first)
        XCTAssertEqual(decoded.safeCopy, first.safeCopy)
    }

    private func assertRejected(
        request: ServerProviderSearchAPILiveTransportReadinessRequest,
        reason: ServerProviderSearchAPILiveTransportReadinessRejection,
        duplicateEvidenceID: String? = nil,
        unknownEvidenceID: String? = nil,
        unsafeEvidenceID: String? = nil,
        runtimeEntryPointName: String? = nil,
        liveProviderPathEnabled: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(request: request)

        XCTAssertEqual(decision.state, .rejected, file: file, line: line)
        XCTAssertFalse(decision.isReadyForPlanning, file: file, line: line)
        XCTAssertEqual(decision.rejection, reason, file: file, line: line)
        XCTAssertTrue(decision.acceptedEvidenceIDs.isEmpty, file: file, line: line)
        XCTAssertTrue(decision.safeCopy.acceptedEvidenceIDs.isEmpty, file: file, line: line)
        XCTAssertEqual(decision.duplicateEvidenceID, duplicateEvidenceID, file: file, line: line)
        XCTAssertEqual(decision.unknownEvidenceID, unknownEvidenceID, file: file, line: line)
        XCTAssertEqual(decision.unsafeEvidenceID, unsafeEvidenceID, file: file, line: line)
        XCTAssertEqual(decision.runtimeEntryPointName, runtimeEntryPointName, file: file, line: line)
        XCTAssertEqual(decision.liveProviderPathEnabled, liveProviderPathEnabled, file: file, line: line)
    }

    private func requiredEvidence() -> [ServerProviderSearchAPILiveTransportReadinessEvidence] {
        ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
    }

    private func duplicateIDSetup() -> [ServerProviderSearchAPILiveTransportReadinessEvidence] {
        var evidence = requiredEvidence()
        evidence[1] = ServerProviderSearchAPILiveTransportReadinessEvidence(
            id: evidence[0].id,
            target: evidence[1].target
        )
        return evidence
    }

    private func unsafeEvidenceSetup() -> [ServerProviderSearchAPILiveTransportReadinessEvidence] {
        var evidence = requiredEvidence()
        evidence[0] = ServerProviderSearchAPILiveTransportReadinessEvidence(
            id: evidence[0].id,
            target: evidence[0].target,
            unsafeMaterialMarkers: ["unsafe-marker"]
        )
        return evidence
    }

    private func boundary(
        id: String = ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID,
        runtimeEntryPointName: String? = nil
    ) -> ServerProviderSearchAPILiveTransportBoundaryDocument {
        let current = ServerProviderSearchAPILiveTransportBoundary.planningDocument()
        return ServerProviderSearchAPILiveTransportBoundaryDocument(
            id: id,
            state: current.state,
            upstreamChain: current.upstreamChain,
            readinessChecklist: current.readinessChecklist,
            runtimeEntryPointName: runtimeEntryPointName
        )
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
