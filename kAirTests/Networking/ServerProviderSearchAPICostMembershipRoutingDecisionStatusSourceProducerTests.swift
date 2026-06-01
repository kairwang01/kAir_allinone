//
//  ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducerTests.swift
//  kAirTests
//
//  A172 Search API cost and membership routing-decision status-source tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducerTests:
    XCTestCase
{

    func test_acceptedDecisionsPackageStableAdvisoryStatus() throws {
        let local = decision(id: "local", costClass: .freeLocal)
        let included = decision(
            id: "included",
            membershipTier: .plus,
            costClass: .includedQuota,
            quotaSnapshot: includedQuota(remaining: 4)
        )
        let metered = decision(
            id: "metered",
            membershipTier: .pro,
            costClass: .meteredPremium,
            quotaSnapshot: meteredQuota()
        )
        let hidden = decision(id: "hidden", costClass: .freeLocal)
        let source = ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: "rec-local",
                        statusSourceID: "routing local",
                        statusSourceRank: 1,
                        decision: local
                    ),
                    .init(
                        recommendationID: "rec-included",
                        statusSourceID: "routing included",
                        statusSourceRank: 2,
                        decision: included
                    ),
                    .init(
                        recommendationID: "rec-metered",
                        statusSourceID: "routing metered",
                        statusSourceRank: 3,
                        decision: metered
                    ),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-metered",
                    "rec-local",
                    "rec-included",
                    "rec-included",
                ]
            )

        let localPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-local")
        )
        let includedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-included")
        )
        let meteredPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-metered")
        )

        XCTAssertEqual(
            source.renderedRecommendationIDs,
            ["rec-included", "rec-local", "rec-metered"]
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(localPresentation.cardHint, .normal)
        XCTAssertEqual(localPresentation.badges.map(\.kind), [.localProvider, .freeLocal])
        XCTAssertTrue(localPresentation.statusLine.contains("advisory status only"))
        XCTAssertTrue(localPresentation.statusLine.contains("Route: localFallback, rank 1"))
        XCTAssertTrue(localPresentation.statusLine.contains("Membership: free"))
        XCTAssertTrue(localPresentation.statusLine.contains("Cost: freeLocal"))
        XCTAssertTrue(localPresentation.statusLine.contains("Status source: routing-local"))
        XCTAssertTrue(localPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(localPresentation.statusLine.contains("No transport or provider runtime has run"))
        assertSafePresentation(localPresentation, "local")

        XCTAssertEqual(includedPresentation.cardHint, .normal)
        XCTAssertEqual(includedPresentation.badges.map(\.kind), [.remoteProvider, .includedQuota])
        XCTAssertTrue(includedPresentation.statusLine.contains("Route: includedQuotaPreferred, rank 2"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Membership: plus"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Cost: includedQuota"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Region: northAmerica"))
        assertSafePresentation(includedPresentation, "included")

        XCTAssertEqual(meteredPresentation.cardHint, .warning)
        XCTAssertEqual(meteredPresentation.badges.map(\.kind), [.remoteProvider, .meteredPremium])
        XCTAssertTrue(meteredPresentation.statusLine.contains("Route: meteredAllowed, rank 3"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Membership: pro"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Cost: meteredPremium"))
        assertSafePresentation(meteredPresentation, "metered")
    }

    func test_rejectedDecisionsPackageReviewOrDisabledStatusWithReasons() throws {
        let plan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        let cases: [
            (
                id: String,
                decision: ServerProviderSearchAPICostMembershipRoutingDecision,
                expectedRoute: ServerProviderSearchAPICostMembershipRouteKind?,
                expectedReason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason,
                expectedHint: ProviderStatusCardHint,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            (
                "region",
                decision(
                    id: "region",
                    membershipTier: .plus,
                    costClass: .includedQuota,
                    region: .china,
                    quotaSnapshot: includedQuota(remaining: 4)
                ),
                .regionReview,
                .regionReviewRequired,
                .warning,
                .termsBlocked
            ),
            (
                "cost",
                decision(
                    id: "cost",
                    membershipTier: .plus,
                    costClass: .blockedByCost,
                    quotaSnapshot: includedQuota(remaining: 4)
                ),
                .costBlocked,
                .costClassBlocked,
                .disabled,
                .costBlocked
            ),
            (
                "privacy",
                decision(
                    id: "privacy",
                    membershipTier: .plus,
                    costClass: .includedQuota,
                    privacyClass: .private,
                    quotaSnapshot: includedQuota(remaining: 4)
                ),
                .localFallback,
                .privacyBlocksRemotePosture,
                .disabled,
                .privacyBlocked
            ),
            (
                "invalid",
                decision(
                    id: "invalid",
                    membershipTier: .plus,
                    costClass: .includedQuota,
                    quotaSnapshot: includedQuota(remaining: 4),
                    plan: misorderedPlan()
                ),
                nil,
                .invalidPlan,
                .disabled,
                .unavailable
            ),
            (
                "quota",
                decision(
                    id: "quota",
                    membershipTier: .plus,
                    costClass: .includedQuota,
                    quotaSnapshot: includedQuota(remaining: 0)
                ),
                .costBlocked,
                .quotaUnavailable,
                .disabled,
                .costBlocked
            ),
            (
                "coverage",
                decision(
                    id: "coverage",
                    membershipTier: .plus,
                    costClass: .includedQuota,
                    quotaSnapshot: includedQuota(remaining: 4),
                    plan: membershipCoveragePlan([.free])
                ),
                nil,
                .membershipCoverageMissing,
                .disabled,
                .unavailable
            ),
            (
                "preferred",
                decision(
                    id: "preferred",
                    membershipTier: .plus,
                    costClass: .includedQuota,
                    quotaSnapshot: includedQuota(remaining: 4),
                    preferredRouteKind: .meteredAllowed
                ),
                .includedQuotaPreferred,
                .preferredRouteNotAllowed,
                .disabled,
                .termsBlocked
            ),
            (
                "tier",
                decision(
                    id: "tier",
                    membershipTier: .plus,
                    costClass: .meteredPremium,
                    quotaSnapshot: meteredQuota()
                ),
                .costBlocked,
                .membershipTierNotEligible,
                .disabled,
                .costBlocked
            ),
        ]
        let source = ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer()
            .statusSource(
                inputs: cases.map { testCase in
                    .init(
                        recommendationID: "rec-\(testCase.id)",
                        statusSourceID: "routing-\(testCase.id)",
                        statusSourceRank: testCase.decision.selectedRouteRank ?? 0,
                        decision: testCase.decision
                    )
                },
                renderedRecommendationIDs: cases.map { "rec-\($0.id)" }
            )

        XCTAssertEqual(plan.validation.isAccepted, true)
        for testCase in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(testCase.id)"),
                testCase.id
            )

            XCTAssertEqual(testCase.decision.state, .rejected, testCase.id)
            XCTAssertEqual(testCase.decision.selectedRouteKind, testCase.expectedRoute, testCase.id)
            XCTAssertEqual(testCase.decision.rejectionReason, testCase.expectedReason, testCase.id)
            XCTAssertEqual(presentation.cardHint, testCase.expectedHint, testCase.id)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.id)
            XCTAssertTrue(presentation.statusLine.contains("review-only status"), testCase.id)
            XCTAssertTrue(presentation.statusLine.contains(testCase.expectedReason.rawValue), testCase.id)
            XCTAssertTrue(
                presentation.statusLine.contains(
                    "Route: \(testCase.expectedRoute?.rawValue ?? "none")"
                ),
                testCase.id
            )
            XCTAssertTrue(presentation.statusLine.contains("isRuntimeCallable false"), testCase.id)
            XCTAssertTrue(
                presentation.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
            assertSafePresentation(presentation, testCase.id)
        }
    }

    func test_duplicateRecommendationIDsKeepFirstInputAndHiddenMissingStayNil() throws {
        let first = decision(
            id: "first",
            membershipTier: .plus,
            costClass: .includedQuota,
            quotaSnapshot: includedQuota(remaining: 7)
        )
        let second = decision(
            id: "second",
            membershipTier: .pro,
            costClass: .meteredPremium,
            quotaSnapshot: meteredQuota()
        )
        let invisible = decision(id: "invisible", costClass: .freeLocal)
        let hidden = decision(id: "hidden", costClass: .freeLocal)
        let store = ServerProviderSearchAPICostMembershipRoutingDecisionStatusStore(
            entries: [
                .init(
                    recommendationID: "rec-duplicate",
                    statusSourceID: "first-status",
                    statusSourceRank: 4,
                    isVisible: true,
                    safeCopy: first.safeCopy
                ),
                .init(
                    recommendationID: "rec-duplicate",
                    statusSourceID: "second-status",
                    statusSourceRank: 9,
                    isVisible: true,
                    safeCopy: second.safeCopy
                ),
                .init(
                    recommendationID: "rec-invisible",
                    statusSourceID: "invisible-status",
                    statusSourceRank: 1,
                    isVisible: false,
                    safeCopy: invisible.safeCopy
                ),
                .init(
                    recommendationID: "rec-hidden",
                    statusSourceID: "hidden-status",
                    statusSourceRank: 1,
                    isVisible: true,
                    safeCopy: hidden.safeCopy
                ),
            ]
        )
        let source = ServerProviderRenderedRuntimeStatusSource(
            source: store,
            renderedRecommendationIDs: ["rec-duplicate", "rec-duplicate", "rec-invisible"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-duplicate", "rec-hidden"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-duplicate", "rec-invisible"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(presentation.badges.map(\.kind), [.remoteProvider, .includedQuota])
        XCTAssertTrue(presentation.statusLine.contains("first-status"))
        XCTAssertTrue(presentation.statusLine.contains("includedQuotaPreferred"))
        XCTAssertFalse(presentation.statusLine.contains("second-status"))
        XCTAssertFalse(presentation.statusLine.contains("meteredAllowed"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-invisible"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_statusCopyAndDebugTextStayValueOnlyAndNotRuntimeCallable() throws {
        let accepted = decision(
            id: "safe",
            membershipTier: .plus,
            costClass: .includedQuota,
            quotaSnapshot: includedQuota(remaining: 4)
        )
        let rejected = decision(
            id: "safe-private",
            membershipTier: .plus,
            costClass: .includedQuota,
            privacyClass: .private,
            quotaSnapshot: includedQuota(remaining: 4)
        )
        let source = ServerProviderSearchAPICostMembershipRoutingDecisionStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", decision: accepted),
                    .init(recommendationID: "rec-blocked", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let acceptedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-safe")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-blocked")
        )
        let text = [
            try encodedString(accepted.safeCopy),
            try encodedString(rejected.safeCopy),
            accepted.description,
            rejected.description,
            acceptedPresentation.statusLine,
            rejectedPresentation.statusLine,
            acceptedPresentation.badges.map(\.label).joined(separator: " "),
            rejectedPresentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertFalse(accepted.isRuntimeCallable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        XCTAssertFalse(accepted.safeCopy.isRuntimeCallable)
        XCTAssertFalse(rejected.safeCopy.isRuntimeCallable)
        XCTAssertTrue(text.contains("advisory"))
        XCTAssertTrue(text.contains("review-only"))
        XCTAssertTrue(text.contains("isruntimecallable false"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        for forbidden in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected routing status-source wording: \(forbidden)"
            )
        }
    }

    private func decision(
        id: String,
        membershipTier: MembershipTier = .free,
        costClass: ProviderCostClass,
        region: ProviderRegion = .northAmerica,
        privacyClass: ProviderPrivacyClass = .general,
        quotaSnapshot: ServerProviderQuotaSnapshot? = nil,
        preferredRouteKind: ServerProviderSearchAPICostMembershipRouteKind? = nil,
        plan: ServerProviderSearchAPICostMembershipRoutingPlan = .defaultPlan()
    ) -> ServerProviderSearchAPICostMembershipRoutingDecision {
        ServerProviderSearchAPICostMembershipRoutingDecider.decide(
            input: ServerProviderSearchAPICostMembershipRoutingDecisionInput(
                id: "a172-\(id)",
                membershipTier: membershipTier,
                requestedCostClass: costClass,
                region: region,
                privacyClass: privacyClass,
                quotaSnapshot: quotaSnapshot ?? ServerProviderQuotaSnapshot(),
                preferredRouteKind: preferredRouteKind
            ),
            plan: plan
        )
    }

    private func includedQuota(
        remaining: Int
    ) -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            remainingIncludedQuota: [.searchAPI: remaining],
            meteredEligibleProviderFamilies: [],
            disabledProviderFamilies: [],
            enabledExperimentalProviderFamilies: []
        )
    }

    private func meteredQuota() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            remainingIncludedQuota: [:],
            meteredEligibleProviderFamilies: [.searchAPI],
            disabledProviderFamilies: [],
            enabledExperimentalProviderFamilies: []
        )
    }

    private func misorderedPlan() -> ServerProviderSearchAPICostMembershipRoutingPlan {
        let defaultPlan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        var routes = defaultPlan.routes
        routes.swapAt(0, 1)
        return ServerProviderSearchAPICostMembershipRoutingPlan(
            routes: routes,
            statusStackExtensionSlots: defaultPlan.statusStackExtensionSlots,
            extensionNotes: defaultPlan.extensionNotes
        )
    }

    private func membershipCoveragePlan(
        _ eligibleMembershipTiers: [MembershipTier]
    ) -> ServerProviderSearchAPICostMembershipRoutingPlan {
        let defaultPlan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        let routes = defaultPlan.routes.map { route in
            replacementRoute(
                from: route,
                eligibleMembershipTiers: eligibleMembershipTiers
            )
        }
        return ServerProviderSearchAPICostMembershipRoutingPlan(
            routes: routes,
            statusStackExtensionSlots: defaultPlan.statusStackExtensionSlots,
            extensionNotes: defaultPlan.extensionNotes
        )
    }

    private func replacementRoute(
        from route: ServerProviderSearchAPICostMembershipRoute,
        eligibleMembershipTiers: [MembershipTier]
    ) -> ServerProviderSearchAPICostMembershipRoute {
        ServerProviderSearchAPICostMembershipRoute(
            kind: route.kind,
            id: route.id,
            rank: route.rank,
            minimumMembershipTier: route.minimumMembershipTier,
            eligibleMembershipTiers: eligibleMembershipTiers,
            quotaPosture: route.quotaPosture,
            costPosture: route.costPosture,
            costClasses: route.costClasses,
            region: route.region,
            regionPosture: route.regionPosture,
            uiLabel: route.uiLabel,
            reviewerNote: route.reviewerNote
        )
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    private func assertSafePresentation(
        _ presentation: ProviderStatusPresentation,
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = [
            presentation.statusLine,
            presentation.badges.map(\.label).joined(separator: " "),
            presentation.badges.map(\.systemImage).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()
        for forbidden in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected routing status presentation wording in \(context): \(forbidden)",
                file: file,
                line: line
            )
        }
    }

    private func forbiddenLiveMaterialFragments() -> [String] {
        [
            "http" + "://",
            "https" + "://",
            "end" + "point",
            "api" + "Key",
            "api" + " key",
            "O" + "Auth",
            "bear" + "er",
            "tok" + "en",
            "URL" + "Session",
            "URL" + "Request",
            "S" + "DK",
            "cred" + "ential",
            "client" + "Handle",
            "raw" + "Query",
            "raw" + "Page",
            "provider" + "Payload",
            "crawl" + "er",
            "M" + "CP",
            "Ga" + "ode",
            "Goo" + "gle",
            "Store" + "Kit",
            "pay" + "ment",
            "ord" + "er",
            "book" + "ing",
            "hidden app" + "-control",
            "provider" + " call",
            "exec" + "ution",
            "exec" + "ute",
            "com" + "pleted",
            "comple" + "tion",
            "succ" + "ess",
            "do" + "ne",
            "call" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "pa" + "id",
        ]
    }
}
