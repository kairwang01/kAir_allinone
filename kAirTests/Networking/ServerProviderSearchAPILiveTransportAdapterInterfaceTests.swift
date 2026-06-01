//
//  ServerProviderSearchAPILiveTransportAdapterInterfaceTests.swift
//  kAirTests
//
//  A155 Search API live transport server adapter interface proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPILiveTransportAdapterInterfaceTests: XCTestCase {

    func test_acceptsMatchingSearchAPIDescriptorAndRemainsNonCallable() throws {
        let request = interfaceRequest()
        let descriptor = adapterDescriptor(id: "primary-adapter")
        let fallback = adapterDescriptor(
            id: "fallback-adapter",
            vendorID: "other-vendor"
        )

        let decision = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: request,
            descriptors: [descriptor, fallback]
        )
        let repeated = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: request,
            descriptors: [descriptor, fallback]
        )

        assertSendable(descriptor)
        assertSendable(request)
        assertSendable(decision)
        assertSendable(decision.safeCopy)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertTrue(decision.isAccepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.safeCopy.isRuntimeCallable)
        XCTAssertEqual(decision.selectedDescriptorID, "primary-adapter")
        XCTAssertEqual(decision.selectedVendorID, "a155-vendor")
        XCTAssertEqual(decision.rejectionReasons, [])
        XCTAssertEqual(decision.descriptorSummaries.map(\.id), ["primary-adapter", "fallback-adapter"])
        XCTAssertEqual(decision.descriptorSummaries.map(\.isEligible), [true, false])
        XCTAssertEqual(decision.descriptorSummaries.first?.costUnit, .request)
        XCTAssertEqual(decision.descriptorSummaries.first?.searchContextClass, .compactContext)
        XCTAssertEqual(decision.descriptorSummaries.first?.pageContentMode, .optional)
        XCTAssertEqual(decision.descriptorSummaries.first?.retentionClass, .ephemeralOnly)
        XCTAssertEqual(decision.descriptorSummaries.first?.qpsClass, .standard)
        XCTAssertEqual(decision.descriptorSummaries.first?.regionIDs, ["global", "northAmerica"])
        XCTAssertTrue(decision.statusLine.contains("metadata only"))
        XCTAssertTrue(decision.statusLine.contains("live provider path remains disabled"))
    }

    func test_rejectionMatrixPreservesDeterministicValueOnlyReasons() {
        let baseRequest = interfaceRequest()
        let baseDescriptor = adapterDescriptor()
        let cases: [
            (
                id: String,
                request: ServerProviderSearchAPILiveTransportAdapterInterfaceRequest,
                descriptors: [ServerProviderSearchAPILiveTransportAdapterDescriptor],
                expected: ServerProviderSearchAPILiveTransportAdapterInterfaceRejectionReason
            )
        ] = [
            (
                "empty descriptor list",
                baseRequest,
                [],
                .descriptorListEmpty
            ),
            (
                "provider family mismatch",
                baseRequest,
                [adapterDescriptor(providerFamily: .googleMaps)],
                .providerFamilyMismatch
            ),
            (
                "vendor mismatch",
                baseRequest,
                [adapterDescriptor(vendorID: "other-vendor")],
                .vendorMismatch
            ),
            (
                "unsupported capability",
                baseRequest,
                [adapterDescriptor(capability: .localServiceSearch)],
                .unsupportedCapability
            ),
            (
                "unsupported result shape",
                baseRequest,
                [adapterDescriptor(supportedResultShapes: [.answerSummary])],
                .unsupportedResultShape
            ),
            (
                "unsupported freshness",
                baseRequest,
                [adapterDescriptor(supportedFreshness: [.cachedOK])],
                .unsupportedFreshness
            ),
            (
                "cost class mismatch",
                baseRequest,
                [adapterDescriptor(costClass: .includedQuota)],
                .costClassMismatch
            ),
            (
                "cost unit mismatch",
                baseRequest,
                [adapterDescriptor(costUnit: .contextBlock)],
                .costUnitMismatch
            ),
            (
                "page content policy conflict",
                baseRequest,
                [adapterDescriptor(pageContentMode: .required)],
                .pageContentPolicyConflict
            ),
            (
                "retention conflict",
                baseRequest,
                [adapterDescriptor(retentionClass: .shortTermCache)],
                .retentionConflict
            ),
            (
                "missing citation support",
                baseRequest,
                [
                    adapterDescriptor(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: false,
                            supportsSourceHost: true,
                            supportsAttribution: true
                        )
                    ),
                ],
                .missingCitationSupport
            ),
            (
                "missing source support",
                baseRequest,
                [
                    adapterDescriptor(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: true,
                            supportsSourceHost: false,
                            supportsAttribution: true
                        )
                    ),
                ],
                .missingSourceSupport
            ),
            (
                "missing attribution support",
                baseRequest,
                [
                    adapterDescriptor(
                        citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                            supportsCitations: true,
                            supportsSourceHost: true,
                            supportsAttribution: false
                        )
                    ),
                ],
                .missingAttributionSupport
            ),
            (
                "region blocked",
                baseRequest,
                [adapterDescriptor(allowedRegions: [.europe])],
                .regionBlocked
            ),
            (
                "quota unavailable",
                baseRequest,
                [adapterDescriptor(qpsClass: .unavailable)],
                .quotaOrQPSUnavailable
            ),
            (
                "kill switch active",
                baseRequest,
                [adapterDescriptor(isKillSwitchActive: true)],
                .killSwitchActive
            ),
            (
                "missing upstream id",
                interfaceRequest(meteredDecisionID: ""),
                [baseDescriptor],
                .missingUpstreamID
            ),
            (
                "privacy blocked",
                interfaceRequest(privacyClass: .health),
                [baseDescriptor],
                .privacyBlocked
            ),
            (
                "stale boundary",
                interfaceRequest(boundaryID: "a155-stale-boundary"),
                [baseDescriptor],
                .staleBoundaryOrReadiness
            ),
            (
                "not server owned",
                baseRequest,
                [adapterDescriptor(serverSecretMode: .clientProvided)],
                .serverSecretModeNotServerOwned
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
                request: testCase.request,
                descriptors: testCase.descriptors
            )
            let repeated = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
                request: testCase.request,
                descriptors: testCase.descriptors
            )

            XCTAssertEqual(decision, repeated, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertFalse(decision.isAccepted, testCase.id)
            XCTAssertFalse(decision.isRuntimeCallable, testCase.id)
            XCTAssertFalse(decision.safeCopy.isRuntimeCallable, testCase.id)
            XCTAssertNil(decision.selectedDescriptorID, testCase.id)
            XCTAssertNil(decision.selectedVendorID, testCase.id)
            XCTAssertTrue(decision.rejectionReasons.contains(testCase.expected), testCase.id)
            XCTAssertTrue(
                decision.statusLine.contains("metadata policy"),
                testCase.id
            )
            XCTAssertTrue(
                decision.statusLine.contains("live provider path remains disabled"),
                testCase.id
            )
        }
    }

    func test_duplicateDescriptorsKeepFirstWins() {
        let request = interfaceRequest()
        let blockedFirst = adapterDescriptor(
            id: "duplicate-adapter",
            isKillSwitchActive: true
        )
        let laterEligible = adapterDescriptor(
            id: "duplicate adapter",
            searchContextClass: .answerContext
        )
        let rejected = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: request,
            descriptors: [blockedFirst, laterEligible]
        )

        XCTAssertEqual(rejected.state, .rejected)
        XCTAssertNil(rejected.selectedDescriptorID)
        XCTAssertEqual(rejected.duplicateDescriptorIDs, ["duplicate-adapter"])
        XCTAssertEqual(rejected.descriptorSummaries.count, 1)
        XCTAssertEqual(rejected.descriptorSummaries[0].searchContextClass, .compactContext)
        XCTAssertTrue(rejected.rejectionReasons.contains(.duplicateDescriptorID))
        XCTAssertTrue(rejected.rejectionReasons.contains(.killSwitchActive))

        let eligibleFirst = adapterDescriptor(
            id: "accepted-duplicate",
            searchContextClass: .searchOnly
        )
        let blockedLater = adapterDescriptor(
            id: "accepted duplicate",
            isKillSwitchActive: true
        )
        let accepted = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: request,
            descriptors: [eligibleFirst, blockedLater]
        )

        XCTAssertEqual(accepted.state, .accepted)
        XCTAssertEqual(accepted.selectedDescriptorID, "accepted-duplicate")
        XCTAssertEqual(accepted.duplicateDescriptorIDs, ["accepted-duplicate"])
        XCTAssertEqual(accepted.descriptorSummaries.count, 1)
        XCTAssertEqual(accepted.descriptorSummaries[0].searchContextClass, .searchOnly)
        XCTAssertFalse(accepted.isRuntimeCallable)
    }

    func test_decisionAndSafeCopyAreCodableAndDoNotExposeRuntimeFields() throws {
        let accepted = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(),
            descriptors: [adapterDescriptor(id: "safe-adapter")]
        )
        let rejected = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(privacyClass: .private),
            descriptors: [adapterDescriptor(id: "blocked-adapter")]
        )

        let encodedDecision = try encodedString(accepted)
        let decodedDecision = try JSONDecoder().decode(
            ServerProviderSearchAPILiveTransportAdapterInterfaceDecision.self,
            from: try JSONEncoder().encode(accepted)
        )
        XCTAssertEqual(decodedDecision, accepted)
        XCTAssertEqual(decodedDecision.safeCopy, accepted.safeCopy)

        let text = [
            encodedDecision,
            try encodedString(accepted.safeCopy),
            try encodedString(rejected.safeCopy),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
            accepted.safeCopy.description,
            rejected.safeCopy.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("live provider path remains disabled"))
        XCTAssertFalse(accepted.isRuntimeCallable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        for fragment in forbiddenRuntimeFragments() {
            XCTAssertFalse(
                text.contains(fragment),
                "Unexpected adapter interface copy fragment: \(fragment)"
            )
        }
    }

    private func interfaceRequest(
        selectedVendorDecisionID: String = "a150-selection-a155-vendor",
        selectedVendorID: String = "a155-vendor",
        meteredDecisionID: String = "a117-metered-decision",
        leaseID: String = "a122-lease",
        transportRequestID: String = "a126-transport-request",
        auditTraceID: String = "a140-audit-trace",
        boundaryID: String = ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID,
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
        id: String = "a155-adapter",
        vendorID: String = "a155-vendor",
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
        citationSupport: ServerProviderSearchAPIVendorCitationSupport = .full,
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
            citationSupport: citationSupport,
            qpsClass: qpsClass,
            allowedRegions: allowedRegions,
            killSwitchID: "a155-kill-switch",
            retryPolicyID: "a155-retry-policy",
            serverSecretMode: serverSecretMode,
            isKillSwitchActive: isKillSwitchActive
        )
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(String(data: JSONEncoder().encode(value), encoding: .utf8))
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
        XCTAssertTrue(true, file: file, line: line)
    }

    private func forbiddenRuntimeFragments() -> [String] {
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
            "hidden " + "app" + "-control",
            "provider" + " call",
            "exec" + "ution",
            "exec" + "ute",
            "complete" + "d",
            "comple" + "tion",
        ]
    }
}
