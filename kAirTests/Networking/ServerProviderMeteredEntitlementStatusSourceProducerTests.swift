//
//  ServerProviderMeteredEntitlementStatusSourceProducerTests.swift
//  kAirTests
//
//  A118 server-provider metered entitlement status-source proof.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderMeteredEntitlementStatusSourceProducerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_decisionsPackageRenderedIncludedAndMeteredStatus() throws {
        let included = acceptedDecision(
            id: "a118-included",
            costClass: .includedQuota,
            estimatedUnits: 5,
            remainingUnits: 30,
            reservedUnits: 4
        )
        let metered = acceptedDecision(
            id: "a118-metered",
            costClass: .meteredPremium,
            estimatedUnits: 7,
            remainingUnits: 41,
            reservedUnits: 8
        )
        let hidden = acceptedDecision(id: "a118-hidden")
        let source = ServerProviderMeteredEntitlementStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-included", decision: included),
                    .init(recommendationID: "rec-metered", decision: metered),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-metered",
                    "rec-included",
                    "rec-included",
                ]
            )
        let baseline = ServerProviderMeteredEntitlementStatusStore(
            decisions: [
                (recommendationID: "rec-included", decision: included),
                (recommendationID: "rec-metered", decision: metered),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )

        let includedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-included")
        )
        let meteredPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-metered")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-included", "rec-metered"])
        XCTAssertEqual(
            includedPresentation,
            baseline.providerStatusPresentation(for: "rec-included")
        )
        XCTAssertEqual(
            meteredPresentation,
            baseline.providerStatusPresentation(for: "rec-metered")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(includedPresentation.cardHint, .normal)
        XCTAssertEqual(badge(.remoteProvider, in: includedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.includedQuota, in: includedPresentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: includedPresentation))
        XCTAssertEqual(badge(.liveFreshness, in: includedPresentation)?.tone, .positive)
        XCTAssertTrue(includedPresentation.statusLine.contains("budget metadata only"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Provider: searchAPI"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Vendor: a118-search-vendor"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Quota period: a118-2026-05"))
        XCTAssertTrue(includedPresentation.statusLine.contains("25 remaining"))
        XCTAssertTrue(includedPresentation.statusLine.contains("9 reserved"))
        XCTAssertTrue(includedPresentation.statusLine.contains("estimate 5 SEARCH-UNIT"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Cost: includedQuota"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Freshness: livePreferred"))
        XCTAssertTrue(includedPresentation.statusLine.contains("No transport or provider runtime has run"))

        XCTAssertEqual(meteredPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: meteredPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: meteredPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: meteredPresentation)?.tone, .positive)
        XCTAssertTrue(meteredPresentation.statusLine.contains("34 remaining"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("15 reserved"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Cost: meteredPremium"))
    }

    func test_rejectionMatrixPreservesExplicitDenialReasonOnly() throws {
        let cases: [
            (
                String,
                ServerProviderMeteredUsageDecision,
                ServerProviderMeteredUsageDenialReason,
                ProviderStatusBadgeKind
            )
        ] = [
            (
                "stale",
                rejectedDecision(
                    id: "a118-stale",
                    snapshot: entitlementSnapshot(
                        id: "a118-stale-snapshot",
                        sourceTimestamp: now.addingTimeInterval(-700),
                        staleAfter: 600
                    )
                ),
                .staleSnapshot,
                .staleCache
            ),
            (
                "over-quota",
                rejectedDecision(
                    id: "a118-over",
                    request: usageRequest(id: "a118-over", estimatedUnits: 81),
                    snapshot: entitlementSnapshot(remainingUnits: 80)
                ),
                .overQuota,
                .costBlocked
            ),
            (
                "privacy",
                rejectedDecision(
                    id: "a118-private",
                    request: usageRequest(id: "a118-private", privacyClass: .private)
                ),
                .privacyBlocked,
                .privacyBlocked
            ),
            (
                "provider-mismatch",
                rejectedDecision(
                    id: "a118-provider-mismatch",
                    snapshot: entitlementSnapshot(providerFamily: .googleMaps)
                ),
                .providerFamilyMismatch,
                .termsBlocked
            ),
        ]
        let source = ServerProviderMeteredEntitlementStatusSourceProducer()
            .statusSource(
                inputs: cases.map { entry in
                    .init(recommendationID: "rec-\(entry.0)", decision: entry.1)
                },
                renderedRecommendationIDs: cases.map { entry in "rec-\(entry.0)" }
            )

        for (id, decision, expectedReason, expectedBadgeKind) in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(id)"),
                id
            )

            XCTAssertEqual(decision.state, .rejected, id)
            XCTAssertEqual(decision.denialReason, expectedReason, id)
            XCTAssertEqual(presentation.cardHint, .disabled, id)
            XCTAssertEqual(badge(expectedBadgeKind, in: presentation)?.tone, .warning, id)
            XCTAssertNil(badge(.remoteProvider, in: presentation), id)
            XCTAssertNil(badge(.includedQuota, in: presentation), id)
            XCTAssertNil(badge(.meteredPremium, in: presentation), id)
            XCTAssertTrue(presentation.statusLine.contains("blocked by budget metadata policy"), id)
            XCTAssertTrue(presentation.statusLine.contains(expectedReason.rawValue), id)
            XCTAssertTrue(
                presentation.statusLine.contains("No transport or provider runtime has run"),
                id
            )
            XCTAssertFalse(presentation.statusLine.contains("Quota period"), id)
            XCTAssertFalse(presentation.statusLine.contains("remaining"), id)
            XCTAssertFalse(presentation.statusLine.contains("reserved"), id)
            XCTAssertFalse(presentation.statusLine.contains("Cost:"), id)
            XCTAssertFalse(presentation.statusLine.contains("Freshness:"), id)
            XCTAssertFalse(presentation.statusLine.contains("a118-search-vendor"), id)
        }
    }

    func test_duplicateIDsKeepFirstDecisionAndRenderedGuardHidesUnrenderedDecisions() throws {
        let first = acceptedDecision(
            id: "a118-first",
            costClass: .includedQuota,
            estimatedUnits: 2,
            remainingUnits: 13,
            reservedUnits: 3,
            freshness: .cachedOK
        )
        let second = acceptedDecision(
            id: "a118-second",
            costClass: .meteredPremium,
            estimatedUnits: 8,
            remainingUnits: 80,
            reservedUnits: 1
        )
        let hidden = acceptedDecision(id: "a118-hidden")
        let store = ServerProviderMeteredEntitlementStatusStore(
            decisions: [
                (recommendationID: "rec-duplicate", decision: first),
                (recommendationID: "rec-duplicate", decision: second),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )
        let source = ServerProviderRenderedRuntimeStatusSource(
            source: store,
            renderedRecommendationIDs: ["rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-duplicate", "rec-hidden"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-duplicate"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertNil(badge(.liveFreshness, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("11 remaining"))
        XCTAssertTrue(presentation.statusLine.contains("5 reserved"))
        XCTAssertTrue(presentation.statusLine.contains("estimate 2 SEARCH-UNIT"))
        XCTAssertFalse(presentation.statusLine.contains("72 remaining"))
        XCTAssertFalse(presentation.statusLine.contains("estimate 8 SEARCH-UNIT"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyDoesNotExposeSensitiveRuntimeOrUserIntentFields() throws {
        let accepted = acceptedDecision(
            id: "a118-copy",
            request: usageRequest(
                id: "a118-copy",
                traceID: "a118-copy-trace",
                userFacingReason: "public coffee near me"
            ),
            snapshot: entitlementSnapshot(id: "a118-copy-snapshot")
        )
        let rejected = rejectedDecision(
            id: "a118-copy-private",
            request: usageRequest(
                id: "a118-copy-private",
                traceID: "a118-copy-private-trace",
                privacyClass: .private,
                userFacingReason: "private appointment search"
            )
        )
        let hidden = acceptedDecision(
            id: "a118-hidden-copy",
            request: usageRequest(
                id: "a118-hidden-copy",
                vendorID: "a118-hidden-vendor"
            ),
            snapshot: entitlementSnapshot(vendorID: "a118-hidden-vendor")
        )
        let source = ServerProviderMeteredEntitlementStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", decision: accepted),
                    .init(recommendationID: "rec-blocked", decision: rejected),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let safePresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-safe")
        )
        let blockedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-blocked")
        )
        let text = [
            safePresentation.statusLine,
            blockedPresentation.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("budget metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("private appointment"))
        XCTAssertFalse(text.contains("a118-hidden-vendor"))
        XCTAssertFalse(blockedPresentation.statusLine.contains("remaining"))
        XCTAssertFalse(blockedPresentation.statusLine.contains("reserved"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected metered status wording: \(forbidden)")
        }
    }

    private func acceptedDecision(
        id: String,
        costClass: ProviderCostClass = .meteredPremium,
        estimatedUnits: Int = 8,
        remainingUnits: Int = 80,
        reservedUnits: Int = 8,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderMeteredUsageDecision {
        acceptedDecision(
            id: id,
            request: usageRequest(
                id: id,
                estimatedUnits: estimatedUnits,
                costClass: costClass,
                freshness: freshness
            ),
            snapshot: entitlementSnapshot(
                id: "\(id)-snapshot",
                costClass: costClass,
                reservedUnits: reservedUnits,
                remainingUnits: remainingUnits
            )
        )
    }

    private func acceptedDecision(
        id: String,
        request: ServerProviderMeteredUsageRequest,
        snapshot: ServerProviderMeteredEntitlementSnapshot
    ) -> ServerProviderMeteredUsageDecision {
        ServerProviderMeteredEntitlementLedger.evaluate(
            request: request,
            snapshot: snapshot,
            now: now
        )
    }

    private func rejectedDecision(
        id: String,
        request: ServerProviderMeteredUsageRequest? = nil,
        snapshot: ServerProviderMeteredEntitlementSnapshot? = nil
    ) -> ServerProviderMeteredUsageDecision {
        ServerProviderMeteredEntitlementLedger.evaluate(
            request: request ?? usageRequest(id: id),
            snapshot: snapshot ?? entitlementSnapshot(id: "\(id)-snapshot"),
            now: now
        )
    }

    private func usageRequest(
        id: String = "a118-request",
        traceID: String = "a118-trace",
        providerFamily: ProviderFamily = .searchAPI,
        vendorID: String = "a118-search-vendor",
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
        id: String = "a118-snapshot",
        providerFamily: ProviderFamily = .searchAPI,
        vendorID: String = "a118-search-vendor",
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        isVendorEnabled: Bool = true,
        membershipTier: MembershipTier = .plus,
        minimumMembershipTier: MembershipTier = .plus,
        hasEntitlement: Bool = true,
        quotaPeriodID: String = "a118-2026-05",
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

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
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
            "source body",
            "provider" + " raw",
            "hea" + "lthkit",
            "blood",
            "secret",
            "merchant",
            "order",
            "pay" + "ment",
            "book" + "ing",
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
