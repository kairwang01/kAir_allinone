//
//  ServerProviderSearchAPILiveProviderInvocationPreflightTests.swift
//  kAirTests
//
//  A160 Search API live provider invocation preflight proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPILiveProviderInvocationPreflightTests: XCTestCase {

    func test_acceptsMatchingUpstreamChainAndRemainsNonCallable() throws {
        let adapterDecision = acceptedAdapterDecision()
        let input = preflightInput(adapterDecision: adapterDecision)

        let decision = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: input
        )
        let repeated = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: input
        )

        assertSendable(input)
        assertSendable(decision)
        assertSendable(decision.safeCopy)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision.state, .accepted)
        XCTAssertTrue(decision.isAccepted)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.safeCopy.isRuntimeCallable)
        XCTAssertEqual(decision.rejectionReasons, [])
        XCTAssertEqual(decision.summary?.id, "a160-preflight")
        XCTAssertEqual(decision.summary?.selectedDescriptorID, "a160-adapter")
        XCTAssertEqual(decision.summary?.selectedVendorDecisionID, "a150-selection-a160-vendor")
        XCTAssertEqual(decision.summary?.selectedVendorID, "a160-vendor")
        XCTAssertEqual(decision.summary?.meteredDecisionID, "a117-metered-decision")
        XCTAssertEqual(decision.summary?.leaseID, "a122-lease")
        XCTAssertEqual(decision.summary?.transportRequestID, "a126-transport-request")
        XCTAssertEqual(decision.summary?.auditTraceID, "a140-audit-trace")
        XCTAssertEqual(decision.summary?.budgetSnapshotID, "a160-budget-snapshot")
        XCTAssertEqual(decision.summary?.providerFamily, .searchAPI)
        XCTAssertEqual(decision.summary?.capability, .webSearch)
        XCTAssertEqual(decision.summary?.resultShape, .organicLinks)
        XCTAssertEqual(decision.summary?.freshness, .livePreferred)
        XCTAssertEqual(decision.summary?.costClass, .meteredPremium)
        XCTAssertEqual(decision.summary?.costUnit, .request)
        XCTAssertEqual(decision.summary?.searchContextClass, .compactContext)
        XCTAssertEqual(decision.summary?.pageContentRequirement, .snippetsOnly)
        XCTAssertEqual(decision.summary?.retentionClass, .ephemeralOnly)
        XCTAssertEqual(decision.summary?.sourceState, .passed)
        XCTAssertEqual(decision.summary?.region, .northAmerica)
        XCTAssertEqual(decision.summary?.membershipTier, .plus)
        XCTAssertTrue(decision.statusLine.contains("metadata only"))
        XCTAssertTrue(decision.statusLine.contains("remote provider path remains disabled"))
    }

    func test_rejectionMatrixPreservesDeterministicValueOnlyReasons() {
        let accepted = acceptedAdapterDecision()
        let rejectedAdapter = ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(privacyClass: .health),
            descriptors: [adapterDescriptor()]
        )
        let europeAdapter = acceptedAdapterDecision(
            interfaceRegion: .europe,
            descriptorRegions: [.europe]
        )
        let pageRequiredAdapter = acceptedAdapterDecision(
            pageContentRequirement: .required,
            pageContentMode: .required
        )
        let retainedAdapter = acceptedAdapterDecision(
            allowedRetention: .shortTermCache,
            retentionClass: .shortTermCache
        )

        let cases: [
            (
                id: String,
                input: ServerProviderSearchAPILiveProviderInvocationPreflightInput,
                expected: ServerProviderSearchAPILiveProviderInvocationPreflightRejectionReason
            )
        ] = [
            (
                "adapter interface rejected",
                preflightInput(adapterDecision: rejectedAdapter),
                .adapterInterfaceNotAccepted
            ),
            (
                "runtime callable flag",
                preflightInput(adapterDecision: accepted, adapterRuntimeCallableFlag: true),
                .runtimeCallableFlagTrue
            ),
            (
                "unsupported provider family",
                preflightInput(adapterDecision: accepted, providerFamily: .mcp),
                .unsupportedProviderFamily
            ),
            (
                "capability mismatch",
                preflightInput(adapterDecision: accepted, capability: .localServiceSearch),
                .capabilityMismatch
            ),
            (
                "result shape mismatch",
                preflightInput(adapterDecision: accepted, adapterResultShape: .answerSummary),
                .resultShapeMismatch
            ),
            (
                "freshness mismatch",
                preflightInput(adapterDecision: accepted, adapterFreshness: .cachedOK),
                .freshnessMismatch
            ),
            (
                "search context mismatch",
                preflightInput(adapterDecision: accepted, searchContextClass: .answerContext),
                .searchContextMismatch
            ),
            (
                "vendor mismatch",
                preflightInput(adapterDecision: accepted, selectedVendorID: "other-vendor"),
                .vendorOrDescriptorMismatch
            ),
            (
                "descriptor mismatch",
                preflightInput(adapterDecision: accepted, selectedDescriptorID: "other-adapter"),
                .vendorOrDescriptorMismatch
            ),
            (
                "missing upstream id",
                preflightInput(adapterDecision: accepted, meteredDecisionID: ""),
                .missingUpstreamID
            ),
            (
                "metered decision mismatch",
                preflightInput(adapterDecision: accepted, leaseMeteredDecisionID: "other-metered"),
                .meteredDecisionMismatch
            ),
            (
                "lease mismatch",
                preflightInput(adapterDecision: accepted, transportLeaseID: "other-lease"),
                .leaseMismatch
            ),
            (
                "expired lease",
                preflightInput(adapterDecision: accepted, leaseState: .expired),
                .expiredLease
            ),
            (
                "transport request mismatch",
                preflightInput(adapterDecision: accepted, auditTransportRequestID: "other-request"),
                .transportRequestMismatch
            ),
            (
                "stale boundary",
                preflightInput(adapterDecision: accepted, boundaryID: "stale-boundary"),
                .staleBoundaryOrReadiness
            ),
            (
                "cost class mismatch",
                preflightInput(adapterDecision: accepted, costClass: .includedQuota),
                .costClassMismatch
            ),
            (
                "cost unit mismatch",
                preflightInput(adapterDecision: accepted, costUnit: .contextBlock),
                .costUnitMismatch
            ),
            (
                "missing budget snapshot",
                preflightInput(adapterDecision: accepted, budgetSnapshotID: ""),
                .missingBudgetSnapshot
            ),
            (
                "region blocked",
                preflightInput(adapterDecision: europeAdapter, region: .northAmerica),
                .regionBlocked
            ),
            (
                "private blocked",
                preflightInput(adapterDecision: accepted, privacyClass: .private),
                .privacyBlocked
            ),
            (
                "health blocked",
                preflightInput(adapterDecision: accepted, privacyClass: .health),
                .healthContextBlocked
            ),
            (
                "source policy missing",
                preflightInput(adapterDecision: accepted, sourceState: .unknown),
                .missingSourcePolicy
            ),
            (
                "citation missing",
                preflightInput(adapterDecision: accepted, citationRequired: false),
                .missingCitation
            ),
            (
                "source host missing",
                preflightInput(adapterDecision: accepted, sourceHostRequired: false),
                .missingSourceHost
            ),
            (
                "attribution missing",
                preflightInput(adapterDecision: accepted, attributionRequired: false),
                .missingAttribution
            ),
            (
                "page content conflict",
                preflightInput(adapterDecision: pageRequiredAdapter, pageContentRequirement: .snippetsOnly),
                .pageContentPolicyConflict
            ),
            (
                "retention conflict",
                preflightInput(adapterDecision: retainedAdapter, retentionClass: .ephemeralOnly),
                .retentionConflict
            ),
            (
                "server secret not owned",
                preflightInput(adapterDecision: accepted, serverSecretMode: .clientProvided),
                .serverSecretModeNotServerOwned
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
                input: testCase.input
            )
            let repeated = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
                input: testCase.input
            )

            XCTAssertEqual(decision, repeated, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertFalse(decision.isAccepted, testCase.id)
            XCTAssertFalse(decision.isRuntimeCallable, testCase.id)
            XCTAssertFalse(decision.safeCopy.isRuntimeCallable, testCase.id)
            XCTAssertTrue(decision.rejectionReasons.contains(testCase.expected), testCase.id)
            XCTAssertTrue(decision.statusLine.contains("metadata policy"), testCase.id)
            XCTAssertTrue(
                decision.statusLine.contains("remote provider path remains disabled"),
                testCase.id
            )
        }
    }

    func test_duplicatePreflightIDRejectsDeterministically() {
        let adapterDecision = acceptedAdapterDecision()
        let input = preflightInput(adapterDecision: adapterDecision)

        let decision = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: input,
            existingPreflightIDs: [input.preflightID]
        )
        let repeated = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: input,
            existingPreflightIDs: [input.preflightID]
        )

        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertEqual(decision.rejectionReasons, [.duplicatePreflightID])
        XCTAssertEqual(decision.summary?.id, input.preflightID)
    }

    func test_decisionAndSafeCopyAreCodableAndDoNotExposeRuntimeFields() throws {
        let accepted = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(adapterDecision: acceptedAdapterDecision())
        )
        let rejected = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(
                adapterDecision: acceptedAdapterDecision(),
                privacyClass: .health
            )
        )

        let encodedDecision = try encodedString(accepted)
        let decodedDecision = try JSONDecoder().decode(
            ServerProviderSearchAPILiveProviderInvocationPreflightDecision.self,
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
        XCTAssertTrue(text.contains("remote provider path remains disabled"))
        XCTAssertFalse(accepted.isRuntimeCallable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        for fragment in forbiddenRuntimeFragments() {
            XCTAssertFalse(
                text.contains(fragment),
                "Unexpected preflight copy fragment: \(fragment)"
            )
        }
    }

    private func preflightInput(
        adapterDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision,
        preflightID: String = "a160-preflight",
        adapterRuntimeCallableFlag: Bool? = nil,
        selectedDescriptorID: String = "a160-adapter",
        selectedVendorDecisionID: String = "a150-selection-a160-vendor",
        selectedVendorID: String = "a160-vendor",
        meteredDecisionID: String = "a117-metered-decision",
        leaseID: String = "a122-lease",
        leaseMeteredDecisionID: String = "a117-metered-decision",
        leaseState: ServerProviderSearchAPILiveProviderInvocationLeaseState = .issued,
        transportRequestID: String = "a126-transport-request",
        transportLeaseID: String = "a122-lease",
        auditTraceID: String = "a140-audit-trace",
        auditTransportRequestID: String = "a126-transport-request",
        boundaryID: String = ServerProviderSearchAPILiveTransportReadinessGate.expectedBoundaryID,
        readinessState: ServerProviderSearchAPILiveTransportReadinessState = .readyForPlanning,
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
        budgetSnapshotID: String = "a160-budget-snapshot",
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightInput {
        ServerProviderSearchAPILiveProviderInvocationPreflightInput(
            preflightID: preflightID,
            adapterInterfaceDecision: adapterDecision,
            adapterRuntimeCallableFlag: adapterRuntimeCallableFlag,
            selectedDescriptorID: selectedDescriptorID,
            selectedVendorDecisionID: selectedVendorDecisionID,
            selectedVendorID: selectedVendorID,
            meteredDecisionID: meteredDecisionID,
            leaseID: leaseID,
            leaseMeteredDecisionID: leaseMeteredDecisionID,
            leaseState: leaseState,
            transportRequestID: transportRequestID,
            transportLeaseID: transportLeaseID,
            auditTraceID: auditTraceID,
            auditTransportRequestID: auditTransportRequestID,
            boundaryID: boundaryID,
            readinessState: readinessState,
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
        descriptorRegions: Set<ProviderRegion> = [.global, .northAmerica],
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        pageContentMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        allowedRetention: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        retentionClass: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(
                region: interfaceRegion,
                pageContentRequirement: pageContentRequirement,
                allowedRetention: allowedRetention
            ),
            descriptors: [
                adapterDescriptor(
                    pageContentMode: pageContentMode,
                    retentionClass: retentionClass,
                    allowedRegions: descriptorRegions
                ),
            ]
        )
    }

    private func interfaceRequest(
        selectedVendorDecisionID: String = "a150-selection-a160-vendor",
        selectedVendorID: String = "a160-vendor",
        meteredDecisionID: String = "a117-metered-decision",
        leaseID: String = "a122-lease",
        transportRequestID: String = "a126-transport-request",
        auditTraceID: String = "a140-audit-trace",
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
            expectedResultShape: .organicLinks,
            expectedFreshness: .livePreferred,
            expectedCostClass: .meteredPremium,
            expectedCostUnit: .request,
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
        id: String = "a160-adapter",
        vendorID: String = "a160-vendor",
        pageContentMode: ServerProviderSearchAPIVendorPageBodyMode = .optional,
        retentionClass: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        allowedRegions: Set<ProviderRegion> = [.global, .northAmerica]
    ) -> ServerProviderSearchAPILiveTransportAdapterDescriptor {
        ServerProviderSearchAPILiveTransportAdapterDescriptor(
            id: id,
            vendorID: vendorID,
            supportedResultShapes: [.organicLinks, .answerSummary],
            supportedFreshness: [.cachedOK, .livePreferred],
            costUnit: .request,
            searchContextClass: .compactContext,
            pageContentMode: pageContentMode,
            retentionClass: retentionClass,
            citationSupport: .full,
            qpsClass: .standard,
            allowedRegions: allowedRegions,
            killSwitchID: "a160-kill-switch",
            retryPolicyID: "a160-retry-policy"
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
