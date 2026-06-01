//
//  ServerProviderSearchAPIVendorPolicyStatusSourceProducerTests.swift
//  kAirTests
//
//  A106 Search API vendor policy status-source producer guard tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPIVendorPolicyStatusSourceProducerTests: XCTestCase {

    func test_decisionsPackageRenderedAcceptedAndBlockedStatus() throws {
        let accepted = acceptedDecision(id: "balanced-vendor")
        let blocked = rejectedDecision(
            id: "private-vendor",
            context: vendorContext(privacyClass: .private),
            vendor: vendorPolicy(id: "private-vendor")
        )
        let hidden = acceptedDecision(id: "hidden-vendor")
        let source = ServerProviderSearchAPIVendorPolicyStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-accepted", decision: accepted),
                    .init(recommendationID: "rec-blocked", decision: blocked),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-blocked",
                    "rec-accepted",
                    "rec-accepted",
                ]
            )
        let baseline = SearchAPIVendorPolicyProviderStatusStore(
            decisions: [
                (recommendationID: "rec-accepted", decision: accepted),
                (recommendationID: "rec-blocked", decision: blocked),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )

        let acceptedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-accepted")
        )
        let blockedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-blocked")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-accepted", "rec-blocked"])
        XCTAssertEqual(
            acceptedPresentation,
            baseline.providerStatusPresentation(for: "rec-accepted")
        )
        XCTAssertEqual(
            blockedPresentation,
            baseline.providerStatusPresentation(for: "rec-blocked")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(accepted.state, .accepted)
        XCTAssertEqual(acceptedPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: acceptedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: acceptedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: acceptedPresentation)?.tone, .positive)
        XCTAssertTrue(acceptedPresentation.statusLine.contains("accepted from approved metadata only"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("balanced-vendor"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("webSearch"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("meteredPremium"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("livePreferred"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("organicLinks"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("No provider runtime has run"))

        XCTAssertEqual(blocked.state, .rejected)
        XCTAssertEqual(blocked.rejection, .privacyBlocked)
        XCTAssertEqual(blockedPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: blockedPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: blockedPresentation))
        XCTAssertNil(badge(.meteredPremium, in: blockedPresentation))
        XCTAssertTrue(blockedPresentation.statusLine.contains("blocked by metadata policy"))
        XCTAssertTrue(blockedPresentation.statusLine.contains("privacyBlocked"))
        XCTAssertTrue(blockedPresentation.statusLine.contains("private-vendor"))
        XCTAssertTrue(blockedPresentation.statusLine.contains("No provider runtime has run"))
    }

    func test_rejectionMatrixMapsToStableProviderStatusCopy() throws {
        let cases: [(String, ServerProviderSearchAPIVendorPolicyDecision, ServerProviderSearchAPIVendorPolicyRejectionReason, ProviderStatusBadgeKind)] = [
            (
                "disabled-vendor",
                rejectedDecision(vendor: vendorPolicy(id: "disabled-vendor", isEnabled: false)),
                .vendorDisabled,
                .termsBlocked
            ),
            (
                "entitlement",
                rejectedDecision(
                    context: vendorContext(
                        quotaSnapshot: ServerProviderQuotaSnapshot(
                            allowedProviderFamilies: [.searchAPI],
                            meteredEligibleProviderFamilies: [.searchAPI]
                        )
                    )
                ),
                .entitlementMissing,
                .costBlocked
            ),
            (
                "quota",
                rejectedDecision(
                    context: vendorContext(
                        costClass: .includedQuota,
                        quotaSnapshot: includedQuota(remaining: 0)
                    ),
                    vendor: vendorPolicy(costClass: .includedQuota)
                ),
                .includedQuotaExhausted,
                .costBlocked
            ),
            (
                "privacy",
                rejectedDecision(context: vendorContext(privacyClass: .health)),
                .privacyBlocked,
                .privacyBlocked
            ),
            (
                "freshness",
                rejectedDecision(
                    context: vendorContext(freshness: .liveRequired),
                    vendor: vendorPolicy(supportedFreshness: [.cachedOK])
                ),
                .unsupportedFreshness,
                .staleCache
            ),
            (
                "citation",
                rejectedDecision(
                    vendor: vendorPolicy(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: false,
                            supportsSourceHost: true,
                            supportsAttribution: true
                        )
                    )
                ),
                .citationSupportMissing,
                .termsBlocked
            ),
            (
                "source",
                rejectedDecision(
                    vendor: vendorPolicy(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: true,
                            supportsSourceHost: false,
                            supportsAttribution: true
                        )
                    )
                ),
                .sourceSupportMissing,
                .termsBlocked
            ),
            (
                "page-body",
                rejectedDecision(
                    context: vendorContext(pageBodyRequirement: .snippetsOnly),
                    vendor: vendorPolicy(pageBodyMode: .required)
                ),
                .pageBodyNotAllowed,
                .termsBlocked
            ),
            (
                "retention",
                rejectedDecision(
                    context: vendorContext(allowedRetention: .ephemeralOnly),
                    vendor: vendorPolicy(requiredRetention: .shortTermCache)
                ),
                .retentionConflict,
                .termsBlocked
            ),
            (
                "result-shape",
                rejectedDecision(
                    context: vendorContext(resultShape: .localBusiness),
                    vendor: vendorPolicy(supportedResultShapes: [.organicLinks])
                ),
                .unsupportedResultShape,
                .termsBlocked
            ),
        ]

        let source = ServerProviderSearchAPIVendorPolicyStatusSourceProducer()
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
            XCTAssertEqual(decision.rejection, expectedReason, id)
            XCTAssertEqual(presentation.cardHint, .disabled, id)
            XCTAssertNotNil(badge(expectedBadgeKind, in: presentation), id)
            XCTAssertNil(badge(.remoteProvider, in: presentation), id)
            XCTAssertTrue(presentation.statusLine.contains("blocked by metadata policy"), id)
            XCTAssertTrue(presentation.statusLine.contains(expectedReason.rawValue), id)
            XCTAssertTrue(presentation.statusLine.contains("No provider runtime has run"), id)
        }
    }

    func test_duplicateIDsKeepFirstAndRenderedGuardHidesUnrenderedDecisions() throws {
        let first = acceptedDecision(
            id: "first-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            quotaSnapshot: includedQuota(remaining: 2)
        )
        let second = rejectedDecision(
            id: "second-vendor",
            context: vendorContext(privacyClass: .private),
            vendor: vendorPolicy(id: "second-vendor")
        )
        let hidden = acceptedDecision(id: "hidden-vendor")
        let store = SearchAPIVendorPolicyProviderStatusStore(
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
        XCTAssertTrue(presentation.statusLine.contains("first-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("second-vendor"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyAndDecisionDebugTextDoNotLeakSensitiveRuntimeFields() throws {
        let accepted = acceptedDecision(id: "safe-vendor")
        let rejected = rejectedDecision(
            id: "blocked-vendor",
            context: vendorContext(pageBodyRequirement: .required),
            vendor: vendorPolicy(id: "blocked-vendor", pageBodyMode: .unavailable)
        )
        let source = ServerProviderSearchAPIVendorPolicyStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", decision: accepted),
                    .init(recommendationID: "rec-blocked", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let safePresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-safe"))
        let blockedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-blocked"))
        let text = [
            try encodedString(accepted),
            try encodedString(rejected),
            accepted.description,
            rejected.description,
            safePresentation.statusLine,
            blockedPresentation.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        XCTAssertFalse(text.contains("hidden-vendor"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status-source wording: \(forbidden)")
        }
    }

    private func acceptedDecision(
        id: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        quotaSnapshot: ServerProviderQuotaSnapshot? = nil
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        ServerProviderSearchAPIVendorPolicy.evaluate(
            context: vendorContext(
                costClass: costClass,
                freshness: freshness,
                quotaSnapshot: quotaSnapshot ?? meteredQuota()
            ),
            vendor: vendorPolicy(
                id: id,
                costClass: costClass,
                supportedFreshness: [.cachedOK, .livePreferred, .liveRequired]
            )
        )
    }

    private func rejectedDecision(
        id: String = "blocked-vendor",
        context: ServerProviderSearchAPIVendorPolicyContext? = nil,
        vendor: ServerProviderSearchAPIVendorPolicyDescriptor? = nil
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        ServerProviderSearchAPIVendorPolicy.evaluate(
            context: context ?? vendorContext(),
            vendor: vendor ?? vendorPolicy(id: id)
        )
    }

    private func vendorContext(
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        quotaSnapshot: ServerProviderQuotaSnapshot? = nil
    ) -> ServerProviderSearchAPIVendorPolicyContext {
        ServerProviderSearchAPIVendorPolicyContext(
            providerFamily: providerFamily,
            capability: capability,
            privacyClass: privacyClass,
            costClass: costClass,
            freshness: freshness,
            citationRequired: citationRequired,
            sourceHostRequired: sourceHostRequired,
            pageBodyRequirement: pageBodyRequirement,
            allowedRetention: allowedRetention,
            resultShape: resultShape,
            quotaSnapshot: quotaSnapshot ?? meteredQuota()
        )
    }

    private func vendorPolicy(
        id: String = "test-vendor",
        isEnabled: Bool = true,
        costClass: ProviderCostClass = .meteredPremium,
        supportedFreshness: Set<ProviderFreshness> = [.cachedOK, .livePreferred, .liveRequired],
        citationSupport: ServerProviderSearchAPIVendorCitationSupport? = nil,
        pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        requiredRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
            .documentSnippets,
        ]
    ) -> ServerProviderSearchAPIVendorPolicyDescriptor {
        ServerProviderSearchAPIVendorPolicyDescriptor(
            id: id,
            isEnabled: isEnabled,
            costClass: costClass,
            supportedFreshness: supportedFreshness,
            citationSupport: citationSupport ?? ServerProviderSearchAPIVendorCitationSupport(
                supportsCitations: true,
                supportsSourceHost: true,
                supportsAttribution: true
            ),
            pageBodyMode: pageBodyMode,
            requiredRetention: requiredRetention,
            supportedResultShapes: supportedResultShapes
        )
    }

    private func meteredQuota() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
    }

    private func includedQuota(
        remaining: Int
    ) -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            remainingIncludedQuota: [.searchAPI: remaining]
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
        try XCTUnwrap(
            String(data: JSONEncoder().encode(value), encoding: .utf8)
        )
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
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "healthkit",
            "blood",
            "secret",
            "merchant",
            "order",
            "pay" + "ment",
            "book" + "ing",
            "provider" + " raw",
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
