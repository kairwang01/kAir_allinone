//
//  ServerProviderSearchAPILiveTransportReadinessStatusSourceProducerTests.swift
//  kAirTests
//
//  A146 Search API planning evidence status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPILiveTransportReadinessStatusSourceProducerTests: XCTestCase {

    func test_acceptedAndRejectedReadinessDecisionsPackageRenderedStatus() throws {
        let accepted = acceptedDecision()
        let rejected = rejectedDecision(reason: .missingEvidence)
        let source = ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-ready", decision: accepted),
                    .init(recommendationID: "rec-blocked", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-ready", "rec-blocked"]
            )

        let readyPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-ready")
        )
        XCTAssertEqual(readyPresentation.cardHint, .warning)
        XCTAssertEqual(
            readyPresentation.badges.map(\.kind),
            [.remoteProvider, .includedQuota, .liveFreshness]
        )
        XCTAssertTrue(readyPresentation.statusLine.contains("planning evidence is ready"))
        XCTAssertTrue(readyPresentation.statusLine.contains("Provider path remains disabled"))
        assertSafePresentation(readyPresentation, "accepted")

        let blockedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-blocked")
        )
        XCTAssertEqual(blockedPresentation.cardHint, .disabled)
        XCTAssertEqual(blockedPresentation.badges.map(\.kind), [.unavailable])
        XCTAssertTrue(blockedPresentation.statusLine.contains("planning evidence is blocked"))
        XCTAssertTrue(blockedPresentation.statusLine.contains("Provider path remains disabled"))
        assertSafePresentation(blockedPresentation, "rejected")
    }

    func test_rejectionReasonsMapToStableAdvisoryBadges() throws {
        let cases: [
            (
                name: String,
                decision: ServerProviderSearchAPILiveTransportReadinessDecision,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            ("missing", rejectedDecision(reason: .missingEvidence), .unavailable),
            ("duplicate", rejectedDecision(reason: .duplicateEvidenceID), .unavailable),
            ("unknown", rejectedDecision(reason: .unknownEvidenceTarget), .unavailable),
            ("stale", rejectedDecision(reason: .staleBoundaryID), .staleCache),
            ("callable", rejectedDecision(reason: .callableRuntimeEntrypoint), .termsBlocked),
            ("unsafe", rejectedDecision(reason: .unsafeMaterialDetected), .termsBlocked),
            ("enabled", rejectedDecision(reason: .liveProviderPathEnabled), .termsBlocked),
        ]
        let inputs = cases.map { testCase in
            ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer.Input(
                recommendationID: "rec-\(testCase.name)",
                decision: testCase.decision
            )
        }
        let source = ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer()
            .statusSource(
                inputs: inputs,
                renderedRecommendationIDs: inputs.map(\.recommendationID)
            )

        for testCase in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(testCase.name)"),
                testCase.name
            )
            XCTAssertEqual(presentation.cardHint, .disabled, testCase.name)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("value-only policy"), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("Provider path remains disabled"), testCase.name)
            assertSafePresentation(presentation, testCase.name)
        }
    }

    func test_duplicateIDsKeepFirstAndHiddenMissingStayNil() throws {
        let first = acceptedDecision()
        let stale = rejectedDecision(reason: .unsafeMaterialDetected)
        let hidden = acceptedDecision()
        let source = ServerProviderSearchAPILiveTransportReadinessStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-visible", decision: first),
                    .init(recommendationID: "rec-visible", decision: stale),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: ["rec-visible"]
            )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-visible")
        )
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(
            presentation.badges.map(\.kind),
            [.remoteProvider, .includedQuota, .liveFreshness]
        )
        XCTAssertTrue(presentation.statusLine.contains("planning evidence is ready"))
        XCTAssertFalse(presentation.statusLine.contains("value-only policy"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_statusCopyDoesNotCarryUnsafeLiveMaterial() throws {
        let store = ServerProviderSearchAPILiveTransportReadinessStatusStore(
            decisions: [
                (recommendationID: "rec-safe", decision: acceptedDecision()),
                (recommendationID: "rec-unsafe", decision: unsafeRejectedDecision()),
            ]
        )
        let safePresentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-safe")
        )
        let unsafePresentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-unsafe")
        )

        assertSafePresentation(safePresentation, "safe")
        assertSafePresentation(unsafePresentation, "unsafe")
        let encodedSafeCopy = String(
            decoding: try JSONEncoder().encode(unsafeRejectedDecision().safeCopy),
            as: UTF8.self
        )
        assertSafeString(encodedSafeCopy, "encoded readiness safe copy")
    }

    private func acceptedDecision() -> ServerProviderSearchAPILiveTransportReadinessDecision {
        let decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(
                evidence: ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
            )
        )
        XCTAssertTrue(decision.isReadyForPlanning)
        return decision
    }

    private func rejectedDecision(
        reason: ServerProviderSearchAPILiveTransportReadinessRejection
    ) -> ServerProviderSearchAPILiveTransportReadinessDecision {
        let decision: ServerProviderSearchAPILiveTransportReadinessDecision
        switch reason {
        case .missingEvidence:
            decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(evidence: [])
            )
        case .duplicateEvidenceID:
            decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(
                    evidence: duplicateEvidence()
                )
            )
        case .unknownEvidenceTarget:
            decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(
                    evidence: ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
                        + [
                            .init(
                                id: "a146-unknown",
                                target: .unknown("a146-unknown-target")
                            ),
                        ]
                )
            )
        case .staleBoundaryID:
            decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(
                    boundaryDocument: boundary(id: "a146-stale-boundary"),
                    evidence: ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
                )
            )
        case .callableRuntimeEntrypoint:
            decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(
                    boundaryDocument: boundary(runtimeEntryPointName: "a146-runtime-entry"),
                    evidence: ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
                )
            )
        case .unsafeMaterialDetected:
            decision = unsafeRejectedDecision()
        case .liveProviderPathEnabled:
            decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
                request: ServerProviderSearchAPILiveTransportReadinessRequest(
                    evidence: ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence(),
                    liveProviderPathEnabled: true
                )
            )
        }

        XCTAssertEqual(decision.rejection, reason)
        XCTAssertFalse(decision.isReadyForPlanning)
        return decision
    }

    private func unsafeRejectedDecision() -> ServerProviderSearchAPILiveTransportReadinessDecision {
        var evidence = ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
        evidence[0] = .init(
            id: evidence[0].id,
            target: evidence[0].target,
            unsafeMaterialMarkers: unsafeFragments()
        )
        let decision = ServerProviderSearchAPILiveTransportReadinessGate.decision(
            request: ServerProviderSearchAPILiveTransportReadinessRequest(evidence: evidence)
        )
        XCTAssertEqual(decision.rejection, .unsafeMaterialDetected)
        return decision
    }

    private func duplicateEvidence() -> [ServerProviderSearchAPILiveTransportReadinessEvidence] {
        var evidence = ServerProviderSearchAPILiveTransportReadinessGate.requiredEvidence()
        evidence[1] = .init(
            id: evidence[0].id,
            target: evidence[1].target
        )
        return evidence
    }

    private func boundary(
        id: String = "a144-search-api-live-transport-boundary",
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

    private func unsafeFragments() -> [String] {
        [
            "http" + "s://provider.example/item",
            "api" + "Key=secret",
            "O" + "Auth bearer",
            "URL" + "Session client",
            "S" + "DK handle",
            "M" + "CP client descriptor",
            "Ga" + "ode route",
            "Goo" + "gle map",
            "book" + "ing id",
            "pay" + "ment token",
            "raw" + "Query text",
            "raw" + "Page body",
            "provider" + "Payload body",
            "exec" + "ution complete",
        ]
    }

    private func assertSafePresentation(
        _ presentation: ProviderStatusPresentation,
        _ label: String
    ) {
        assertSafeString(presentation.statusLine, "\(label) status")
        for badge in presentation.badges {
            assertSafeString(badge.label, "\(label) badge label")
            assertSafeString(badge.systemImage, "\(label) badge icon")
        }
    }

    private func assertSafeString(
        _ value: String,
        _ label: String
    ) {
        for fragment in unsafeFragments() {
            XCTAssertFalse(
                value.lowercased().contains(fragment.lowercased()),
                "\(label) contains \(fragment)"
            )
        }
    }
}
