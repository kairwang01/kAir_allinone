//
//  ServerProviderServiceCutPlanStatusSourceProducerTests.swift
//  kAirTests
//
//  A183 status projection tests for A182 service cut-plan decisions.
//

import XCTest
@testable import kAir

final class ServerProviderServiceCutPlanStatusSourceProducerTests: XCTestCase {
    func test_cutPlanDecisionsPackageStableRenderedStatusCopy() throws {
        let fixtures = serviceCutPlanFixtures()
        let source = ServerProviderServiceCutPlanStatusSourceProducer()
            .statusSource(
                inputs: fixtures.map { fixture in
                    .init(
                        recommendationID: fixture.id,
                        statusSourceID: "a183-\(fixture.id)-source",
                        statusSourceRank: fixture.rank,
                        decision: fixture.decision
                    )
                },
                renderedRecommendationIDs: fixtures.map(\.id)
            )

        for fixture in fixtures {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: fixture.id),
                fixture.id
            )
            let statusText = providerStatusText(presentation)

            XCTAssertEqual(presentation.recommendationID, fixture.id)
            XCTAssertEqual(presentation.cardHint, fixture.expectedCardHint, fixture.id)
            XCTAssertTrue(
                presentation.badges.contains { $0.kind == fixture.expectedPrimaryBadge },
                fixture.id
            )
            XCTAssertTrue(statusText.contains(fixture.expectedState), fixture.id)
            XCTAssertTrue(statusText.contains(fixture.expectedLane), fixture.id)
            XCTAssertTrue(statusText.contains(text("intent", fixture.decision.serviceIntent.rawValue)))
            XCTAssertTrue(statusText.contains(text("provider", fixture.decision.providerFamily.rawValue)))
            XCTAssertTrue(statusText.contains(text("capability", fixture.decision.capability.rawValue)))
            XCTAssertTrue(statusText.contains(text("membership", fixture.decision.membershipTier.rawValue)))
            XCTAssertTrue(statusText.contains(text("region", fixture.decision.region.rawValue)))
            XCTAssertTrue(statusText.contains(text("privacy", fixture.decision.privacyClass.rawValue)))
            XCTAssertTrue(statusText.contains(text("cost", fixture.decision.costClass.rawValue)))
            XCTAssertTrue(statusText.contains("a183-\(fixture.id)-source"))
            XCTAssertTrue(statusText.contains("rank: \(fixture.rank)"))
            XCTAssertTrue(statusText.contains("isruntimecallable false"))
            XCTAssertTrue(statusText.contains("isexecutable false"))
        }
    }

    func test_duplicateHiddenMissingAndRenderedIDScoping() throws {
        let localID = "a183-local-visible"
        let hiddenID = "a183-hidden"
        let unrenderedID = "a183-unrendered"
        let missingID = "a183-missing"
        let localDecision = localDecision()
        let lowerDecision = searchDecision()
        let source = ServerProviderServiceCutPlanStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: localID,
                        statusSourceID: "a183-first-visible-source",
                        statusSourceRank: 1,
                        decision: localDecision
                    ),
                    .init(
                        recommendationID: localID,
                        statusSourceID: "a183-lower-duplicate-source",
                        statusSourceRank: 99,
                        decision: lowerDecision
                    ),
                    .init(
                        recommendationID: hiddenID,
                        statusSourceID: "a183-hidden-source",
                        statusSourceRank: 2,
                        isVisible: false,
                        decision: searchDecision()
                    ),
                    .init(
                        recommendationID: unrenderedID,
                        statusSourceID: "a183-unrendered-source",
                        statusSourceRank: 3,
                        decision: mcpDecision()
                    ),
                ],
                renderedRecommendationIDs: [localID, hiddenID]
            )
        let visible = try XCTUnwrap(source.providerStatusPresentation(for: localID))
        let visibleText = providerStatusText(visible)

        XCTAssertEqual(visible.cardHint, .normal)
        XCTAssertTrue(visibleText.contains("a183-first-visible-source"))
        XCTAssertTrue(visibleText.contains("localapplemaps"))
        XCTAssertFalse(visibleText.contains("a183-lower-duplicate-source"))
        XCTAssertFalse(visibleText.contains("serversearchapi"))
        XCTAssertNil(source.providerStatusPresentation(for: hiddenID))
        XCTAssertNil(source.providerStatusPresentation(for: unrenderedID))
        XCTAssertNil(source.providerStatusPresentation(for: missingID))
    }

    func test_cardHintAndBadgeMappingsAreStableByState() throws {
        let local = try presentation(for: localDecision())
        let search = try presentation(for: searchDecision())
        let privacy = try presentation(for: privacyBlockedDecision())
        let unsupported = try presentation(for: unsupportedDecision())

        XCTAssertEqual(local.cardHint, .normal)
        XCTAssertTrue(local.badges.contains { $0.kind == .localProvider })
        XCTAssertTrue(local.badges.contains { $0.kind == .freeLocal })
        XCTAssertEqual(search.cardHint, .warning)
        XCTAssertTrue(search.badges.contains { $0.kind == .remoteProvider })
        XCTAssertTrue(search.badges.contains { $0.kind == .meteredPremium })
        XCTAssertTrue(search.badges.contains { $0.kind == .termsBlocked })
        XCTAssertEqual(privacy.cardHint, .disabled)
        XCTAssertTrue(privacy.badges.contains { $0.kind == .privacyBlocked })
        XCTAssertEqual(unsupported.cardHint, .disabled)
        XCTAssertTrue(unsupported.badges.contains { $0.kind == .unavailable })
    }

    func test_statusCopyCarriesGatesReasonsAndDoesNotLeakLowerPriorityMarkers() throws {
        let recommendationID = "a183-gated"
        let privacyDecision = privacyBlockedDecision()
        let mcpDecision = mcpDecision()
        let source = ServerProviderServiceCutPlanStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: recommendationID,
                        statusSourceID: "a183-privacy-source",
                        statusSourceRank: 7,
                        decision: privacyDecision
                    ),
                    .init(
                        recommendationID: recommendationID,
                        statusSourceID: "a183-mcp-lower-source",
                        statusSourceRank: 8,
                        decision: mcpDecision
                    ),
                ],
                renderedRecommendationIDs: [recommendationID]
            )
        let presentation = try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))
        let statusText = providerStatusText(presentation)

        XCTAssertTrue(statusText.contains("required gates: privatedatalocalonly"))
        XCTAssertTrue(statusText.contains("block reasons: privacyblocked"))
        XCTAssertTrue(statusText.contains("a183-privacy-source"))
        XCTAssertFalse(statusText.contains("a183-mcp-lower-source"))
        XCTAssertFalse(statusText.contains("reservedmcp"))
        XCTAssertFalse(statusText.contains("mcpdescriptorverification"))
    }

    func test_statusAndDecisionCopyStayValueOnlyAndFreeOfRuntimeFragments() throws {
        let fixtures = serviceCutPlanFixtures()
        let decisions = fixtures.map(\.decision)
        let source = ServerProviderServiceCutPlanStatusSourceProducer()
            .statusSource(
                inputs: fixtures.map { fixture in
                    .init(
                        recommendationID: fixture.id,
                        statusSourceID: "a183-\(fixture.id)-source",
                        statusSourceRank: fixture.rank,
                        decision: fixture.decision
                    )
                },
                renderedRecommendationIDs: fixtures.map(\.id)
            )
        let presentations = try fixtures.map { fixture in
            try XCTUnwrap(source.providerStatusPresentation(for: fixture.id))
        }
        let encodedDecisions = try JSONEncoder().encode(decisions)
        let inspected = (
            String(data: encodedDecisions, encoding: .utf8)!
                + "\n"
                + presentations.map(providerStatusText).joined(separator: "\n")
                + "\n"
                + String(describing: presentations)
        )

        for decision in decisions {
            XCTAssertFalse(decision.isRuntimeCallable)
            XCTAssertFalse(decision.isExecutable)
        }
        for forbidden in serviceCutPlanStatusForbiddenFragments() {
            XCTAssertFalse(inspected.localizedCaseInsensitiveContains(forbidden), forbidden)
        }
    }

    private struct Fixture {
        let id: String
        let rank: Int
        let decision: ServerProviderServiceCutPlanDecision
        let expectedState: String
        let expectedLane: String
        let expectedCardHint: ProviderStatusCardHint
        let expectedPrimaryBadge: ProviderStatusBadgeKind
    }

    private func serviceCutPlanFixtures() -> [Fixture] {
        [
            Fixture(
                id: "local",
                rank: 1,
                decision: localDecision(),
                expectedState: "state: localready",
                expectedLane: "lane: localapplemaps",
                expectedCardHint: .normal,
                expectedPrimaryBadge: .localProvider
            ),
            Fixture(
                id: "google",
                rank: 2,
                decision: googleDecision(),
                expectedState: "state: serverreserved",
                expectedLane: "lane: servergooglemaps",
                expectedCardHint: .warning,
                expectedPrimaryBadge: .remoteProvider
            ),
            Fixture(
                id: "gaode",
                rank: 3,
                decision: gaodeDecision(),
                expectedState: "state: serverreserved",
                expectedLane: "lane: servergaode",
                expectedCardHint: .warning,
                expectedPrimaryBadge: .remoteProvider
            ),
            Fixture(
                id: "search",
                rank: 4,
                decision: searchDecision(),
                expectedState: "state: serverreserved",
                expectedLane: "lane: serversearchapi",
                expectedCardHint: .warning,
                expectedPrimaryBadge: .remoteProvider
            ),
            Fixture(
                id: "crawler",
                rank: 5,
                decision: crawlerDecision(),
                expectedState: "state: serverreserved",
                expectedLane: "lane: reservedcrawler",
                expectedCardHint: .warning,
                expectedPrimaryBadge: .remoteProvider
            ),
            Fixture(
                id: "mcp",
                rank: 6,
                decision: mcpDecision(),
                expectedState: "state: serverreserved",
                expectedLane: "lane: reservedmcp",
                expectedCardHint: .warning,
                expectedPrimaryBadge: .remoteProvider
            ),
            Fixture(
                id: "privacy",
                rank: 7,
                decision: privacyBlockedDecision(),
                expectedState: "state: blocked",
                expectedLane: "lane: serversearchapi",
                expectedCardHint: .disabled,
                expectedPrimaryBadge: .privacyBlocked
            ),
            Fixture(
                id: "unsupported",
                rank: 8,
                decision: unsupportedDecision(),
                expectedState: "state: unsupported",
                expectedLane: "lane: none",
                expectedCardHint: .disabled,
                expectedPrimaryBadge: .unavailable
            ),
        ]
    }

    private func presentation(
        for decision: ServerProviderServiceCutPlanDecision
    ) throws -> ProviderStatusPresentation {
        let source = ServerProviderServiceCutPlanStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: "one",
                        statusSourceID: "a183-one-source",
                        decision: decision
                    ),
                ],
                renderedRecommendationIDs: ["one"]
            )
        return try XCTUnwrap(source.providerStatusPresentation(for: "one"))
    }

    private func localDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapRoute,
                providerFamily: .appleLocal,
                capability: .routePlanning,
                membershipTier: .free,
                region: .northAmerica,
                privacyClass: .health,
                costClass: .freeLocal,
                privateDataPosture: .privateOrHealthLocalOnly
            )
        )
    }

    private func googleDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapSearch,
                providerFamily: .googleMaps,
                capability: .placeSearch,
                membershipTier: .pro,
                region: .northAmerica,
                costClass: .meteredPremium,
                quotaPosture: .meteredEligible,
                attributionCacheDisplayPolicy: .represented,
                serverSecretPosture: .serverOwned
            )
        )
    }

    private func gaodeDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapRoute,
                providerFamily: .gaode,
                capability: .routePlanning,
                membershipTier: .plus,
                region: .china,
                costClass: .includedQuota,
                quotaPosture: .includedQuotaAvailable,
                attributionCacheDisplayPolicy: .represented,
                serverSecretPosture: .serverOwned
            )
        )
    }

    private func searchDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(searchAPIInput())
    }

    private func crawlerDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(crawlerInput())
    }

    private func mcpDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(mcpInput())
    }

    private func privacyBlockedDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(searchAPIInput(privacyClass: .health))
    }

    private func unsupportedDecision() -> ServerProviderServiceCutPlanDecision {
        ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .publicInfoSearch,
                providerFamily: .appleLocal,
                capability: .webSearch,
                membershipTier: .free,
                costClass: .freeLocal
            )
        )
    }

    private func searchAPIInput(
        privacyClass: ProviderPrivacyClass = .general
    ) -> ServerProviderServiceCutPlanInput {
        ServerProviderServiceCutPlanInput(
            serviceIntent: .publicInfoSearch,
            providerFamily: .searchAPI,
            capability: .webSearch,
            membershipTier: .pro,
            region: .northAmerica,
            privacyClass: privacyClass,
            costClass: .meteredPremium,
            quotaPosture: .meteredEligible,
            sourceCitationRequirement: .requiredAndRepresented,
            rawContentPolicy: .redactedOrDisabled,
            serverSecretPosture: .serverOwned,
            rateRetentionPosture: .represented
        )
    }

    private func crawlerInput() -> ServerProviderServiceCutPlanInput {
        ServerProviderServiceCutPlanInput(
            serviceIntent: .publicSourceCrawlCandidate,
            providerFamily: .crawler,
            capability: .crawlerFetch,
            membershipTier: .pro,
            region: .northAmerica,
            costClass: .meteredPremium,
            quotaPosture: .meteredEligible,
            sourceCitationRequirement: .requiredAndRepresented,
            rawContentPolicy: .redactedOrDisabled,
            serverSecretPosture: .serverOwned,
            robotsState: .allowed,
            rateRetentionPosture: .represented,
            sandboxAuditPosture: .represented,
            experimentalEnablementPosture: .enabled
        )
    }

    private func mcpInput() -> ServerProviderServiceCutPlanInput {
        ServerProviderServiceCutPlanInput(
            serviceIntent: .mcpToolCandidate,
            providerFamily: .mcp,
            capability: .mcpTool,
            membershipTier: .developerInternal,
            region: .global,
            costClass: .includedQuota,
            quotaPosture: .includedQuotaAvailable,
            descriptorTrustPosture: .verified,
            confirmationRequirement: .requiredSatisfied,
            serverSecretPosture: .serverOwned,
            sandboxAuditPosture: .represented,
            experimentalEnablementPosture: .enabled,
            mcpAuthorizationPosture: .represented,
            tokenProtectionPosture: .represented
        )
    }

    private func providerStatusText(
        _ presentation: ProviderStatusPresentation
    ) -> String {
        ([presentation.statusLine] + presentation.badges.map(\.label))
            .joined(separator: "\n")
            .lowercased()
    }

    private func text(_ label: String, _ value: String) -> String {
        "\(label): \(value)".lowercased()
    }

    private func serviceCutPlanStatusForbiddenFragments() -> [String] {
        [
            "end" + "point",
            "api" + " key",
            "oa" + "uth",
            "bear" + "er",
            "creden" + "tial",
            "url" + "session",
            "url" + "request",
            "s" + "dk/client",
            "raw" + " query",
            "raw" + " page",
            "raw" + " provider",
            "crawler " + "runtime",
            "mcp " + "runtime",
            "maps " + "sdk",
            "store" + "kit",
            "pay" + "ment",
            "book" + "ing",
            "provider " + "call",
            "execution " + "claim",
            "completion " + "claim",
            "real " + "provider",
            "concrete " + "vendor",
        ]
    }
}
