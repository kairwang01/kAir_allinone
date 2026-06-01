//
//  ServerProviderSearchAPILiveVendorSelectionStatusSourceProducerTests.swift
//  kAirTests
//
//  A151 Search API live vendor selection status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPILiveVendorSelectionStatusSourceProducerTests: XCTestCase {

    func test_selectedAndRejectedDecisionsPackageRenderedStatus() throws {
        let selected = selectedDecision(id: "balanced-search")
        let rejected = rejectedDecision(
            request: selectionRequest(privacyClass: .private),
            candidates: [candidate(id: "blocked-search")]
        )
        let source = ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-selected", decision: selected),
                    .init(recommendationID: "rec-rejected", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-rejected", "rec-selected"]
            )

        let selectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-selected")
        )
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-rejected", "rec-selected"])
        XCTAssertEqual(selectedPresentation.cardHint, .warning)
        XCTAssertEqual(
            selectedPresentation.badges.map(\.kind),
            [.remoteProvider, .includedQuota, .meteredPremium]
        )
        XCTAssertEqual(badge(.remoteProvider, in: selectedPresentation)?.label, "Search API")
        XCTAssertEqual(badge(.includedQuota, in: selectedPresentation)?.label, "Candidate policy")
        XCTAssertEqual(badge(.meteredPremium, in: selectedPresentation)?.tone, .neutral)
        XCTAssertTrue(selectedPresentation.statusLine.contains("policy planning only"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("balanced-search"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("meteredPremium"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("request"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("500 micros usd"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("metered"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("standard"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("balanced"))
        XCTAssertTrue(selectedPresentation.statusLine.contains("No transport or provider runtime has run"))
        assertSafePresentation(selectedPresentation, "selected")

        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )
        XCTAssertEqual(rejected.state, .rejected)
        XCTAssertEqual(rejectedPresentation.cardHint, .disabled)
        XCTAssertEqual(rejectedPresentation.badges.map(\.kind), [.privacyBlocked])
        XCTAssertEqual(badge(.privacyBlocked, in: rejectedPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: rejectedPresentation))
        XCTAssertNil(badge(.meteredPremium, in: rejectedPresentation))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("blocked by metadata policy"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("privacyBlocked"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No candidate is eligible"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(rejectedPresentation.statusLine.contains("blocked-search selected"))
        assertSafePresentation(rejectedPresentation, "rejected")
    }

    func test_duplicateIDsKeepFirstAndHiddenMissingStayNil() throws {
        let first = selectedDecision(
            id: "first-vendor",
            costClass: .includedQuota,
            quotaClass: .includedQuota,
            quotaSnapshot: Self.includedQuota()
        )
        let second = rejectedDecision(
            request: selectionRequest(maxUnitMicros: 100),
            candidates: [candidate(id: "second-vendor", estimatedUnitMicros: 500)]
        )
        let hidden = selectedDecision(id: "hidden-vendor")
        let source = ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-duplicate", decision: first),
                    .init(recommendationID: "rec-duplicate", decision: second),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: ["rec-duplicate", "rec-duplicate"]
            )
        let store = ServerProviderSearchAPILiveVendorSelectionStatusStore(
            decisions: [
                (recommendationID: "rec-duplicate", decision: first),
                (recommendationID: "rec-duplicate", decision: second),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-duplicate", "rec-hidden"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-duplicate"])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(
            presentation.badges.map(\.kind),
            [.remoteProvider, .includedQuota]
        )
        XCTAssertTrue(presentation.statusLine.contains("first-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("second-vendor"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_rejectionReasonMatrixMapsToStableBadges() throws {
        let cases: [
            (
                id: String,
                decision: ServerProviderSearchAPILiveVendorSelectionDecision,
                expectedReason: ServerProviderSearchAPILiveVendorSelectionRejectionReason,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            (
                "empty",
                rejectedDecision(candidates: []),
                .candidateListEmpty,
                .unavailable
            ),
            (
                "privacy",
                rejectedDecision(request: selectionRequest(privacyClass: .health)),
                .privacyBlocked,
                .privacyBlocked
            ),
            (
                "cost",
                rejectedDecision(
                    request: selectionRequest(maxUnitMicros: 100),
                    candidates: [candidate(estimatedUnitMicros: 500)]
                ),
                .unitPriceTooHigh,
                .costBlocked
            ),
            (
                "freshness",
                rejectedDecision(
                    request: selectionRequest(freshness: .liveRequired),
                    candidates: [candidate(supportedFreshness: [.cachedOK])]
                ),
                .unsupportedFreshness,
                .staleCache
            ),
            (
                "terms",
                rejectedDecision(
                    candidates: [
                        candidate(
                            citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                                supportsCitations: false,
                                supportsSourceHost: true,
                                supportsAttribution: true
                            )
                        ),
                    ]
                ),
                .citationSupportMissing,
                .termsBlocked
            ),
        ]
        let source = ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer()
            .statusSource(
                inputs: cases.map { testCase in
                    .init(recommendationID: "rec-\(testCase.id)", decision: testCase.decision)
                },
                renderedRecommendationIDs: cases.map { "rec-\($0.id)" }
            )

        for testCase in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(testCase.id)"),
                testCase.id
            )
            XCTAssertEqual(testCase.decision.state, .rejected, testCase.id)
            XCTAssertTrue(
                testCase.decision.rejectionReasons.contains(testCase.expectedReason),
                testCase.id
            )
            XCTAssertEqual(presentation.cardHint, .disabled, testCase.id)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.id)
            XCTAssertTrue(presentation.statusLine.contains(testCase.expectedReason.rawValue), testCase.id)
            XCTAssertTrue(presentation.statusLine.contains("No candidate is eligible"), testCase.id)
            assertSafePresentation(presentation, testCase.id)
        }
    }

    func test_statusCopyAndDebugTextDoNotLeakRuntimeFields() throws {
        let selected = selectedDecision(id: "safe-vendor")
        let rejected = rejectedDecision(
            request: selectionRequest(pageBodyRequirement: .required),
            candidates: [candidate(id: "blocked-vendor", pageBodyMode: .unavailable)]
        )
        let source = ServerProviderSearchAPILiveVendorSelectionStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", decision: selected),
                    .init(recommendationID: "rec-blocked", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let selectedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-safe"))
        let rejectedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-blocked"))
        let text = [
            try encodedString(selected.safeCopy),
            try encodedString(rejected.safeCopy),
            selected.description,
            rejected.description,
            selectedPresentation.statusLine,
            rejectedPresentation.statusLine,
            selectedPresentation.badges.map(\.label).joined(separator: " "),
            rejectedPresentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("hidden-vendor"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status-source wording: \(forbidden)")
        }
    }

    private func selectedDecision(
        id: String,
        costClass: ProviderCostClass = .meteredPremium,
        quotaClass: ServerProviderSearchAPILiveVendorQuotaClass = .metered,
        quotaSnapshot: ServerProviderQuotaSnapshot? = nil
    ) -> ServerProviderSearchAPILiveVendorSelectionDecision {
        let decision = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: selectionRequest(
                costClass: costClass,
                quotaSnapshot: quotaSnapshot ?? Self.meteredQuota()
            ),
            candidates: [
                candidate(
                    id: id,
                    costClass: costClass,
                    quotaClass: quotaClass
                ),
            ]
        )
        XCTAssertEqual(decision.state, .selected)
        return decision
    }

    private func rejectedDecision(
        request: ServerProviderSearchAPILiveVendorSelectionRequest? = nil,
        candidates: [ServerProviderSearchAPILiveVendorCandidate]? = nil
    ) -> ServerProviderSearchAPILiveVendorSelectionDecision {
        let decision = ServerProviderSearchAPILiveVendorSelection.evaluate(
            request: request ?? selectionRequest(),
            candidates: candidates ?? [candidate()]
        )
        XCTAssertEqual(decision.state, .rejected)
        return decision
    }

    private func selectionRequest(
        desiredCapability: ProviderCapability = .webSearch,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        freshness: ProviderFreshness = .livePreferred,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        membershipTier: MembershipTier = .plus,
        region: ProviderRegion = .northAmerica,
        pageBodyRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        maxUnitMicros: Int = 1_000,
        quotaSnapshot: ServerProviderQuotaSnapshot? = nil
    ) -> ServerProviderSearchAPILiveVendorSelectionRequest {
        ServerProviderSearchAPILiveVendorSelectionRequest(
            desiredCapability: desiredCapability,
            resultShape: resultShape,
            freshness: freshness,
            privacyClass: privacyClass,
            costClass: costClass,
            membershipTier: membershipTier,
            region: region,
            citationRequired: true,
            sourceHostRequired: true,
            attributionRequired: true,
            pageBodyRequirement: pageBodyRequirement,
            allowedRetention: allowedRetention,
            maxUnitMicros: maxUnitMicros,
            quotaSnapshot: quotaSnapshot ?? Self.meteredQuota(),
            userFacingPurpose: "public-info lookup"
        )
    }

    private func candidate(
        id: String = "test-vendor",
        displayName: String = "Test Vendor",
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
        ],
        supportedFreshness: Set<ProviderFreshness> = [
            .cachedOK,
            .livePreferred,
        ],
        citationSupport: ServerProviderSearchAPIVendorCitationSupport? = nil,
        pageBodyMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        requiredRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit = .request,
        estimatedUnitMicros: Int = 500,
        quotaClass: ServerProviderSearchAPILiveVendorQuotaClass = .metered,
        qpsClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        allowedRegions: Set<ProviderRegion> = [.global, .northAmerica],
        latencyClass: ServerProviderSearchAPILiveVendorLatencyClass = .balanced,
        supportsAnswerGeneration: Bool = true,
        minimumMembershipTier: MembershipTier = .plus,
        isEnabled: Bool = true,
        disabledReason: ServerProviderSearchAPILiveVendorDisabledReason? = nil
    ) -> ServerProviderSearchAPILiveVendorCandidate {
        ServerProviderSearchAPILiveVendorCandidate(
            id: id,
            displayName: displayName,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            supportedResultShapes: supportedResultShapes,
            supportedFreshness: supportedFreshness,
            citationSupport: citationSupport ?? ServerProviderSearchAPIVendorCitationSupport(
                supportsCitations: true,
                supportsSourceHost: true,
                supportsAttribution: true
            ),
            pageBodyMode: pageBodyMode,
            requiredRetention: requiredRetention,
            costUnit: costUnit,
            estimatedUnitMicros: estimatedUnitMicros,
            quotaClass: quotaClass,
            qpsClass: qpsClass,
            allowedRegions: allowedRegions,
            latencyClass: latencyClass,
            supportsAnswerGeneration: supportsAnswerGeneration,
            minimumMembershipTier: minimumMembershipTier,
            isEnabled: isEnabled,
            disabledReason: disabledReason
        )
    }

    private static func meteredQuota() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            meteredEligibleProviderFamilies: [.searchAPI]
        )
    }

    private static func includedQuota() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: [.searchAPI],
            entitledProviderFamilies: [.searchAPI],
            remainingIncludedQuota: [.searchAPI: 2]
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
        try XCTUnwrap(String(data: JSONEncoder().encode(value), encoding: .utf8))
    }

    private func assertSafePresentation(
        _ presentation: ProviderStatusPresentation,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = [
            presentation.statusLine,
            presentation.badges.map(\.label).joined(separator: " "),
            presentation.badges.map(\.systemImage).joined(separator: " "),
            presentation.cardHint.rawValue,
        ]
            .joined(separator: "\n")
            .lowercased()
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected \(label) presentation wording: \(forbidden)",
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
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "cred" + "ential",
            "o" + "auth",
            "url" + "session",
            "url" + "request",
            "s" + "dk",
            "client" + "handle",
            "raw" + "query",
            "raw" + " query",
            "raw" + "page",
            "raw" + " page",
            "provider" + "payload",
            "provider" + " payload",
            "crawl" + "er runtime",
            "m" + "cp runtime",
            "maps" + " " + "s" + "dk",
            "pay" + "ment",
            "book" + "ing",
            "ord" + "er",
            "hidden app" + "-control",
        ]
    }

    private func executionClaimFragments() -> [String] {
        [
            "exec" + "ution",
            "exec" + "ute",
            "complete" + "d",
            "comple" + "tion",
        ]
    }
}
