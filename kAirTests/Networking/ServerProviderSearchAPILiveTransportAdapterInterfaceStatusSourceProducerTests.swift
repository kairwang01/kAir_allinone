//
//  ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducerTests.swift
//  kAirTests
//
//  A156 Search API live transport adapter interface status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducerTests:
    XCTestCase
{

    func test_acceptedAndRejectedDecisionsPackageRenderedStatus() throws {
        let accepted = acceptedDecision(id: "primary-adapter")
        let rejected = rejectedDecision(
            request: interfaceRequest(privacyClass: .private),
            descriptors: [adapterDescriptor(id: "blocked-adapter")]
        )
        let source = ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer()
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
        XCTAssertEqual(badge(.remoteProvider, in: acceptedPresentation)?.label, "Search API interface")
        XCTAssertEqual(badge(.includedQuota, in: acceptedPresentation)?.label, "Adapter policy")
        XCTAssertEqual(badge(.meteredPremium, in: acceptedPresentation)?.label, "Premium metered")
        XCTAssertEqual(badge(.liveFreshness, in: acceptedPresentation)?.label, "Source required")
        XCTAssertTrue(acceptedPresentation.statusLine.contains("candidate adapter policy is advisory only"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Descriptor: primary-adapter"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Vendor: a156-vendor"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Cost: meteredPremium"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Unit: request"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Source state"))
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
        XCTAssertTrue(rejectedPresentation.statusLine.contains("privacyBlocked"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("isRuntimeCallable false"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(rejectedPresentation.statusLine.contains("blocked-adapter selected"))
        assertSafePresentation(rejectedPresentation, "rejected")
    }

    func test_duplicateIDsKeepFirstAndHiddenMissingStayNil() throws {
        let first = acceptedDecision(
            id: "first-adapter",
            searchContextClass: .searchOnly
        )
        let second = rejectedDecision(
            request: interfaceRequest(expectedCostClass: .includedQuota),
            descriptors: [adapterDescriptor(id: "second-adapter")]
        )
        let hidden = acceptedDecision(id: "hidden-adapter")
        let source = ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-visible", decision: first),
                    .init(recommendationID: "rec-visible", decision: second),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: ["rec-visible", "rec-visible"]
            )
        let store = ServerProviderSearchAPILiveTransportAdapterInterfaceStatusStore(
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
        XCTAssertTrue(presentation.statusLine.contains("first-adapter"))
        XCTAssertTrue(presentation.statusLine.contains("Context: searchOnly"))
        XCTAssertFalse(presentation.statusLine.contains("second-adapter"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        assertSafePresentation(presentation, "first-wins")
    }

    func test_rejectionReasonsMapToStableBadges() throws {
        let cases: [
            (
                name: String,
                decision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision,
                expectedReason: ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason,
                expectedBadge: ProviderStatusBadgeKind
            )
        ] = [
            (
                "privacy",
                rejectedDecision(
                    request: interfaceRequest(privacyClass: .private),
                    descriptors: [adapterDescriptor()]
                ),
                .privacyBlocked,
                .privacyBlocked
            ),
            (
                "cost",
                rejectedDecision(descriptors: [adapterDescriptor(costClass: .includedQuota)]),
                .costClassMismatch,
                .costBlocked
            ),
            (
                "quota",
                rejectedDecision(descriptors: [adapterDescriptor(qpsClass: .unavailable)]),
                .quotaOrQPSUnavailable,
                .costBlocked
            ),
            (
                "source",
                rejectedDecision(
                    descriptors: [
                        adapterDescriptor(
                            citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                                supportsCitations: true,
                                supportsSourceHost: false,
                                supportsAttribution: true
                            )
                        ),
                    ]
                ),
                .missingSourceSupport,
                .termsBlocked
            ),
            (
                "readiness",
                rejectedDecision(
                    request: interfaceRequest(boundaryID: "a156-stale-boundary"),
                    descriptors: [adapterDescriptor()]
                ),
                .staleBoundaryOrReadiness,
                .staleCache
            ),
            (
                "unavailable",
                rejectedDecision(descriptors: []),
                .descriptorListEmpty,
                .unavailable
            ),
        ]
        let source = ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer()
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
        let accepted = acceptedDecision(id: "safe-adapter")
        let rejected = rejectedDecision(
            request: interfaceRequest(pageContentRequirement: .required),
            descriptors: [adapterDescriptor(id: "blocked-adapter", pageContentMode: .unavailable)]
        )
        let source = ServerProviderSearchAPILiveTransportAdapterInterfaceStatusSourceProducer()
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

    private func acceptedDecision(
        id: String,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass = .compactContext
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        let decision = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(),
            descriptors: [
                adapterDescriptor(
                    id: id,
                    searchContextClass: searchContextClass
                ),
            ]
        )
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func rejectedDecision(
        request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest? = nil,
        descriptors: [ServerProviderSearchAPILiveTransportAdapterDescriptor]? = nil
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        let decision = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: request ?? interfaceRequest(),
            descriptors: descriptors ?? [adapterDescriptor(isKillSwitchActive: true)]
        )
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertFalse(decision.isRuntimeCallable)
        return decision
    }

    private func interfaceRequest(
        selectedVendorDecisionID: String = "a150-selection-a156-vendor",
        selectedVendorID: String = "a156-vendor",
        meteredDecisionID: String = "a117-metered-decision",
        leaseID: String = "a122-lease",
        transportRequestID: String = "a126-transport-request",
        auditTraceID: String = "a140-audit-trace",
        boundaryID: String = "a144-search-api-live-transport-boundary",
        readinessDecisionID: String = "a145-search-api-live-transport-readiness",
        readinessState: ServerProviderSearchAPILiveTransportReadinessState = .readyForPlanning,
        liveProviderPathEnabled: Bool = false,
        expectedCapability: ProviderCapability = .webSearch,
        expectedResultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        expectedFreshness: ProviderFreshness = .livePreferred,
        expectedCostClass: ProviderCostClass = .meteredPremium,
        expectedCostUnit: ServerProviderSearchAPILiveVendorCostUnit = .request,
        privacyClass: ProviderPrivacyClass = .general,
        region: ProviderRegion = .northAmerica,
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceRequest {
        ServerProviderSearchAPILiveTransportAdapterInterfaceRequest(
            selectedVendorDecisionID: selectedVendorDecisionID,
            selectedVendorID: selectedVendorID,
            meteredDecisionID: meteredDecisionID,
            leaseID: leaseID,
            transportRequestID: transportRequestID,
            auditTraceID: auditTraceID,
            boundaryID: boundaryID,
            readinessDecisionID: readinessDecisionID,
            readinessState: readinessState,
            liveProviderPathEnabled: liveProviderPathEnabled,
            expectedCapability: expectedCapability,
            expectedResultShape: expectedResultShape,
            expectedFreshness: expectedFreshness,
            expectedCostClass: expectedCostClass,
            expectedCostUnit: expectedCostUnit,
            privacyClass: privacyClass,
            region: region,
            citationRequired: true,
            sourceHostRequired: true,
            attributionRequired: true,
            pageContentRequirement: pageContentRequirement,
            allowedRetention: allowedRetention,
            userFacingPurpose: "public-info lookup"
        )
    }

    private func adapterDescriptor(
        id: String = "a156-adapter",
        vendorID: String = "a156-vendor",
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
        costUnit: ServerProviderSearchAPILiveVendorCostUnit = .request,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass = .compactContext,
        pageContentMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        retentionClass: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        citationSupport: ServerProviderSearchAPIVendorCitationSupport? = nil,
        qpsClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        allowedRegions: Set<ProviderRegion> = [.global, .northAmerica],
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        isKillSwitchActive: Bool = false
    ) -> ServerProviderSearchAPILiveTransportAdapterDescriptor {
        ServerProviderSearchAPILiveTransportAdapterDescriptor(
            id: id,
            vendorID: vendorID,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            supportedResultShapes: supportedResultShapes,
            supportedFreshness: supportedFreshness,
            costUnit: costUnit,
            searchContextClass: searchContextClass,
            pageContentMode: pageContentMode,
            retentionClass: retentionClass,
            citationSupport: citationSupport ?? ServerProviderSearchAPIVendorCitationSupport(
                supportsCitations: true,
                supportsSourceHost: true,
                supportsAttribution: true
            ),
            qpsClass: qpsClass,
            allowedRegions: allowedRegions,
            killSwitchID: "a156-kill-switch",
            retryPolicyID: "a156-retry-policy",
            serverSecretMode: serverSecretMode,
            isKillSwitchActive: isKillSwitchActive
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
