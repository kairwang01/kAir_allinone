//
//  ServerProviderTransportAdapterStatusSourceProducerTests.swift
//  kAirTests
//
//  A136 external provider transport adapter status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderTransportAdapterStatusSourceProducerTests: XCTestCase {

    func test_preflightDecisionsPackageRenderedAcceptedAndRejectedStatus() throws {
        let acceptedCases: [
            (
                String,
                ServerProviderTransportAdapterPreflightDecision,
                ProviderStatusBadgeKind,
                ProviderStatusCardHint,
                [String]
            )
        ] = [
            (
                "search",
                acceptedDecision(
                    id: "a136-search",
                    adapterID: "a136-search-adapter",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    membershipTier: .plus,
                    meteredDecisionID: "a136-search-metered",
                    transportLeaseID: "a136-search-lease"
                ),
                .meteredPremium,
                .warning,
                [
                    "a136-search-adapter",
                    "a136-search-request",
                    "searchAPI",
                    "webSearch",
                    "meteredPremium",
                    "a136-search-metered",
                    "a136-search-lease",
                ]
            ),
            (
                "gaode",
                acceptedDecision(
                    id: "a136-gaode",
                    adapterID: "a136-gaode-adapter",
                    providerFamily: .gaode,
                    capability: .localServiceSearch,
                    costClass: .includedQuota,
                    membershipTier: .plus
                ),
                .includedQuota,
                .normal,
                [
                    "a136-gaode-adapter",
                    "a136-gaode-request",
                    "gaode",
                    "localServiceSearch",
                    "includedQuota",
                ]
            ),
            (
                "google",
                acceptedDecision(
                    id: "a136-google",
                    adapterID: "a136-google-adapter",
                    providerFamily: .googleMaps,
                    capability: .placeSearch,
                    costClass: .meteredPremium,
                    membershipTier: .plus
                ),
                .meteredPremium,
                .warning,
                [
                    "a136-google-adapter",
                    "a136-google-request",
                    "googleMaps",
                    "placeSearch",
                    "meteredPremium",
                ]
            ),
            (
                "crawler",
                acceptedDecision(
                    id: "a136-crawler",
                    adapterID: "a136-crawler-adapter",
                    providerFamily: .crawler,
                    capability: .crawlerFetch,
                    costClass: .meteredPremium,
                    membershipTier: .pro
                ),
                .meteredPremium,
                .warning,
                [
                    "a136-crawler-adapter",
                    "a136-crawler-request",
                    "crawler",
                    "crawlerFetch",
                    "meteredPremium",
                ]
            ),
            (
                "mcp",
                acceptedDecision(
                    id: "a136-mcp",
                    adapterID: "a136-mcp-adapter",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    membershipTier: .pro
                ),
                .includedQuota,
                .normal,
                [
                    "a136-mcp-adapter",
                    "a136-mcp-request",
                    "mcp",
                    "mcpTool",
                    "includedQuota",
                ]
            ),
        ]
        let rejectedCases: [
            (
                String,
                ServerProviderTransportAdapterPreflightDecision,
                ProviderStatusBadgeKind
            )
        ] = [
            (
                "search",
                rejectedDecision(
                    id: "a136-search-rejected",
                    adapterID: "a136-search-rejected-adapter",
                    providerFamily: .searchAPI,
                    capability: .webSearch,
                    costClass: .meteredPremium,
                    membershipTier: .plus,
                    reason: .staleBudgetEvidence
                ),
                .costBlocked
            ),
            (
                "gaode",
                rejectedDecision(
                    id: "a136-gaode-rejected",
                    adapterID: "a136-gaode-rejected-adapter",
                    providerFamily: .gaode,
                    capability: .localServiceSearch,
                    costClass: .includedQuota,
                    membershipTier: .plus,
                    reason: .includedQuotaExhausted
                ),
                .costBlocked
            ),
            (
                "google",
                rejectedDecision(
                    id: "a136-google-rejected",
                    adapterID: "a136-google-rejected-adapter",
                    providerFamily: .googleMaps,
                    capability: .placeSearch,
                    costClass: .meteredPremium,
                    membershipTier: .plus,
                    reason: .privacyBlocked
                ),
                .privacyBlocked
            ),
            (
                "crawler",
                rejectedDecision(
                    id: "a136-crawler-rejected",
                    adapterID: "a136-crawler-rejected-adapter",
                    providerFamily: .crawler,
                    capability: .crawlerFetch,
                    costClass: .meteredPremium,
                    membershipTier: .pro,
                    reason: .experimentalProviderDisabled
                ),
                .unavailable
            ),
            (
                "mcp",
                rejectedDecision(
                    id: "a136-mcp-rejected",
                    adapterID: "a136-mcp-rejected-adapter",
                    providerFamily: .mcp,
                    capability: .mcpTool,
                    costClass: .includedQuota,
                    membershipTier: .pro,
                    reason: .confirmationMissing
                ),
                .termsBlocked
            ),
        ]
        let hidden = acceptedDecision(
            id: "a136-hidden",
            adapterID: "a136-hidden-adapter",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            membershipTier: .plus,
            meteredDecisionID: "a136-hidden-metered",
            transportLeaseID: "a136-hidden-lease"
        )
        let inputs = acceptedCases.map { entry in
            ServerProviderTransportAdapterStatusSourceProducer.Input(
                recommendationID: "rec-accepted-\(entry.0)",
                decision: entry.1
            )
        } + rejectedCases.map { entry in
            ServerProviderTransportAdapterStatusSourceProducer.Input(
                recommendationID: "rec-rejected-\(entry.0)",
                decision: entry.1
            )
        } + [
            .init(recommendationID: "rec-hidden", decision: hidden),
        ]
        let renderedIDs = acceptedCases.map { "rec-accepted-\($0.0)" }
            + rejectedCases.map { "rec-rejected-\($0.0)" }
        let source = ServerProviderTransportAdapterStatusSourceProducer()
            .statusSource(
                inputs: inputs,
                renderedRecommendationIDs: renderedIDs + ["rec-accepted-search"]
            )
        let baseline = ServerProviderTransportAdapterPreflightStatusStore(
            decisions: inputs.map { input in
                (
                    recommendationID: input.recommendationID,
                    decision: input.decision
                )
            }
        )

        XCTAssertEqual(source.renderedRecommendationIDs, renderedIDs.sorted())
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        for (name, decision, expectedCostBadge, expectedHint, expectedMarkers) in acceptedCases {
            let id = "rec-accepted-\(name)"
            let presentation = try XCTUnwrap(source.providerStatusPresentation(for: id), name)
            let text = providerStatusText(presentation)

            XCTAssertEqual(presentation, baseline.providerStatusPresentation(for: id), name)
            XCTAssertEqual(presentation.cardHint, expectedHint, name)
            XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral, name)
            XCTAssertEqual(badge(expectedCostBadge, in: presentation)?.tone, .neutral, name)
            XCTAssertTrue(text.contains("preflight accepted"), name)
            XCTAssertTrue(text.contains("value-only metadata"), name)
            XCTAssertTrue(text.contains("no provider transport has run"), name)
            XCTAssertFalse(text.contains("unavailable"), name)
            XCTAssertFalse(text.contains("blocked by metadata policy"), name)
            XCTAssertEqual(presentation.recommendationID, id, name)
            XCTAssertEqual(presentation.id, "provider-status-\(id)", name)
            for marker in expectedMarkers {
                XCTAssertTrue(presentation.statusLine.contains(marker), "\(name): \(marker)")
            }
            XCTAssertNil(decision.rejectionReason, name)
        }
        for (name, decision, expectedBadge) in rejectedCases {
            let id = "rec-rejected-\(name)"
            let presentation = try XCTUnwrap(source.providerStatusPresentation(for: id), name)
            let reason = try XCTUnwrap(decision.rejectionReason, name)
            let text = providerStatusText(presentation)

            XCTAssertEqual(presentation, baseline.providerStatusPresentation(for: id), name)
            XCTAssertEqual(presentation.cardHint, .disabled, name)
            XCTAssertEqual(badge(expectedBadge, in: presentation)?.tone, .warning, name)
            XCTAssertNil(badge(.remoteProvider, in: presentation), name)
            XCTAssertTrue(text.contains("preflight is blocked"), name)
            XCTAssertTrue(text.contains(reason.rawValue.lowercased()), name)
            XCTAssertTrue(text.contains("no provider transport has run"), name)
            XCTAssertFalse(text.contains("preflight accepted"), name)
        }
    }

    func test_duplicateRecommendationIDsKeepFirstDecisionAndHiddenMissingStayNil() throws {
        let first = acceptedDecision(
            id: "a136-first",
            adapterID: "a136-first-adapter",
            providerFamily: .gaode,
            capability: .localServiceSearch,
            costClass: .includedQuota,
            membershipTier: .plus
        )
        let duplicate = rejectedDecision(
            id: "a136-duplicate",
            adapterID: "a136-duplicate-adapter",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            membershipTier: .plus,
            reason: .missingEntitlement
        )
        let source = ServerProviderTransportAdapterStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-dup", decision: first),
                    .init(recommendationID: "rec-dup", decision: duplicate),
                    .init(recommendationID: "rec-hidden", decision: duplicate),
                ],
                renderedRecommendationIDs: [
                    "rec-dup",
                    "rec-hidden-filtered",
                ]
            )
        let presentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-dup"))

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-dup", "rec-hidden-filtered"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("a136-first-adapter"))
        XCTAssertTrue(presentation.statusLine.contains("gaode"))
        XCTAssertFalse(presentation.statusLine.contains("a136-duplicate-adapter"))
        XCTAssertFalse(presentation.statusLine.contains("missingEntitlement"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden-filtered"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_rejectionReasonMatrixMapsToStableAdvisoryBadges() throws {
        let cases: [
            (
                ServerProviderTransportAdapterPreflightRejectionReason,
                ProviderStatusBadgeKind
            )
        ] = [
            (.privacyBlocked, .privacyBlocked),
            (.membershipTierTooLow, .costBlocked),
            (.missingEntitlement, .costBlocked),
            (.meteredEligibilityMissing, .costBlocked),
            (.staleBudgetEvidence, .costBlocked),
            (.sourcePolicyMissing, .termsBlocked),
            (.attributionMissing, .termsBlocked),
            (.crawlerRobotsBlocked, .termsBlocked),
            (.confirmationMissing, .termsBlocked),
            (.experimentalProviderDisabled, .unavailable),
            (.missingTransportLease, .unavailable),
        ]
        let source = ServerProviderTransportAdapterStatusSourceProducer()
            .statusSource(
                inputs: cases.map { reason, _ in
                    .init(
                        recommendationID: "rec-\(reason.rawValue)",
                        decision: rejectedDecision(
                            id: "a136-\(reason.rawValue)",
                            adapterID: "a136-\(reason.rawValue)-adapter",
                            providerFamily: .crawler,
                            capability: .crawlerFetch,
                            costClass: .meteredPremium,
                            membershipTier: .pro,
                            reason: reason
                        )
                    )
                },
                renderedRecommendationIDs: cases.map { reason, _ in
                    "rec-\(reason.rawValue)"
                }
            )

        for (reason, expectedBadge) in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(reason.rawValue)"),
                reason.rawValue
            )

            XCTAssertEqual(presentation.cardHint, .disabled, reason.rawValue)
            XCTAssertEqual(
                badge(expectedBadge, in: presentation)?.tone,
                .warning,
                reason.rawValue
            )
            XCTAssertTrue(presentation.statusLine.contains(reason.rawValue), reason.rawValue)
            XCTAssertTrue(
                presentation.statusLine.contains("No provider transport has run"),
                reason.rawValue
            )
        }
    }

    func test_encodedDebugAndStatusCopiesDoNotLeakRuntimeOrSensitiveFragments() throws {
        let accepted = acceptedDecision(
            id: "a136-safe-accepted",
            adapterID: "a136-safe-adapter",
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: .meteredPremium,
            membershipTier: .plus,
            meteredDecisionID: "a136-safe-metered",
            transportLeaseID: "a136-safe-lease"
        )
        let rejected = rejectedDecision(
            id: "a136-safe-rejected",
            adapterID: "a136-safe-rejected-adapter",
            providerFamily: .mcp,
            capability: .mcpTool,
            costClass: .includedQuota,
            membershipTier: .pro,
            reason: .confirmationMissing
        )
        let store = ServerProviderTransportAdapterPreflightStatusStore(
            decisions: [
                (recommendationID: "rec-accepted", decision: accepted),
                (recommendationID: "rec-rejected", decision: rejected),
            ]
        )
        let acceptedPresentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-accepted")
        )
        let rejectedPresentation = try XCTUnwrap(
            store.providerStatusPresentation(for: "rec-rejected")
        )
        let encoded = try JSONEncoder().encode([accepted, rejected])
        let text = [
            String(data: encoded, encoding: .utf8),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
            acceptedPresentation.statusLine,
            rejectedPresentation.statusLine,
            providerStatusText(acceptedPresentation),
            providerStatusText(rejectedPresentation),
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
            .lowercased()

        for fragment in sensitiveFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(fragment), fragment)
        }
    }

    private func acceptedDecision(
        id: String,
        adapterID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        membershipTier: MembershipTier,
        meteredDecisionID: String? = nil,
        transportLeaseID: String? = nil
    ) -> ServerProviderTransportAdapterPreflightDecision {
        ServerProviderTransportAdapterPreflightDecision(
            id: "\(id)-accepted",
            state: .accepted,
            statusLine: "A136 accepted preflight fixture uses value-only metadata.",
            adapterID: adapterID,
            requestID: "\(id)-request",
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            membershipTier: membershipTier,
            meteredDecisionID: meteredDecisionID,
            transportLeaseID: transportLeaseID,
            rejectionReason: nil
        )
    }

    private func rejectedDecision(
        id: String,
        adapterID: String,
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        membershipTier: MembershipTier,
        reason: ServerProviderTransportAdapterPreflightRejectionReason
    ) -> ServerProviderTransportAdapterPreflightDecision {
        ServerProviderTransportAdapterPreflightDecision(
            id: "\(id)-rejected-\(reason.rawValue)",
            state: .rejected,
            statusLine: "A136 rejected preflight fixture uses value-only metadata.",
            adapterID: adapterID,
            requestID: "\(id)-request",
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            membershipTier: membershipTier,
            meteredDecisionID: nil,
            transportLeaseID: nil,
            rejectionReason: reason
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }

    private func providerStatusText(
        _ presentation: ProviderStatusPresentation
    ) -> String {
        ([presentation.statusLine] + presentation.badges.map(\.label))
            .joined(separator: "\n")
            .lowercased()
    }

    private func sensitiveFragments() -> [String] {
        [
            "end" + "point",
            "http" + "://",
            "https" + "://",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
            "oa" + "uth",
            "url" + "session",
            "urlrequest",
            "s" + "dk",
            "raw" + "query",
            "raw" + " query",
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "source body",
            "citation url",
            "source-host",
            "store" + "kit",
            "pay" + "ment",
            "order",
            "book" + "ing",
            "hidden app",
            "crawler runtime",
            "mcp runtime",
            "maps sdk",
        ]
    }

    private func executionClaimFragments() -> [String] {
        [
            "completed",
            "complete",
            "done",
            "executed",
            "execution",
            "called provider",
            "provider call",
            "contact" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "paid",
        ]
    }
}
