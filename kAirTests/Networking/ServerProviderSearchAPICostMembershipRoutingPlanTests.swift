//
//  ServerProviderSearchAPICostMembershipRoutingPlanTests.swift
//  kAirTests
//
//  A170 Search API cost and membership routing plan tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPICostMembershipRoutingPlanTests: XCTestCase {

    func test_defaultPlanFreezesRouteOrderLabelsAndStackSlots() {
        let plan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        let expectedKinds: [ServerProviderSearchAPICostMembershipRouteKind] = [
            .localFallback,
            .includedQuotaPreferred,
            .meteredAllowed,
            .regionReview,
            .costBlocked,
        ]
        let expectedRouteIDs = [
            "search-api-cost-route-local-fallback",
            "search-api-cost-route-included-quota-preferred",
            "search-api-cost-route-metered-allowed",
            "search-api-cost-route-region-review",
            "search-api-cost-route-cost-blocked",
        ]

        assertSendable(plan)
        assertSendable(plan.safeCopy)
        XCTAssertEqual(plan.id, "a170-search-api-cost-membership-routing-plan")
        XCTAssertNil(plan.runtimeEntryPointName)
        XCTAssertFalse(plan.isRuntimeCallable)
        XCTAssertEqual(plan.routes.map(\.kind), expectedKinds)
        XCTAssertEqual(plan.routes.map(\.id), expectedRouteIDs)
        XCTAssertEqual(plan.routes.map(\.rank), Array(1...expectedKinds.count))
        XCTAssertEqual(
            plan.routes.map(\.minimumMembershipTier),
            [.free, .plus, .pro, .plus, .free]
        )
        XCTAssertEqual(
            plan.routes.map(\.eligibleMembershipTiers),
            [
                MembershipTier.allCases,
                [.plus, .pro, .developerInternal],
                [.pro, .developerInternal],
                [.plus, .pro, .developerInternal],
                MembershipTier.allCases,
            ]
        )
        XCTAssertEqual(
            plan.routes.map(\.quotaPosture),
            [.notRequired, .includedAvailable, .meteredEligible, .reviewRequired, .unavailable]
        )
        XCTAssertEqual(
            plan.routes.map(\.costPosture),
            [.localOnly, .includedQuota, .metered, .reviewRequired, .blocked]
        )
        XCTAssertEqual(
            plan.routes.map(\.costClasses),
            [
                [.freeLocal],
                [.includedQuota],
                [.meteredPremium],
                [.includedQuota, .meteredPremium],
                [.blockedByCost],
            ]
        )
        XCTAssertEqual(
            plan.routes.map(\.regionPosture),
            [.localOnly, .globalAllowed, .globalAllowed, .regionReviewRequired, .globalAllowed]
        )
        XCTAssertEqual(
            plan.routes.map(\.uiLabel),
            [
                "Local fallback",
                "Included quota preferred",
                "Metered allowed",
                "Region review",
                "Cost blocked",
            ]
        )
        XCTAssertEqual(plan.coveredMembershipTiers, MembershipTier.allCases)
        XCTAssertEqual(plan.validation.state, .accepted)
        XCTAssertTrue(plan.validation.isAccepted)
        XCTAssertEqual(plan.validation.reasons, [])
        XCTAssertEqual(plan.safeCopy.routeIDs, expectedRouteIDs)
        XCTAssertEqual(plan.safeCopy.routeRanks, Array(1...expectedKinds.count))
        XCTAssertEqual(plan.safeCopy.routeKinds, expectedKinds)
        XCTAssertEqual(plan.safeCopy.coveredMembershipTiers, MembershipTier.allCases)
        XCTAssertFalse(plan.safeCopy.isRuntimeCallable)
        XCTAssertEqual(plan.safeCopy.validationState, .accepted)
        XCTAssertEqual(plan.safeCopy.validationReasons, [])
        XCTAssertEqual(
            plan.safeCopy.statusStackExtensionSlotIDs,
            ServerProviderSearchAPIProviderStatusStackExtensionSlot.defaultSlots.map(\.slotID)
        )
        XCTAssertEqual(
            plan.safeCopy.extensionNoteIDs,
            [
                "search-api-routing-note-server-owned-vendor-selection",
                "search-api-routing-note-membership-package-mapping",
                "search-api-routing-note-budget-fallback-review",
            ]
        )
    }

    func test_validationRejectsDuplicateMisorderedMissingAndUnsupportedRoutes() {
        let defaultRoutes = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan().routes

        var duplicateID = defaultRoutes
        duplicateID[1] = replacementRoute(
            from: duplicateID[1],
            id: duplicateID[0].id
        )
        let duplicateIDResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: duplicateID
        )
        XCTAssertEqual(duplicateIDResult.state, .rejected)
        XCTAssertTrue(duplicateIDResult.reasons.contains(.duplicateRouteID))

        var duplicateKind = defaultRoutes
        duplicateKind[1] = replacementRoute(
            from: duplicateKind[1],
            kind: .localFallback,
            id: "search-api-cost-route-local-fallback-shadow"
        )
        let duplicateKindResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: duplicateKind
        )
        XCTAssertEqual(duplicateKindResult.state, .rejected)
        XCTAssertTrue(duplicateKindResult.reasons.contains(.duplicateRouteKind))
        XCTAssertTrue(duplicateKindResult.reasons.contains(.routeOrderMismatch))
        XCTAssertTrue(duplicateKindResult.reasons.contains(.routeRankMismatch))

        var duplicateRank = defaultRoutes
        duplicateRank[1] = replacementRoute(
            from: duplicateRank[1],
            rank: duplicateRank[0].rank
        )
        let duplicateRankResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: duplicateRank
        )
        XCTAssertEqual(duplicateRankResult.state, .rejected)
        XCTAssertTrue(duplicateRankResult.reasons.contains(.duplicateRank))
        XCTAssertTrue(duplicateRankResult.reasons.contains(.nonContiguousRanks))
        XCTAssertTrue(duplicateRankResult.reasons.contains(.routeRankMismatch))

        var fallbackSecond = defaultRoutes
        fallbackSecond.swapAt(0, 1)
        let fallbackSecondResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: fallbackSecond
        )
        XCTAssertEqual(fallbackSecondResult.state, .rejected)
        XCTAssertTrue(fallbackSecondResult.reasons.contains(.localFallbackNotFirst))
        XCTAssertTrue(fallbackSecondResult.reasons.contains(.routeOrderMismatch))
        XCTAssertTrue(fallbackSecondResult.reasons.contains(.nonContiguousRanks))

        let missingCoverage = defaultRoutes.map {
            replacementRoute(from: $0, eligibleMembershipTiers: [.free])
        }
        let missingCoverageResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: missingCoverage
        )
        XCTAssertEqual(missingCoverageResult.state, .rejected)
        XCTAssertTrue(missingCoverageResult.reasons.contains(.missingMembershipCoverage))

        var unsupported = defaultRoutes
        unsupported[0] = replacementRoute(
            from: unsupported[0],
            kind: .unsupportedRoute,
            id: "search-api-cost-route-unsupported"
        )
        let unsupportedResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: unsupported
        )
        XCTAssertEqual(unsupportedResult.state, .rejected)
        XCTAssertTrue(unsupportedResult.reasons.contains(.unsupportedRouteKind))
        XCTAssertTrue(unsupportedResult.reasons.contains(.localFallbackNotFirst))
        XCTAssertTrue(unsupportedResult.reasons.contains(.routeOrderMismatch))
        XCTAssertTrue(unsupportedResult.reasons.contains(.routeRankMismatch))

        let missingSlotResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: defaultRoutes,
            statusStackExtensionSlots: [.costBasedProviderSelection]
        )
        XCTAssertEqual(missingSlotResult.state, .rejected)
        XCTAssertTrue(missingSlotResult.reasons.contains(.missingStatusStackExtensionSlot))

        let duplicateSlotResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(
            routes: defaultRoutes,
            statusStackExtensionSlots: [
                .costBasedProviderSelection,
                .costBasedProviderSelection,
            ]
        )
        XCTAssertEqual(duplicateSlotResult.state, .rejected)
        XCTAssertTrue(duplicateSlotResult.reasons.contains(.duplicateStatusStackExtensionSlot))
        XCTAssertTrue(duplicateSlotResult.reasons.contains(.missingStatusStackExtensionSlot))

        let emptyResult = ServerProviderSearchAPICostMembershipRoutingPlan.validate(routes: [])
        XCTAssertEqual(emptyResult.state, .rejected)
        XCTAssertTrue(emptyResult.reasons.contains(.emptyRoutes))
        XCTAssertTrue(emptyResult.reasons.contains(.localFallbackNotFirst))
        XCTAssertTrue(emptyResult.reasons.contains(.missingMembershipCoverage))
    }

    func test_planCopyIsCodableDeterministicAndValueOnly() throws {
        let plan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()
        let repeatedPlan = ServerProviderSearchAPICostMembershipRoutingPlan.defaultPlan()

        XCTAssertEqual(plan, repeatedPlan)
        XCTAssertEqual(plan.safeCopy, repeatedPlan.safeCopy)

        let encodedPlan = try JSONEncoder().encode(plan)
        let decodedPlan = try JSONDecoder().decode(
            ServerProviderSearchAPICostMembershipRoutingPlan.self,
            from: encodedPlan
        )
        XCTAssertEqual(decodedPlan, plan)
        XCTAssertEqual(decodedPlan.safeCopy, plan.safeCopy)

        let encodedSafeCopy = try JSONEncoder().encode(plan.safeCopy)
        let decodedSafeCopy = try JSONDecoder().decode(
            ServerProviderSearchAPICostMembershipRoutingPlanSafeCopy.self,
            from: encodedSafeCopy
        )
        XCTAssertEqual(decodedSafeCopy, plan.safeCopy)

        let encodedPlanText = try XCTUnwrap(String(data: encodedPlan, encoding: .utf8))
        let encodedSafeCopyText = try XCTUnwrap(String(data: encodedSafeCopy, encoding: .utf8))
        let reviewerText = (
            [
                plan.description,
                plan.safeCopy.description,
            ]
            + plan.routes.flatMap { route in
                [
                    route.id,
                    route.uiLabel,
                    route.reviewerNote,
                    route.quotaPosture.rawValue,
                    route.costPosture.rawValue,
                    route.regionPosture.rawValue,
                ]
            }
            + plan.extensionNotes.flatMap { note in
                [
                    note.id,
                    note.reviewerNote,
                ]
            }
        )
        .joined(separator: "\n")
        let joined = [encodedPlanText, encodedSafeCopyText, reviewerText]
            .joined(separator: "\n")

        for fragment in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                joined.localizedCaseInsensitiveContains(fragment),
                "Routing plan copy leaked value-only fragment: \(fragment)"
            )
        }
    }

    private func replacementRoute(
        from route: ServerProviderSearchAPICostMembershipRoute,
        kind replacementKind: ServerProviderSearchAPICostMembershipRouteKind? = nil,
        id replacementID: String? = nil,
        rank replacementRank: Int? = nil,
        eligibleMembershipTiers replacementEligibleTiers: [MembershipTier]? = nil
    ) -> ServerProviderSearchAPICostMembershipRoute {
        ServerProviderSearchAPICostMembershipRoute(
            kind: replacementKind ?? route.kind,
            id: replacementID ?? route.id,
            rank: replacementRank ?? route.rank,
            minimumMembershipTier: route.minimumMembershipTier,
            eligibleMembershipTiers: replacementEligibleTiers ?? route.eligibleMembershipTiers,
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
