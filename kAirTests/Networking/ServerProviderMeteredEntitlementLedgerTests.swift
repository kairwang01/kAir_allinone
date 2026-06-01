//
//  ServerProviderMeteredEntitlementLedgerTests.swift
//  kAirTests
//
//  A117 server-provider metered entitlement ledger proof.
//

import XCTest
@testable import kAir

final class ServerProviderMeteredEntitlementLedgerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_includedQuotaDecisionReservesUnitsAndBuildsQuotaSnapshot() throws {
        let request = usageRequest(
            id: "a117-included",
            estimatedUnits: 5,
            costClass: .includedQuota,
            membershipTier: .plus
        )
        let snapshot = entitlementSnapshot(
            id: "a117-included-snapshot",
            costClass: .includedQuota,
            membershipTier: .plus,
            minimumMembershipTier: .plus,
            includedUnits: 40,
            usedUnits: 10,
            reservedUnits: 5,
            remainingUnits: 25
        )

        let decision = ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: snapshot,
            now: now
        )
        let repeated = ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: snapshot,
            now: now
        )

        assertSendable(decision)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertTrue(decision.isAccepted)
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertNil(decision.denialReason)
        XCTAssertEqual(decision.requestID, "a117-included")
        XCTAssertEqual(decision.snapshotID, "a117-included-snapshot")
        XCTAssertEqual(decision.quotaPeriodID, "a117-2026-05")
        XCTAssertEqual(decision.providerFamily, .searchAPI)
        XCTAssertEqual(decision.vendorID, "a117-search-vendor")
        XCTAssertEqual(decision.capability, .webSearch)
        XCTAssertEqual(decision.costClass, .includedQuota)
        XCTAssertEqual(decision.estimatedUnits, 5)
        XCTAssertEqual(decision.remainingUnitsBefore, 25)
        XCTAssertEqual(decision.remainingUnitsAfter, 20)
        XCTAssertEqual(decision.reservedUnitsAfter, 10)
        XCTAssertEqual(decision.currencyCode, "USD")
        XCTAssertEqual(decision.unitLabel, "SEARCH-UNIT")
        XCTAssertTrue(decision.statusLine.contains("budget metadata only"))
        XCTAssertTrue(decision.statusLine.contains("No transport or provider runtime has run"))

        let quota = try XCTUnwrap(decision.quotaSnapshotForProvider())
        XCTAssertEqual(quota.allowedProviderFamilies, [.searchAPI])
        XCTAssertEqual(quota.entitledProviderFamilies, [.searchAPI])
        XCTAssertEqual(quota.remainingIncludedQuota[.searchAPI], 20)
        XCTAssertTrue(quota.meteredEligibleProviderFamilies.isEmpty)

        let budgetContext = try XCTUnwrap(
            decision.transportBudgetContext(id: "a117-included-budget")
        )
        XCTAssertEqual(budgetContext.id, "a117-included-budget")
        XCTAssertEqual(budgetContext.allowedCostClasses, [.includedQuota])
        XCTAssertEqual(budgetContext.quotaSnapshot.remainingIncludedQuota[.searchAPI], 20)
    }

    func test_meteredDecisionPreservesServerVerifiedBudgetState() throws {
        let request = usageRequest(
            id: "a117-metered",
            estimatedUnits: 7,
            costClass: .meteredPremium,
            membershipTier: .pro
        )
        let snapshot = entitlementSnapshot(
            id: "a117-metered-snapshot",
            costClass: .meteredPremium,
            membershipTier: .pro,
            minimumMembershipTier: .plus,
            includedUnits: 100,
            usedUnits: 13,
            reservedUnits: 11,
            remainingUnits: 76
        )

        let decision = ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: snapshot,
            now: now
        )

        XCTAssertTrue(decision.isAccepted)
        XCTAssertEqual(decision.costClass, .meteredPremium)
        XCTAssertEqual(decision.remainingUnitsBefore, 76)
        XCTAssertEqual(decision.remainingUnitsAfter, 69)
        XCTAssertEqual(decision.reservedUnitsAfter, 18)
        XCTAssertEqual(decision.audit.membershipTier, .pro)
        XCTAssertEqual(decision.audit.estimatedUnits, 7)
        XCTAssertEqual(decision.audit.remainingUnitsAfter, 69)

        let quota = try XCTUnwrap(decision.quotaSnapshotForProvider())
        XCTAssertEqual(quota.allowedProviderFamilies, [.searchAPI])
        XCTAssertEqual(quota.entitledProviderFamilies, [.searchAPI])
        XCTAssertEqual(quota.meteredEligibleProviderFamilies, [.searchAPI])
        XCTAssertTrue(quota.remainingIncludedQuota.isEmpty)

        let budgetContext = try XCTUnwrap(decision.transportBudgetContext())
        XCTAssertEqual(budgetContext.allowedCostClasses, [.meteredPremium])
        XCTAssertEqual(budgetContext.quotaSnapshot.meteredEligibleProviderFamilies, [.searchAPI])
    }

    func test_rejectionMatrixPreservesExplicitBudgetReasons() {
        let baseRequest = usageRequest(id: "a117-matrix")
        let baseSnapshot = entitlementSnapshot(id: "a117-matrix-snapshot")
        let oldSnapshot = entitlementSnapshot(
            id: "a117-old-snapshot",
            sourceTimestamp: now.addingTimeInterval(-700),
            staleAfter: 600
        )

        let cases: [
            (
                String,
                ServerProviderMeteredUsageRequest,
                ServerProviderMeteredEntitlementSnapshot?,
                ServerProviderMeteredUsageDenialReason
            )
        ] = [
            (
                "missing snapshot",
                baseRequest,
                nil,
                .missingSnapshot
            ),
            (
                "disabled vendor",
                baseRequest,
                entitlementSnapshot(isVendorEnabled: false),
                .vendorDisabled
            ),
            (
                "provider mismatch",
                baseRequest,
                entitlementSnapshot(providerFamily: .googleMaps),
                .providerFamilyMismatch
            ),
            (
                "vendor mismatch",
                usageRequest(vendorID: "other-search-vendor"),
                baseSnapshot,
                .vendorMismatch
            ),
            (
                "capability mismatch",
                baseRequest,
                entitlementSnapshot(capability: .localServiceSearch),
                .capabilityMismatch
            ),
            (
                "private context",
                usageRequest(privacyClass: .private),
                baseSnapshot,
                .privacyBlocked
            ),
            (
                "health context",
                usageRequest(privacyClass: .health),
                baseSnapshot,
                .healthContextBlocked
            ),
            (
                "membership missing",
                usageRequest(membershipTier: .plus),
                entitlementSnapshot(membershipTier: .plus, minimumMembershipTier: .pro),
                .membershipMissing
            ),
            (
                "entitlement missing",
                baseRequest,
                entitlementSnapshot(hasEntitlement: false),
                .entitlementMissing
            ),
            (
                "unsupported cost class",
                usageRequest(costClass: .freeLocal),
                entitlementSnapshot(costClass: .freeLocal),
                .unsupportedCostClass
            ),
            (
                "currency mismatch",
                usageRequest(currencyCode: "cad"),
                baseSnapshot,
                .currencyMismatch
            ),
            (
                "unit mismatch",
                usageRequest(unitLabel: "map-unit"),
                baseSnapshot,
                .unitMismatch
            ),
            (
                "stale snapshot",
                baseRequest,
                oldSnapshot,
                .staleSnapshot
            ),
            (
                "already reserved",
                baseRequest,
                entitlementSnapshot(reservedRequestIDs: ["a117-matrix"]),
                .alreadyReservedBudget
            ),
            (
                "over quota",
                usageRequest(estimatedUnits: 81),
                entitlementSnapshot(remainingUnits: 80),
                .overQuota
            ),
            (
                "zero estimate",
                usageRequest(estimatedUnits: 0),
                baseSnapshot,
                .overQuota
            ),
        ]

        for (id, request, snapshot, expected) in cases {
            let decision = ServerProviderMeteredEntitlementLedger.evaluate(
                request: request,
                snapshot: snapshot,
                now: now
            )

            XCTAssertFalse(decision.isAccepted, id)
            XCTAssertEqual(decision.state, .rejected, id)
            XCTAssertEqual(decision.denialReason, expected, id)
            XCTAssertEqual(decision.audit.denialReason, expected, id)
            XCTAssertNil(decision.providerFamily, id)
            XCTAssertNil(decision.capability, id)
            XCTAssertNil(decision.costClass, id)
            XCTAssertNil(decision.freshness, id)
            XCTAssertNil(decision.remainingUnitsAfter, id)
            XCTAssertNil(decision.reservedUnitsAfter, id)
            XCTAssertNil(decision.quotaSnapshotForProvider(), id)
            XCTAssertNil(decision.transportBudgetContext(), id)
            XCTAssertTrue(decision.statusLine.contains(expected.rawValue), id)
            XCTAssertTrue(
                decision.statusLine.contains("No transport or provider runtime has run"),
                id
            )
        }
    }

    func test_encodingAndDebugCopyDoNotExposeSensitiveRuntimeFields() throws {
        let request = usageRequest(
            id: "a117-copy",
            traceID: "a117-copy-trace",
            userFacingReason: "public coffee near me"
        )
        let snapshot = entitlementSnapshot(id: "a117-copy-snapshot")
        let accepted = ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: snapshot,
            now: now
        )
        let rejected = ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: nil,
            now: now
        )
        let text = [
            try encodedString(accepted),
            try encodedString(rejected),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("budget metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected ledger wording: \(forbidden)")
        }
    }

    private func usageRequest(
        id: String = "a117-request",
        traceID: String = "a117-trace",
        providerFamily: ProviderFamily = .searchAPI,
        vendorID: String = "a117-search-vendor",
        capability: ProviderCapability = .webSearch,
        estimatedUnits: Int = 8,
        costClass: ProviderCostClass = .meteredPremium,
        privacyClass: ProviderPrivacyClass = .general,
        freshness: ProviderFreshness = .livePreferred,
        membershipTier: MembershipTier = .plus,
        currencyCode: String = "usd",
        unitLabel: String = "search-unit",
        userFacingReason: String = "public-info lookup"
    ) -> ServerProviderMeteredUsageRequest {
        ServerProviderMeteredUsageRequest(
            id: id,
            traceID: traceID,
            providerFamily: providerFamily,
            vendorID: vendorID,
            capability: capability,
            estimatedUnits: estimatedUnits,
            costClass: costClass,
            privacyClass: privacyClass,
            freshness: freshness,
            membershipTier: membershipTier,
            currencyCode: currencyCode,
            unitLabel: unitLabel,
            userFacingReason: userFacingReason
        )
    }

    private func entitlementSnapshot(
        id: String = "a117-snapshot",
        providerFamily: ProviderFamily = .searchAPI,
        vendorID: String = "a117-search-vendor",
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        isVendorEnabled: Bool = true,
        membershipTier: MembershipTier = .plus,
        minimumMembershipTier: MembershipTier = .plus,
        hasEntitlement: Bool = true,
        quotaPeriodID: String = "a117-2026-05",
        includedUnits: Int = 100,
        usedUnits: Int = 12,
        reservedUnits: Int = 8,
        remainingUnits: Int = 80,
        currencyCode: String = "usd",
        unitLabel: String = "search-unit",
        sourceTimestamp: Date? = nil,
        staleAfter: TimeInterval = 600,
        reservedRequestIDs: Set<String> = []
    ) -> ServerProviderMeteredEntitlementSnapshot {
        ServerProviderMeteredEntitlementSnapshot(
            id: id,
            providerFamily: providerFamily,
            vendorID: vendorID,
            capability: capability,
            costClass: costClass,
            isVendorEnabled: isVendorEnabled,
            membershipTier: membershipTier,
            minimumMembershipTier: minimumMembershipTier,
            hasEntitlement: hasEntitlement,
            quotaPeriodID: quotaPeriodID,
            includedUnits: includedUnits,
            usedUnits: usedUnits,
            reservedUnits: reservedUnits,
            remainingUnits: remainingUnits,
            currencyCode: currencyCode,
            unitLabel: unitLabel,
            sourceTimestamp: sourceTimestamp ?? now,
            staleAfter: staleAfter,
            reservedRequestIDs: reservedRequestIDs
        )
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(
            String(data: JSONEncoder().encode(value), encoding: .utf8)
        )
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
    }

    private func sensitiveRuntimeFragments() -> [String] {
        [
            "end" + "point",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "oa" + "uth",
            "s" + "dk",
            "raw" + "prompt",
            "raw prompt",
            "raw" + " query",
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "provider" + " raw",
            "source body",
            "secret",
            "merchant",
            "pay" + "ment",
            "order",
        ]
    }

    private func executionClaimFragments() -> [String] {
        [
            "completed",
            "contact" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "ordered",
            "paid",
        ]
    }
}
