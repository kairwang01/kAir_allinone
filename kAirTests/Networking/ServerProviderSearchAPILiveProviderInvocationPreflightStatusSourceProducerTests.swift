//
//  ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducerTests.swift
//  kAirTests
//
//  A161 Search API live provider invocation preflight status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducerTests:
    XCTestCase
{

    func test_acceptedAndRejectedPreflightsPackageRenderedStatus() throws {
        let accepted = acceptedPreflight(preflightID: "primary-preflight")
        let rejected = rejectedPreflight(privacyClass: .health)
        let source = ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-accepted", decision: accepted),
                    .init(recommendationID: "rec-rejected", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-rejected", "rec-accepted"]
            )

        let acceptedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-accepted")
        )
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-accepted", "rec-rejected"])
        XCTAssertEqual(acceptedPresentation.cardHint, .warning)
        XCTAssertEqual(
            acceptedPresentation.badges.map(\.kind),
            [.remoteProvider, .includedQuota, .meteredPremium, .liveFreshness]
        )
        XCTAssertEqual(badge(.remoteProvider, in: acceptedPresentation)?.label, "Search API preflight")
        XCTAssertEqual(badge(.includedQuota, in: acceptedPresentation)?.label, "Preflight policy")
        XCTAssertEqual(badge(.meteredPremium, in: acceptedPresentation)?.label, "Premium metered")
        XCTAssertEqual(badge(.liveFreshness, in: acceptedPresentation)?.label, "Source checked")
        XCTAssertTrue(acceptedPresentation.statusLine.contains("provider preflight is advisory only"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Preflight: primary-preflight"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Descriptor: a161-adapter"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Vendor: a161-vendor"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Budget: a161-budget-snapshot"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("No transport or provider runtime has run"))
        assertSafePresentation(acceptedPresentation, "accepted")

        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )
        XCTAssertEqual(rejected.state, .rejected)
        XCTAssertEqual(rejectedPresentation.cardHint, .disabled)
        XCTAssertEqual(rejectedPresentation.badges.map(\.kind), [.privacyBlocked])
        XCTAssertEqual(badge(.privacyBlocked, in: rejectedPresentation)?.label, "Privacy blocked")
        XCTAssertTrue(rejectedPresentation.statusLine.contains("disabled by metadata policy"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("healthContextBlocked"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
        assertSafePresentation(rejectedPresentation, "rejected")
    }

    func test_duplicateRecommendationIDsKeepFirstAndHiddenMissingStayNil() throws {
        let first = acceptedPreflight(preflightID: "first-preflight")
        let second = rejectedPreflight(costClass: .includedQuota)
        let hidden = acceptedPreflight(preflightID: "hidden-preflight")
        let source = ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-visible", decision: first),
                    .init(recommendationID: "rec-visible", decision: second),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: ["rec-visible", "rec-visible"]
            )
        let store = ServerProviderSearchAPILiveProviderInvocationPreflightStatusStore(
            decisions: [
                (recommendationID: "rec-visible", decision: first),
                (recommendationID: "rec-visible", decision: second),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-visible")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-hidden", "rec-visible"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-visible"])
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertTrue(presentation.statusLine.contains("first-preflight"))
        XCTAssertFalse(presentation.statusLine.contains("includedQuota"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_rejectionReasonsMapToStableBadges() throws {
        let duplicateInput = preflightInput(adapterDecision: acceptedAdapterDecision())
        let cases: [
            (
                name: String,
                decision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision,
                expectedReason: ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            (
                "privacy",
                rejectedPreflight(privacyClass: .private),
                .privacyBlocked,
                .privacyBlocked
            ),
            (
                "cost",
                rejectedPreflight(costClass: .includedQuota),
                .costClassMismatch,
                .costBlocked
            ),
            (
                "source",
                rejectedPreflight(sourceState: .unknown),
                .missingSourcePolicy,
                .termsBlocked
            ),
            (
                "readiness",
                rejectedPreflight(boundaryID: "a161-stale-boundary"),
                .staleBoundaryOrReadiness,
                .staleCache
            ),
            (
                "region",
                rejectedPreflight(
                    adapterDecision: acceptedAdapterDecision(
                        interfaceRegion: .europe,
                        descriptorRegions: [.europe]
                    ),
                    region: .northAmerica
                ),
                .regionBlocked,
                .termsBlocked
            ),
            (
                "duplicate",
                ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
                    input: duplicateInput,
                    existingPreflightIDs: [duplicateInput.preflightID]
                ),
                .duplicatePreflightID,
                .unavailable
            ),
        ]
        let source = ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer()
            .statusSource(
                inputs: cases.map { testCase in
                    .init(
                        recommendationID: "rec-\(testCase.name)",
                        decision: testCase.decision
                    )
                },
                renderedRecommendationIDs: cases.map { "rec-\($0.name)" }
            )

        for testCase in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(testCase.name)"),
                testCase.name
            )
            XCTAssertEqual(testCase.decision.state, .rejected, testCase.name)
            XCTAssertTrue(
                testCase.decision.rejectionReasons.contains(testCase.expectedReason),
                testCase.name
            )
            XCTAssertEqual(presentation.cardHint, .disabled, testCase.name)
            XCTAssertEqual(presentation.badges.map(\.kind), [testCase.expectedBadge], testCase.name)
            XCTAssertTrue(
                presentation.statusLine.contains(testCase.expectedReason.rawValue),
                testCase.name
            )
            XCTAssertTrue(
                presentation.statusLine.contains("disabled by metadata policy"),
                testCase.name
            )
            XCTAssertTrue(
                presentation.statusLine.contains("isRuntimeCallable false"),
                testCase.name
            )
            assertSafePresentation(presentation, testCase.name)
        }
    }

    func test_statusCopyDebugAndEncodedCopyDoNotLeakRuntimeFields() throws {
        let accepted = acceptedPreflight(preflightID: "safe-preflight")
        let rejected = rejectedPreflight(serverSecretMode: .clientProvided)
        let source = ServerProviderSearchAPILiveProviderInvocationPreflightStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", decision: accepted),
                    .init(recommendationID: "rec-blocked", decision: rejected),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let acceptedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-safe"))
        let rejectedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-blocked"))
        let text = [
            try encodedString(accepted.safeCopy),
            try encodedString(rejected.safeCopy),
            accepted.description,
            rejected.description,
            String(describing: acceptedPresentation),
            String(describing: rejectedPresentation),
            acceptedPresentation.statusLine,
            rejectedPresentation.statusLine,
            acceptedPresentation.badges.map(\.label).joined(separator: " "),
            rejectedPresentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("isruntimecallable"))
        XCTAssertTrue(text.contains("false"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(accepted.isRuntimeCallable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        for forbidden in sensitiveRuntimeFragments() + successClaimFragments() {
            XCTAssertFalse(
                text.contains(forbidden),
                "Unexpected status-source wording: \(forbidden)"
            )
        }
    }

    private func acceptedPreflight(
        preflightID: String = "a161-preflight"
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightDecision {
        let decision = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(
                adapterDecision: acceptedAdapterDecision(),
                preflightID: preflightID
            )
        )
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func rejectedPreflight(
        adapterDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision? = nil,
        costClass: ProviderCostClass = .meteredPremium,
        boundaryID: String = "a144-search-api-live-transport-boundary",
        sourceState: ServerSourcePolicyState = .passed,
        region: ProviderRegion = .northAmerica,
        privacyClass: ProviderPrivacyClass = .general,
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightDecision {
        let decision = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(
                adapterDecision: adapterDecision ?? acceptedAdapterDecision(),
                boundaryID: boundaryID,
                costClass: costClass,
                sourceState: sourceState,
                region: region,
                privacyClass: privacyClass,
                serverSecretMode: serverSecretMode
            )
        )
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func preflightInput(
        adapterDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision,
        preflightID: String = "a161-preflight",
        selectedDescriptorID: String = "a161-adapter",
        selectedVendorDecisionID: String = "a150-selection-a161-vendor",
        selectedVendorID: String = "a161-vendor",
        meteredDecisionID: String = "a117-metered-decision",
        leaseID: String = "a122-lease",
        leaseMeteredDecisionID: String = "a117-metered-decision",
        transportRequestID: String = "a126-transport-request",
        transportLeaseID: String = "a122-lease",
        auditTraceID: String = "a140-audit-trace",
        auditTransportRequestID: String = "a126-transport-request",
        boundaryID: String = "a144-search-api-live-transport-boundary",
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        adapterResultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        adapterFreshness: ProviderFreshness = .livePreferred,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        freshness: ProviderFreshness = .livePreferred,
        costClass: ProviderCostClass = .meteredPremium,
        costUnit: ServerProviderSearchAPILiveVendorCostUnit = .request,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass = .compactContext,
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        retentionClass: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        sourceState: ServerSourcePolicyState = .passed,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        attributionRequired: Bool = true,
        region: ProviderRegion = .northAmerica,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .plus,
        budgetSnapshotID: String = "a161-budget-snapshot",
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightInput {
        ServerProviderSearchAPILiveProviderInvocationPreflightInput(
            preflightID: preflightID,
            adapterInterfaceDecision: adapterDecision,
            selectedDescriptorID: selectedDescriptorID,
            selectedVendorDecisionID: selectedVendorDecisionID,
            selectedVendorID: selectedVendorID,
            meteredDecisionID: meteredDecisionID,
            leaseID: leaseID,
            leaseMeteredDecisionID: leaseMeteredDecisionID,
            transportRequestID: transportRequestID,
            transportLeaseID: transportLeaseID,
            auditTraceID: auditTraceID,
            auditTransportRequestID: auditTransportRequestID,
            boundaryID: boundaryID,
            providerFamily: providerFamily,
            capability: capability,
            adapterResultShape: adapterResultShape,
            adapterFreshness: adapterFreshness,
            resultShape: resultShape,
            freshness: freshness,
            costClass: costClass,
            costUnit: costUnit,
            searchContextClass: searchContextClass,
            pageContentRequirement: pageContentRequirement,
            retentionClass: retentionClass,
            sourceState: sourceState,
            citationRequired: citationRequired,
            sourceHostRequired: sourceHostRequired,
            attributionRequired: attributionRequired,
            region: region,
            privacyClass: privacyClass,
            membershipTier: membershipTier,
            budgetSnapshotID: budgetSnapshotID,
            serverSecretMode: serverSecretMode,
            userFacingPurpose: "public-info lookup"
        )
    }

    private func acceptedAdapterDecision(
        interfaceRegion: ProviderRegion = .northAmerica,
        descriptorRegions: Set<ProviderRegion> = [.global, .northAmerica]
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        let decision = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(region: interfaceRegion),
            descriptors: [adapterDescriptor(allowedRegions: descriptorRegions)]
        )
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func interfaceRequest(
        region: ProviderRegion = .northAmerica
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceRequest {
        ServerProviderSearchAPILiveTransportAdapterInterfaceRequest(
            selectedVendorDecisionID: "a150-selection-a161-vendor",
            selectedVendorID: "a161-vendor",
            meteredDecisionID: "a117-metered-decision",
            leaseID: "a122-lease",
            transportRequestID: "a126-transport-request",
            auditTraceID: "a140-audit-trace",
            expectedResultShape: .organicLinks,
            expectedFreshness: .livePreferred,
            expectedCostClass: .meteredPremium,
            expectedCostUnit: .request,
            region: region,
            userFacingPurpose: "public-info lookup"
        )
    }

    private func adapterDescriptor(
        allowedRegions: Set<ProviderRegion> = [.global, .northAmerica]
    ) -> ServerProviderSearchAPILiveTransportAdapterDescriptor {
        ServerProviderSearchAPILiveTransportAdapterDescriptor(
            id: "a161-adapter",
            vendorID: "a161-vendor",
            supportedResultShapes: [.organicLinks, .answerSummary],
            supportedFreshness: [.cachedOK, .livePreferred],
            costUnit: .request,
            searchContextClass: .compactContext,
            pageContentMode: .optional,
            retentionClass: .ephemeralOnly,
            citationSupport: .full,
            qpsClass: .standard,
            allowedRegions: allowedRegions,
            killSwitchID: "a161-kill-switch",
            retryPolicyID: "a161-retry-policy"
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
        for forbidden in sensitiveRuntimeFragments() + successClaimFragments() {
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
            "store" + "kit",
            "pay" + "ment",
            "ord" + "er",
            "book" + "ing",
            "crawl" + "er runtime",
            "m" + "cp runtime",
            "maps" + " " + "s" + "dk",
            "hidden " + "app" + "-control",
            "provider" + " call",
        ]
    }

    private func successClaimFragments() -> [String] {
        [
            "exec" + "ution",
            "exec" + "ute",
            "complete" + "d",
            "comple" + "tion",
        ]
    }
}
