//
//  ServerProviderSearchAPILiveProviderInvocationEnvelopeTests.swift
//  kAirTests
//
//  A165 Search API live provider invocation envelope proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPILiveProviderInvocationEnvelopeTests: XCTestCase {

    func test_preparesMatchingAcceptedPreflightAndRemainsNonExecutable() throws {
        let preflight = acceptedPreflightDecision()
        let input = envelopeInput(preflightDecision: preflight)

        let decision = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: input
        )
        let repeated = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: input
        )

        assertSendable(input)
        assertSendable(decision)
        assertSendable(decision.safeCopy)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision.state, .prepared)
        XCTAssertTrue(decision.isPrepared)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
        XCTAssertFalse(decision.safeCopy.isRuntimeCallable)
        XCTAssertFalse(decision.safeCopy.isExecutable)
        XCTAssertEqual(decision.rejectionReasons, [])
        XCTAssertEqual(decision.summary?.id, "a165-envelope")
        XCTAssertEqual(decision.summary?.preflightID, "a160-preflight")
        XCTAssertEqual(decision.summary?.selectedAdapterID, "a160-adapter")
        XCTAssertEqual(decision.summary?.selectedVendorDecisionID, "a150-selection-a160-vendor")
        XCTAssertEqual(decision.summary?.selectedVendorID, "a160-vendor")
        XCTAssertEqual(decision.summary?.providerFamily, .searchAPI)
        XCTAssertEqual(decision.summary?.capability, .webSearch)
        XCTAssertEqual(decision.summary?.resultShape, .organicLinks)
        XCTAssertEqual(decision.summary?.freshness, .livePreferred)
        XCTAssertEqual(decision.summary?.searchContextClass, .compactContext)
        XCTAssertEqual(decision.summary?.pageContentRequirement, .snippetsOnly)
        XCTAssertEqual(decision.summary?.retentionClass, .ephemeralOnly)
        XCTAssertEqual(decision.summary?.sourceState, .passed)
        XCTAssertEqual(decision.summary?.region, .northAmerica)
        XCTAssertEqual(decision.summary?.membershipTier, .plus)
        XCTAssertEqual(decision.summary?.budgetSnapshotID, "a160-budget-snapshot")
        XCTAssertEqual(decision.summary?.costUnit, .request)
        XCTAssertEqual(decision.summary?.quotaRateClass, .standard)
        XCTAssertEqual(decision.summary?.transportLeaseID, "a122-lease")
        XCTAssertEqual(decision.summary?.transportRequestID, "a126-transport-request")
        XCTAssertEqual(decision.summary?.auditTraceID, "a140-audit-trace")
        XCTAssertEqual(decision.summary?.serverSecretMode, .serverOwned)
        XCTAssertEqual(decision.summary?.redactionPolicy, .sourceCitationMetadataOnly)
        XCTAssertEqual(decision.summary?.userFacingPurpose, "public-info lookup")
        XCTAssertTrue(decision.statusLine.contains("metadata only"))
        XCTAssertTrue(decision.statusLine.contains("provider path remains disabled"))
    }

    func test_rejectionMatrixPreservesDeterministicPreparedOnlyReasons() {
        let accepted = acceptedPreflightDecision()
        let rejectedPreflight = ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(
                adapterDecision: acceptedAdapterDecision(),
                privacyClass: .health
            )
        )

        let cases: [
            (
                id: String,
                input: ServerProviderSearchAPILiveProviderInvocationEnvelopeInput,
                expected: ServerProviderSearchAPILiveProviderInvocationEnvelopeRejectionReason
            )
        ] = [
            (
                "preflight not accepted",
                envelopeInput(preflightDecision: rejectedPreflight),
                .preflightNotAccepted
            ),
            (
                "expired preflight",
                envelopeInput(
                    preflightDecision: accepted,
                    preflightExpiresAt: Date(timeIntervalSince1970: 1_700)
                ),
                .staleOrExpiredPreflight
            ),
            (
                "adapter mismatch",
                envelopeInput(preflightDecision: accepted, selectedAdapterID: "other-adapter"),
                .vendorOrAdapterMismatch
            ),
            (
                "vendor mismatch",
                envelopeInput(preflightDecision: accepted, selectedVendorID: "other-vendor"),
                .vendorOrAdapterMismatch
            ),
            (
                "unsupported family",
                envelopeInput(preflightDecision: accepted, providerFamily: .mcp),
                .unsupportedProviderFamily
            ),
            (
                "capability mismatch",
                envelopeInput(preflightDecision: accepted, capability: .localServiceSearch),
                .capabilityMismatch
            ),
            (
                "result shape mismatch",
                envelopeInput(preflightDecision: accepted, resultShape: .answerSummary),
                .resultShapeMismatch
            ),
            (
                "freshness mismatch",
                envelopeInput(preflightDecision: accepted, freshness: .cachedOK),
                .freshnessMismatch
            ),
            (
                "search context mismatch",
                envelopeInput(preflightDecision: accepted, searchContextClass: .answerContext),
                .searchContextMismatch
            ),
            (
                "page content mismatch",
                envelopeInput(preflightDecision: accepted, pageContentRequirement: .required),
                .pageContentPolicyMismatch
            ),
            (
                "missing budget",
                envelopeInput(preflightDecision: accepted, budgetSnapshotID: ""),
                .missingBudgetSnapshot
            ),
            (
                "budget mismatch",
                envelopeInput(preflightDecision: accepted, budgetSnapshotID: "other-budget"),
                .budgetSnapshotMismatch
            ),
            (
                "cost unit mismatch",
                envelopeInput(preflightDecision: accepted, costUnit: .contextBlock),
                .costUnitMismatch
            ),
            (
                "missing lease id",
                envelopeInput(preflightDecision: accepted, transportLeaseID: ""),
                .missingLeaseRequestOrAuditID
            ),
            (
                "lease mismatch",
                envelopeInput(preflightDecision: accepted, transportLeaseID: "other-lease"),
                .leaseRequestOrAuditMismatch
            ),
            (
                "source policy unsafe",
                envelopeInput(preflightDecision: accepted, sourceState: .unknown),
                .unsafeSourceOrRetentionPolicy
            ),
            (
                "citation unsafe",
                envelopeInput(preflightDecision: accepted, citationRequired: false),
                .unsafeSourceOrRetentionPolicy
            ),
            (
                "retention unsafe",
                envelopeInput(preflightDecision: accepted, retentionClass: .shortTermCache),
                .unsafeSourceOrRetentionPolicy
            ),
            (
                "redaction unsafe",
                envelopeInput(preflightDecision: accepted, redactionPolicy: .unsafeUnredactedMaterial),
                .unsafeRedactionPolicy
            ),
            (
                "region unsupported",
                envelopeInput(preflightDecision: accepted, region: .europe),
                .unsupportedRegion
            ),
            (
                "quota unavailable",
                envelopeInput(preflightDecision: accepted, quotaRateClass: .unavailable),
                .quotaRateUnavailable
            ),
            (
                "server secret not owned",
                envelopeInput(preflightDecision: accepted, serverSecretMode: .clientProvided),
                .serverSecretModeNotServerOwned
            ),
            (
                "runtime callable",
                envelopeInput(preflightDecision: accepted, runtimeCallableFlag: true),
                .runtimeCallableFlagTrue
            ),
            (
                "executable",
                envelopeInput(preflightDecision: accepted, executableFlag: true),
                .executableFlagTrue
            ),
            (
                "unsafe commerce material",
                envelopeInput(preflightDecision: accepted, containsUnsafeCommerceMaterial: true),
                .unsafeCommerceMaterialPresent
            ),
            (
                "unredacted source material",
                envelopeInput(preflightDecision: accepted, containsUnredactedSourceMaterial: true),
                .unredactedSourceMaterialPresent
            ),
            (
                "hidden app control material",
                envelopeInput(preflightDecision: accepted, containsHiddenAppControlMaterial: true),
                .hiddenAppControlMaterialPresent
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
                input: testCase.input
            )
            let repeated = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
                input: testCase.input
            )

            XCTAssertEqual(decision, repeated, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertFalse(decision.isPrepared, testCase.id)
            XCTAssertFalse(decision.isRuntimeCallable, testCase.id)
            XCTAssertFalse(decision.isExecutable, testCase.id)
            XCTAssertFalse(decision.safeCopy.isRuntimeCallable, testCase.id)
            XCTAssertFalse(decision.safeCopy.isExecutable, testCase.id)
            XCTAssertTrue(decision.rejectionReasons.contains(testCase.expected), testCase.id)
            XCTAssertTrue(decision.statusLine.contains("envelope policy"), testCase.id)
            XCTAssertTrue(
                decision.statusLine.contains("provider path remains disabled"),
                testCase.id
            )
        }
    }

    func test_duplicateEnvelopeIDRejectsDeterministically() {
        let input = envelopeInput(preflightDecision: acceptedPreflightDecision())

        let decision = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: input,
            existingEnvelopeIDs: [input.envelopeID]
        )
        let repeated = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: input,
            existingEnvelopeIDs: [input.envelopeID]
        )

        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
        XCTAssertEqual(decision.rejectionReasons, [.duplicateEnvelopeID])
        XCTAssertEqual(decision.summary?.id, input.envelopeID)
    }

    func test_decisionAndSafeCopyAreCodableAndDoNotExposeRuntimeFields() throws {
        let accepted = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: envelopeInput(preflightDecision: acceptedPreflightDecision())
        )
        let rejected = ServerProviderSearchAPILiveProviderInvocationEnvelope.evaluate(
            input: envelopeInput(
                preflightDecision: acceptedPreflightDecision(),
                containsUnredactedSourceMaterial: true
            )
        )

        let encodedDecision = try encodedString(accepted)
        let decodedDecision = try JSONDecoder().decode(
            ServerProviderSearchAPILiveProviderInvocationEnvelopeDecision.self,
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
        XCTAssertTrue(text.contains("provider path remains disabled"))
        XCTAssertFalse(accepted.isRuntimeCallable)
        XCTAssertFalse(accepted.isExecutable)
        XCTAssertFalse(rejected.isRuntimeCallable)
        XCTAssertFalse(rejected.isExecutable)
        for fragment in forbiddenRuntimeFragments() {
            XCTAssertFalse(
                text.contains(fragment),
                "Unexpected envelope copy fragment: \(fragment)"
            )
        }
    }

    private func envelopeInput(
        preflightDecision: ServerProviderSearchAPILiveProviderInvocationPreflightDecision,
        envelopeID: String = "a165-envelope",
        preflightID: String = "a160-preflight",
        selectedAdapterID: String = "a160-adapter",
        selectedVendorDecisionID: String = "a150-selection-a160-vendor",
        selectedVendorID: String = "a160-vendor",
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks,
        freshness: ProviderFreshness = .livePreferred,
        searchContextClass: ServerProviderSearchAPILiveTransportAdapterSearchContextClass = .compactContext,
        pageContentRequirement: ServerProviderSearchAPIPageBodyRequirement = .snippetsOnly,
        retentionClass: ServerProviderSearchAPIRetentionLevel = .ephemeralOnly,
        sourceState: ServerSourcePolicyState = .passed,
        citationRequired: Bool = true,
        sourceHostRequired: Bool = true,
        attributionRequired: Bool = true,
        region: ProviderRegion = .northAmerica,
        membershipTier: MembershipTier = .plus,
        budgetSnapshotID: String = "a160-budget-snapshot",
        costUnit: ServerProviderSearchAPILiveVendorCostUnit = .request,
        quotaRateClass: ServerProviderSearchAPILiveVendorQPSClass = .standard,
        transportLeaseID: String = "a122-lease",
        transportRequestID: String = "a126-transport-request",
        auditTraceID: String = "a140-audit-trace",
        serverSecretMode: ServerProviderSearchAPILiveTransportAdapterSecretMode = .serverOwned,
        issuedAt: Date = Date(timeIntervalSince1970: 2_000),
        preflightExpiresAt: Date = Date(timeIntervalSince1970: 3_000),
        envelopeExpiresAt: Date = Date(timeIntervalSince1970: 2_600),
        redactionPolicy: ServerProviderSearchAPILiveProviderInvocationEnvelopeRedactionPolicy = .sourceCitationMetadataOnly,
        runtimeCallableFlag: Bool = false,
        executableFlag: Bool = false,
        containsUnsafeCommerceMaterial: Bool = false,
        containsUnredactedSourceMaterial: Bool = false,
        containsHiddenAppControlMaterial: Bool = false
    ) -> ServerProviderSearchAPILiveProviderInvocationEnvelopeInput {
        ServerProviderSearchAPILiveProviderInvocationEnvelopeInput(
            envelopeID: envelopeID,
            preflightID: preflightID,
            preflightDecision: preflightDecision,
            selectedAdapterID: selectedAdapterID,
            selectedVendorDecisionID: selectedVendorDecisionID,
            selectedVendorID: selectedVendorID,
            providerFamily: providerFamily,
            capability: capability,
            resultShape: resultShape,
            freshness: freshness,
            searchContextClass: searchContextClass,
            pageContentRequirement: pageContentRequirement,
            retentionClass: retentionClass,
            sourceState: sourceState,
            citationRequired: citationRequired,
            sourceHostRequired: sourceHostRequired,
            attributionRequired: attributionRequired,
            region: region,
            membershipTier: membershipTier,
            budgetSnapshotID: budgetSnapshotID,
            costUnit: costUnit,
            quotaRateClass: quotaRateClass,
            transportLeaseID: transportLeaseID,
            transportRequestID: transportRequestID,
            auditTraceID: auditTraceID,
            serverSecretMode: serverSecretMode,
            issuedAt: issuedAt,
            preflightExpiresAt: preflightExpiresAt,
            envelopeExpiresAt: envelopeExpiresAt,
            redactionPolicy: redactionPolicy,
            userFacingPurpose: "public-info lookup",
            runtimeCallableFlag: runtimeCallableFlag,
            executableFlag: executableFlag,
            containsUnsafeCommerceMaterial: containsUnsafeCommerceMaterial,
            containsUnredactedSourceMaterial: containsUnredactedSourceMaterial,
            containsHiddenAppControlMaterial: containsHiddenAppControlMaterial
        )
    }

    private func acceptedPreflightDecision() -> ServerProviderSearchAPILiveProviderInvocationPreflightDecision {
        ServerProviderSearchAPILiveProviderInvocationPreflight.evaluate(
            input: preflightInput(adapterDecision: acceptedAdapterDecision())
        )
    }

    private func preflightInput(
        adapterDecision: ServerProviderSearchAPILiveTransportAdapterInterfaceDecision,
        preflightID: String = "a160-preflight",
        selectedDescriptorID: String = "a160-adapter",
        selectedVendorDecisionID: String = "a150-selection-a160-vendor",
        selectedVendorID: String = "a160-vendor",
        leaseState: ServerProviderSearchAPILiveProviderInvocationLeaseState = .issued,
        region: ProviderRegion = .northAmerica,
        privacyClass: ProviderPrivacyClass = .general
    ) -> ServerProviderSearchAPILiveProviderInvocationPreflightInput {
        ServerProviderSearchAPILiveProviderInvocationPreflightInput(
            preflightID: preflightID,
            adapterInterfaceDecision: adapterDecision,
            selectedDescriptorID: selectedDescriptorID,
            selectedVendorDecisionID: selectedVendorDecisionID,
            selectedVendorID: selectedVendorID,
            meteredDecisionID: "a117-metered-decision",
            leaseID: "a122-lease",
            leaseMeteredDecisionID: "a117-metered-decision",
            leaseState: leaseState,
            transportRequestID: "a126-transport-request",
            transportLeaseID: "a122-lease",
            auditTraceID: "a140-audit-trace",
            auditTransportRequestID: "a126-transport-request",
            providerFamily: .searchAPI,
            capability: .webSearch,
            adapterResultShape: .organicLinks,
            adapterFreshness: .livePreferred,
            resultShape: .organicLinks,
            freshness: .livePreferred,
            costClass: .meteredPremium,
            costUnit: .request,
            searchContextClass: .compactContext,
            pageContentRequirement: .snippetsOnly,
            retentionClass: .ephemeralOnly,
            region: region,
            privacyClass: privacyClass,
            membershipTier: .plus,
            budgetSnapshotID: "a160-budget-snapshot",
            userFacingPurpose: "public-info lookup"
        )
    }

    private func acceptedAdapterDecision() -> ServerProviderSearchAPILiveTransportAdapterInterfaceDecision {
        ServerProviderSearchAPILiveTransportAdapterInterface.evaluate(
            request: interfaceRequest(),
            descriptors: [adapterDescriptor()]
        )
    }

    private func interfaceRequest(
        privacyClass: ProviderPrivacyClass = .general
    ) -> ServerProviderSearchAPILiveTransportAdapterInterfaceRequest {
        ServerProviderSearchAPILiveTransportAdapterInterfaceRequest(
            selectedVendorDecisionID: "a150-selection-a160-vendor",
            selectedVendorID: "a160-vendor",
            meteredDecisionID: "a117-metered-decision",
            leaseID: "a122-lease",
            transportRequestID: "a126-transport-request",
            auditTraceID: "a140-audit-trace",
            expectedResultShape: .organicLinks,
            expectedFreshness: .livePreferred,
            expectedCostClass: .meteredPremium,
            expectedCostUnit: .request,
            privacyClass: privacyClass,
            region: .northAmerica,
            userFacingPurpose: "public-info lookup"
        )
    }

    private func adapterDescriptor() -> ServerProviderSearchAPILiveTransportAdapterDescriptor {
        ServerProviderSearchAPILiveTransportAdapterDescriptor(
            id: "a160-adapter",
            vendorID: "a160-vendor",
            supportedResultShapes: [.organicLinks, .answerSummary],
            supportedFreshness: [.cachedOK, .livePreferred],
            costUnit: .request,
            searchContextClass: .compactContext,
            pageContentMode: .optional,
            retentionClass: .ephemeralOnly,
            citationSupport: .full,
            qpsClass: .standard,
            allowedRegions: [.global, .northAmerica],
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
