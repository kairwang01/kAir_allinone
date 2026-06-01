//
//  ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducerTests.swift
//  kAirTests
//
//  A178 Search API route-policy compatibility status-source tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducerTests:
    XCTestCase
{

    func test_compatibleIncludedAndMeteredDecisionsPackageRenderedStatus() throws {
        let included = decision(
            id: "included",
            membershipTier: .plus,
            vendorID: "a178-included-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota
        )
        let metered = decision(
            id: "metered",
            membershipTier: .pro,
            vendorID: "a178-metered-vendor",
            costClass: .meteredPremium,
            routeKind: .meteredAllowed,
            quotaPosture: .meteredPremium
        )
        let hidden = decision(
            id: "hidden",
            membershipTier: .plus,
            vendorID: "a178-hidden-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota
        )
        let source = ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(
                        recommendationID: "rec-included",
                        statusSourceID: "a178 included source",
                        statusSourceRank: 2,
                        decision: included
                    ),
                    .init(
                        recommendationID: "rec-metered",
                        statusSourceID: "a178 metered source",
                        statusSourceRank: 3,
                        decision: metered
                    ),
                    .init(
                        recommendationID: "rec-hidden",
                        statusSourceID: "a178 hidden source",
                        statusSourceRank: 4,
                        decision: hidden
                    ),
                ],
                renderedRecommendationIDs: ["rec-metered", "rec-included", "rec-included"]
            )

        let includedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-included")
        )
        let meteredPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-metered")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-included", "rec-metered"])
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(includedPresentation.cardHint, .normal)
        XCTAssertEqual(
            includedPresentation.badges.map(\.kind),
            [.remoteProvider, .includedQuota, .liveFreshness]
        )
        XCTAssertEqual(badge(.remoteProvider, in: includedPresentation)?.label, "Search API policy")
        XCTAssertEqual(badge(.includedQuota, in: includedPresentation)?.label, "Included quota")
        XCTAssertEqual(badge(.liveFreshness, in: includedPresentation)?.label, "Source cited")
        XCTAssertTrue(includedPresentation.statusLine.contains("advisory status only"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Route: includedQuotaPreferred"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Vendor: a178-included-vendor"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Cost: includedQuota"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Quota: includedQuota"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Source: passedCitationRequired"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Status source: a178-included-source"))
        XCTAssertTrue(includedPresentation.statusLine.contains("Rank: 2"))
        XCTAssertTrue(includedPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(includedPresentation.statusLine.contains("isExecutable false"))
        XCTAssertTrue(
            includedPresentation.statusLine.contains("No transport or provider runtime has run")
        )
        assertSafePresentation(includedPresentation, "included")

        XCTAssertEqual(meteredPresentation.cardHint, .warning)
        XCTAssertEqual(
            meteredPresentation.badges.map(\.kind),
            [.remoteProvider, .meteredPremium, .liveFreshness]
        )
        XCTAssertEqual(badge(.meteredPremium, in: meteredPresentation)?.label, "Premium metered")
        XCTAssertTrue(meteredPresentation.statusLine.contains("Route: meteredAllowed"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Vendor: a178-metered-vendor"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Cost: meteredPremium"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Quota: meteredPremium"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Status source: a178-metered-source"))
        XCTAssertTrue(meteredPresentation.statusLine.contains("Rank: 3"))
        assertSafePresentation(meteredPresentation, "metered")
    }

    func test_rejectedDecisionsPackageStableBadgeAndCardHintMappings() throws {
        let cases: [
            (
                name: String,
                reason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason,
                expectedBadge: ProviderStatusBadgeKind,
                expectedHint: ProviderStatusCardHint
            )
        ] = [
            ("routing", .routingRejected, .unavailable, .disabled),
            ("local", .localFallbackRoute, .localProvider, .disabled),
            ("metered", .meteredEntitlementRejected, .costBlocked, .disabled),
            ("vendor", .vendorPolicyRejected, .termsBlocked, .disabled),
            ("dispatch", .payloadDispatchBlocked, .termsBlocked, .disabled),
            ("authorization", .dispatchAuthorizationRejected, .termsBlocked, .disabled),
            ("lease", .leaseRejected, .unavailable, .disabled),
            ("cost", .costClassMismatch, .costBlocked, .disabled),
            ("membership", .membershipTierMismatch, .costBlocked, .disabled),
            ("source", .sourceCitationPostureMismatch, .termsBlocked, .disabled),
            ("audit", .missingAuditID, .unavailable, .disabled),
            ("stale", .staleOrHiddenSourceMarkers, .staleCache, .warning),
        ]
        let source = ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer()
            .statusSource(
                inputs: cases.map { testCase in
                    .init(
                        recommendationID: "rec-\(testCase.name)",
                        statusSourceID: "a178-\(testCase.name)",
                        statusSourceRank: 1,
                        decision: decision(
                            id: testCase.name,
                            membershipTier: .plus,
                            vendorID: "a178-\(testCase.name)-vendor",
                            costClass: .includedQuota,
                            routeKind: testCase.reason == .localFallbackRoute
                                ? .localFallback
                                : .includedQuotaPreferred,
                            quotaPosture: .includedQuota,
                            state: .rejected,
                            rejectionReason: testCase.reason
                        )
                    )
                },
                renderedRecommendationIDs: cases.map { "rec-\($0.name)" }
            )

        for testCase in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(testCase.name)"),
                testCase.name
            )

            XCTAssertEqual(presentation.cardHint, testCase.expectedHint, testCase.name)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("disabled by policy"), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains(testCase.reason.rawValue), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("Status source: a178-\(testCase.name)"))
            XCTAssertTrue(presentation.statusLine.contains("isRuntimeCallable false"), testCase.name)
            XCTAssertTrue(presentation.statusLine.contains("isExecutable false"), testCase.name)
            XCTAssertTrue(
                presentation.statusLine.contains("No transport or provider runtime has run"),
                testCase.name
            )
            assertSafePresentation(presentation, testCase.name)
        }
    }

    func test_duplicateRecommendationIDsKeepFirstVisibleInputAndHiddenMissingStayNil() throws {
        let first = decision(
            id: "first",
            membershipTier: .plus,
            vendorID: "a178-first-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota
        )
        let second = decision(
            id: "second",
            membershipTier: .pro,
            vendorID: "a178-second-vendor",
            costClass: .meteredPremium,
            routeKind: .meteredAllowed,
            quotaPosture: .meteredPremium
        )
        let hidden = decision(
            id: "hidden-input",
            membershipTier: .plus,
            vendorID: "a178-hidden-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota
        )
        let unrendered = decision(
            id: "unrendered",
            membershipTier: .plus,
            vendorID: "a178-unrendered-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota
        )
        let store = ServerProviderSearchAPIRoutePolicyCompatibilityStatusStore(
            entries: [
                .init(
                    recommendationID: "rec-duplicate",
                    statusSourceID: "first-status",
                    statusSourceRank: 1,
                    isVisible: true,
                    safeCopy: first.safeCopy
                ),
                .init(
                    recommendationID: "rec-duplicate",
                    statusSourceID: "second-status",
                    statusSourceRank: 2,
                    isVisible: true,
                    safeCopy: second.safeCopy
                ),
                .init(
                    recommendationID: "rec-hidden",
                    statusSourceID: "hidden-status",
                    statusSourceRank: 3,
                    isVisible: false,
                    safeCopy: hidden.safeCopy
                ),
                .init(
                    recommendationID: "rec-unrendered",
                    statusSourceID: "unrendered-status",
                    statusSourceRank: 4,
                    isVisible: true,
                    safeCopy: unrendered.safeCopy
                ),
            ]
        )
        let source = ServerProviderRenderedRuntimeStatusSource(
            source: store,
            renderedRecommendationIDs: ["rec-duplicate", "rec-hidden", "rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-duplicate", "rec-unrendered"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-duplicate", "rec-hidden"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertTrue(presentation.statusLine.contains("first-status"))
        XCTAssertTrue(presentation.statusLine.contains("a178-first-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("second-status"))
        XCTAssertFalse(presentation.statusLine.contains("a178-second-vendor"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-unrendered"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_statusDebugAndEncodedCopyStayValueOnlyAndNonExecutable() throws {
        let compatible = decision(
            id: "safe-compatible",
            membershipTier: .plus,
            vendorID: "a178-safe-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota
        )
        let rejected = decision(
            id: "safe-rejected",
            membershipTier: .plus,
            vendorID: "a178-safe-rejected-vendor",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota,
            state: .rejected,
            rejectionReason: .vendorPolicyRejected
        )
        let source = ServerProviderSearchAPIRoutePolicyCompatibilityStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-compatible", decision: compatible),
                    .init(recommendationID: "rec-rejected", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-compatible", "rec-rejected"]
            )
        let compatiblePresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-compatible")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )
        let text = [
            try encodedString(compatible.safeCopy),
            try encodedString(rejected.safeCopy),
            compatible.description,
            rejected.description,
            compatiblePresentation.statusLine,
            rejectedPresentation.statusLine,
            compatiblePresentation.badges.map(\.label).joined(separator: " "),
            rejectedPresentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertFalse(compatible.isRuntimeCallable)
        XCTAssertFalse(compatible.isExecutable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        XCTAssertFalse(rejected.isExecutable)
        XCTAssertFalse(compatible.safeCopy.isRuntimeCallable)
        XCTAssertFalse(compatible.safeCopy.isExecutable)
        XCTAssertFalse(rejected.safeCopy.isRuntimeCallable)
        XCTAssertFalse(rejected.safeCopy.isExecutable)
        XCTAssertTrue(text.contains("advisory"))
        XCTAssertTrue(text.contains("disabled by policy"))
        XCTAssertTrue(text.contains("isruntimecallable false"))
        XCTAssertTrue(text.contains("isexecutable false"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        for forbidden in sensitiveRuntimeFragments() + completionClaimFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected route-policy compatibility status-source wording: \(forbidden)"
            )
        }
    }

    private func decision(
        id: String,
        membershipTier: MembershipTier,
        vendorID: String,
        costClass: ProviderCostClass,
        routeKind: ServerProviderSearchAPICostMembershipRouteKind,
        quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture,
        state: ServerProviderSearchAPIRoutePolicyCompatibilityState = .compatible,
        rejectionReason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason? = nil
    ) -> ServerProviderSearchAPIRoutePolicyCompatibilityDecision {
        let safeCopy = ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy(
            id: "a178-\(id)-safe-copy",
            inputID: "a178-\(id)-input",
            renderedRecommendationID: "a178-\(id)-rendered",
            routingDecisionID: "a178-\(id)-routing",
            meteredDecisionID: "a178-\(id)-metered",
            vendorPolicyDecisionID: "a178-\(id)-vendor-policy",
            payloadDispatchReceiptID: "a178-\(id)-dispatch",
            dispatchAuthorizationID: "a178-\(id)-authorization",
            transportLeaseID: "a178-\(id)-lease",
            selectedStatusSourceID: "a178-\(id)-selected-source",
            selectedStatusSourceRank: 1,
            membershipTier: membershipTier,
            providerFamily: .searchAPI,
            vendorID: vendorID,
            capability: .webSearch,
            costClass: costClass,
            routeKind: routeKind,
            quotaPosture: quotaPosture,
            sourceCitationPosture: .passedCitationRequired,
            state: state,
            rejectionReason: rejectionReason,
            isRuntimeCallable: false,
            isExecutable: false
        )
        return ServerProviderSearchAPIRoutePolicyCompatibilityDecision(
            id: "a178-\(id)-decision",
            inputID: "a178-\(id)-input",
            state: state,
            statusLine: "A178 fixture is value-only metadata.",
            rejectionReason: rejectionReason,
            safeCopy: safeCopy
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
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
        for forbidden in sensitiveRuntimeFragments() + completionClaimFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected route-policy compatibility presentation wording in \(context): \(forbidden)",
                file: file,
                line: line
            )
        }
    }

    private func sensitiveRuntimeFragments() -> [String] {
        [
            "http" + "://",
            "https" + "://",
            "end" + "point",
            "api" + " key",
            "api" + "_" + "key",
            "oa" + "uth",
            "bear" + "er",
            "tok" + "en",
            "cred" + "ential",
            "url" + "session",
            "url" + "request",
            "sdk" + "/client",
            "raw" + " query",
            "raw" + " page",
            "raw" + " provider",
            "crawler" + " runtime",
            "mcp" + " runtime",
            "maps" + " sdk",
            "store" + "kit",
            "pay" + "ment",
            "ord" + "er",
            "book" + "ing",
            "hidden app" + "-control",
            "real" + " provider",
            "concrete" + " vendor",
        ]
    }

    private func completionClaimFragments() -> [String] {
        [
            "provider" + " call",
            "execution" + " claim",
            "completion" + " claim",
            "exec" + "uted",
            "exec" + "ution completed",
            "provider" + " called",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "paid",
            "done",
            "success",
        ]
    }
}
