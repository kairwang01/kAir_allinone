//
//  ServerProviderSearchAPICostMembershipRoutingDecisionTests.swift
//  kAirTests
//
//  A171 Search API cost and membership routing decision tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPICostMembershipRoutingDecisionTests: XCTestCase {

    func test_deciderFreezesAdvisoryRouteOutcomesAndReasons() {
        let plan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()

        assertDecision(
            input: routingInput(id: "local", costClass: .freeLocal),
            plan: plan,
            state: .accepted,
            route: .localFallback,
            reason: nil
        )
        assertDecision(
            input: routingInput(
                id: "included",
                membershipTier: .plus,
                costClass: .includedQuota,
                quotaSnapshot: includedQuota(remaining: 4)
            ),
            plan: plan,
            state: .accepted,
            route: .includedQuotaPreferred,
            reason: nil
        )
        assertDecision(
            input: routingInput(
                id: "metered",
                membershipTier: .pro,
                costClass: .meteredPremium,
                quotaSnapshot: meteredQuota()
            ),
            plan: plan,
            state: .accepted,
            route: .meteredAllowed,
            reason: nil
        )
        assertDecision(
            input: routingInput(
                id: "region-review",
                membershipTier: .plus,
                costClass: .includedQuota,
                region: .china,
                quotaSnapshot: includedQuota(remaining: 4)
            ),
            plan: plan,
            state: .rejected,
            route: .regionReview,
            reason: .regionReviewRequired
        )
        assertDecision(
            input: routingInput(
                id: "cost-blocked",
                membershipTier: .plus,
                costClass: .blockedByCost,
                quotaSnapshot: includedQuota(remaining: 4)
            ),
            plan: plan,
            state: .rejected,
            route: .costBlocked,
            reason: .costClassBlocked
        )
        assertDecision(
            input: routingInput(
                id: "privacy-blocked",
                membershipTier: .plus,
                costClass: .includedQuota,
                privacyClass: .private,
                quotaSnapshot: includedQuota(remaining: 4)
            ),
            plan: plan,
            state: .rejected,
            route: .localFallback,
            reason: .privacyBlocksRemotePosture
        )
        assertDecision(
            input: routingInput(
                id: "invalid-plan",
                membershipTier: .plus,
                costClass: .includedQuota,
                quotaSnapshot: includedQuota(remaining: 4)
            ),
            plan: misorderedPlan(),
            state: .rejected,
            route: nil,
            reason: .invalidPlan
        )
        assertDecision(
            input: routingInput(
                id: "missing-quota",
                membershipTier: .plus,
                costClass: .includedQuota,
                quotaSnapshot: includedQuota(remaining: 0)
            ),
            plan: plan,
            state: .rejected,
            route: .costBlocked,
            reason: .quotaUnavailable
        )
        assertDecision(
            input: routingInput(
                id: "missing-coverage",
                membershipTier: .plus,
                costClass: .includedQuota,
                quotaSnapshot: includedQuota(remaining: 4)
            ),
            plan: membershipCoveragePlan([.free]),
            state: .rejected,
            route: nil,
            reason: .membershipCoverageMissing
        )
        assertDecision(
            input: routingInput(
                id: "preferred-mismatch",
                membershipTier: .plus,
                costClass: .includedQuota,
                quotaSnapshot: includedQuota(remaining: 4),
                preferredRouteKind: .meteredAllowed
            ),
            plan: plan,
            state: .rejected,
            route: .includedQuotaPreferred,
            reason: .preferredRouteNotAllowed
        )
    }

    func test_decisionIsDeterministicCodableSendableAndValueOnly() throws {
        let input = routingInput(
            id: "codable",
            membershipTier: .plus,
            costClass: .includedQuota,
            quotaSnapshot: includedQuota(remaining: 6)
        )
        let plan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        let decision = ServerProviderSearchAPICostMembershipRoutingDecider.decide(
            input: input,
            plan: plan
        )
        let repeated = ServerProviderSearchAPICostMembershipRoutingDecider.decide(
            input: input,
            plan: plan
        )

        assertSendable(input)
        assertSendable(decision)
        assertSendable(decision.safeCopy)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(decision.safeCopy, repeated.safeCopy)
        XCTAssertTrue(decision.isAccepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertEqual(decision.selectedRouteKind, .includedQuotaPreferred)
        XCTAssertEqual(decision.selectedRouteRank, 2)
        XCTAssertEqual(decision.safeCopy.selectedRouteKind, .includedQuotaPreferred)
        XCTAssertEqual(decision.safeCopy.selectedRouteRank, 2)
        XCTAssertEqual(decision.safeCopy.membershipTier, .plus)
        XCTAssertEqual(decision.safeCopy.requestedCostClass, .includedQuota)
        XCTAssertEqual(decision.safeCopy.region, .northAmerica)
        XCTAssertNil(decision.safeCopy.rejectionReason)
        XCTAssertFalse(decision.safeCopy.isRuntimeCallable)

        let encodedInput = try JSONEncoder().encode(input)
        let decodedInput = try JSONDecoder().decode(
            ServerProviderSearchAPICostMembershipRoutingDecisionInput.self,
            from: encodedInput
        )
        XCTAssertEqual(decodedInput, input)

        let encodedDecision = try JSONEncoder().encode(decision)
        let decodedDecision = try JSONDecoder().decode(
            ServerProviderSearchAPICostMembershipRoutingDecision.self,
            from: encodedDecision
        )
        XCTAssertEqual(decodedDecision, decision)
        XCTAssertEqual(decodedDecision.safeCopy, decision.safeCopy)

        let encodedSafeCopy = try JSONEncoder().encode(decision.safeCopy)
        let decodedSafeCopy = try JSONDecoder().decode(
            ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy.self,
            from: encodedSafeCopy
        )
        XCTAssertEqual(decodedSafeCopy, decision.safeCopy)

        let encodedInputText = try XCTUnwrap(String(data: encodedInput, encoding: .utf8))
        let encodedDecisionText = try XCTUnwrap(String(data: encodedDecision, encoding: .utf8))
        let encodedSafeCopyText = try XCTUnwrap(String(data: encodedSafeCopy, encoding: .utf8))
        let reviewerText = [
            decision.description,
            decision.safeCopy.description,
            decision.statusLine,
            decision.selectedRouteID ?? "",
            decision.selectedRouteLabel ?? "",
            decision.selectedRouteKind?.rawValue ?? "",
            decision.rejectionReason?.rawValue ?? "",
        ]
        .joined(separator: "\n")
        let joined = [
            encodedInputText,
            encodedDecisionText,
            encodedSafeCopyText,
            reviewerText,
        ]
        .joined(separator: "\n")

        for fragment in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                joined.localizedCaseInsensitiveContains(fragment),
                "Routing decision copy leaked value-only fragment: \(fragment)"
            )
        }
    }

    func test_rejectionsPreserveSelectedAdvisoryRouteWhenAvailable() {
        let plan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        let cases: [
            (
                String,
                ServerProviderSearchAPICostMembershipRoutingDecisionInput,
                ServerProviderSearchAPICostMembershipRouteKind?,
                ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason
            )
        ] = [
            (
                "plus metered not eligible",
                routingInput(
                    id: "plus-metered",
                    membershipTier: .plus,
                    costClass: .meteredPremium,
                    quotaSnapshot: meteredQuota()
                ),
                .costBlocked,
                .membershipTierNotEligible
            ),
            (
                "metered quota missing",
                routingInput(
                    id: "metered-missing",
                    membershipTier: .pro,
                    costClass: .meteredPremium,
                    quotaSnapshot: includedQuota(remaining: 4)
                ),
                .costBlocked,
                .quotaUnavailable
            ),
            (
                "terms blocked",
                routingInput(
                    id: "terms-blocked",
                    membershipTier: .developerInternal,
                    costClass: .blockedByTerms,
                    quotaSnapshot: meteredQuota()
                ),
                .costBlocked,
                .costClassBlocked
            ),
        ]

        for (id, input, route, reason) in cases {
            let decision = ServerProviderSearchAPICostMembershipRoutingDecider.decide(
                input: input,
                plan: plan
            )

            XCTAssertEqual(decision.state, .rejected, id)
            XCTAssertFalse(decision.isAccepted, id)
            XCTAssertEqual(decision.selectedRouteKind, route, id)
            XCTAssertEqual(decision.safeCopy.selectedRouteKind, route, id)
            XCTAssertEqual(decision.rejectionReason, reason, id)
            XCTAssertEqual(decision.safeCopy.rejectionReason, reason, id)
            XCTAssertTrue(decision.statusLine.contains(reason.rawValue), id)
            XCTAssertFalse(decision.isRuntimeCallable, id)
        }
    }

    private func assertDecision(
        input: ServerProviderSearchAPICostMembershipRoutingDecisionInput,
        plan: ServerProviderSearchAPICostMembershipRoutingPlan,
        state: ServerProviderSearchAPICostMembershipRoutingDecisionState,
        route: ServerProviderSearchAPICostMembershipRouteKind?,
        reason: ServerProviderSearchAPICostMembershipRoutingDecisionRejectionReason?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let decision = ServerProviderSearchAPICostMembershipRoutingDecider.decide(
            input: input,
            plan: plan
        )

        XCTAssertEqual(decision.state, state, file: file, line: line)
        XCTAssertEqual(decision.isAccepted, state == .accepted, file: file, line: line)
        XCTAssertEqual(decision.selectedRouteKind, route, file: file, line: line)
        XCTAssertEqual(decision.safeCopy.selectedRouteKind, route, file: file, line: line)
        XCTAssertEqual(decision.rejectionReason, reason, file: file, line: line)
        XCTAssertEqual(decision.safeCopy.rejectionReason, reason, file: file, line: line)
        XCTAssertEqual(decision.membershipTier, input.membershipTier, file: file, line: line)
        XCTAssertEqual(decision.requestedCostClass, input.requestedCostClass, file: file, line: line)
        XCTAssertEqual(decision.region, input.region, file: file, line: line)
        XCTAssertEqual(decision.privacyClass, input.privacyClass, file: file, line: line)
        XCTAssertFalse(decision.isRuntimeCallable, file: file, line: line)
        XCTAssertFalse(decision.safeCopy.isRuntimeCallable, file: file, line: line)
    }

    private func routingInput(
        id: String,
        membershipTier: MembershipTier = .free,
        costClass: ProviderCostClass,
        region: ProviderRegion = .northAmerica,
        privacyClass: ProviderPrivacyClass = .general,
        quotaSnapshot: ServerProviderQuotaSnapshot = ServerProviderQuotaSnapshot(),
        preferredRouteKind: ServerProviderSearchAPICostMembershipRouteKind? = nil
    ) -> ServerProviderSearchAPICostMembershipRoutingDecisionInput {
        ServerProviderSearchAPICostMembershipRoutingDecisionInput(
            id: "a171-\(id)",
            membershipTier: membershipTier,
            requestedCostClass: costClass,
            region: region,
            privacyClass: privacyClass,
            quotaSnapshot: quotaSnapshot,
            preferredRouteKind: preferredRouteKind
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

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
        XCTAssertTrue(true, file: file, line: line)
    }
}
