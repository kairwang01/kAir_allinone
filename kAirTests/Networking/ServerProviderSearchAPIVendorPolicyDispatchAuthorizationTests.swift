//
//  ServerProviderSearchAPIVendorPolicyDispatchAuthorizationTests.swift
//  kAirTests
//
//  A108 Search API vendor policy dispatch authorization proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIVendorPolicyDispatchAuthorizationTests: XCTestCase {

    func test_authorizedDispatchPreservesSafeMetadataWithoutTransportExecution() throws {
        let dispatchReceipt = try eligibleDispatchReceipt(
            traceID: "a108-authorized",
            sourceHost: "a108-authorized.example.com"
        )
        let vendorDecision = acceptedVendorDecision(
            vendorID: "a108-balanced-vendor",
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            resultShape: .organicLinks
        )

        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: dispatchReceipt,
            vendorDecision: vendorDecision,
            requestedResultShape: .organicLinks
        )
        let repeated = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: dispatchReceipt,
            vendorDecision: vendorDecision,
            requestedResultShape: .organicLinks
        )

        assertSendable(authorization)
        XCTAssertEqual(authorization, repeated)
        XCTAssertEqual(Set([authorization]).count, 1)
        XCTAssertTrue(authorization.isAuthorized)
        XCTAssertEqual(authorization.state, .authorized)
        XCTAssertNil(authorization.rejection)
        XCTAssertNil(authorization.dispatchRejection)
        XCTAssertNil(authorization.vendorPolicyRejection)
        XCTAssertEqual(authorization.dispatchReceiptID, dispatchReceipt.id)
        XCTAssertEqual(authorization.dispatchState, .dispatchEligible)
        XCTAssertEqual(authorization.vendorDecisionID, vendorDecision.id)
        XCTAssertEqual(authorization.vendorDecisionState, .accepted)
        XCTAssertEqual(authorization.vendorID, "a108-balanced-vendor")
        XCTAssertEqual(authorization.providerFamily, .searchAPI)
        XCTAssertEqual(authorization.capability, .webSearch)
        XCTAssertEqual(authorization.costClass, .meteredPremium)
        XCTAssertEqual(authorization.freshness, .livePreferred)
        XCTAssertEqual(authorization.resultShape, .organicLinks)
        XCTAssertTrue(authorization.statusLine.contains("verified metadata only"))
        XCTAssertTrue(authorization.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(authorization.description.contains("public coffee"))
    }

    func test_rejectionMatrixPreservesExplicitReasonsBeforeTransport() throws {
        let dispatchReceipt = try eligibleDispatchReceipt(
            traceID: "a108-matrix",
            sourceHost: "a108-matrix.example.com"
        )
        let vendorDecision = acceptedVendorDecision(
            vendorID: "a108-matrix-vendor",
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            resultShape: .organicLinks
        )
        let blockedDispatch = try blockedDispatchReceipt()
        let rejectedVendor = rejectedVendorDecision(vendorID: "a108-rejected-vendor")

        let cases: [
            (
                String,
                ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
                ServerProviderSearchAPIVendorPolicyDecision?,
                ServerProviderSearchAPIVendorResultShape,
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason
            )
        ] = [
            (
                "missing dispatch",
                nil,
                vendorDecision,
                .organicLinks,
                .missingDispatchReceipt
            ),
            (
                "blocked dispatch",
                blockedDispatch,
                vendorDecision,
                .organicLinks,
                .dispatchNotEligible
            ),
            (
                "missing vendor decision",
                dispatchReceipt,
                nil,
                .organicLinks,
                .missingVendorPolicyDecision
            ),
            (
                "rejected vendor decision",
                dispatchReceipt,
                rejectedVendor,
                .organicLinks,
                .vendorPolicyNotAccepted
            ),
            (
                "provider mismatch",
                dispatchReceipt,
                copy(vendorDecision, providerFamily: .googleMaps),
                .organicLinks,
                .providerFamilyMismatch
            ),
            (
                "capability mismatch",
                dispatchReceipt,
                copy(vendorDecision, capability: .localServiceSearch),
                .organicLinks,
                .capabilityMismatch
            ),
            (
                "cost mismatch",
                dispatchReceipt,
                copy(vendorDecision, costClass: .includedQuota),
                .organicLinks,
                .costClassMismatch
            ),
            (
                "freshness mismatch",
                dispatchReceipt,
                copy(vendorDecision, freshness: .cachedOK),
                .organicLinks,
                .freshnessMismatch
            ),
            (
                "result shape mismatch",
                dispatchReceipt,
                copy(vendorDecision, resultShape: .answerSummary),
                .organicLinks,
                .resultShapeMismatch
            ),
        ]

        for (id, dispatch, vendor, resultShape, expected) in cases {
            let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                dispatchReceipt: dispatch,
                vendorDecision: vendor,
                requestedResultShape: resultShape
            )

            XCTAssertFalse(authorization.isAuthorized, id)
            XCTAssertEqual(authorization.state, .rejected, id)
            XCTAssertEqual(authorization.rejection, expected, id)
            XCTAssertNil(authorization.providerFamily, id)
            XCTAssertNil(authorization.capability, id)
            XCTAssertNil(authorization.costClass, id)
            XCTAssertNil(authorization.freshness, id)
            XCTAssertNil(authorization.resultShape, id)
            XCTAssertTrue(authorization.statusLine.contains(expected.rawValue), id)
            XCTAssertTrue(
                authorization.statusLine.contains("No transport or provider runtime has run"),
                id
            )
        }
    }

    func test_rejectedAuthorizationPreservesNestedDispatchAndVendorReasons() throws {
        let blockedDispatch = try blockedDispatchReceipt()
        let rejectedVendor = rejectedVendorDecision(vendorID: "a108-private-vendor")

        let dispatchBlocked = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: blockedDispatch,
            vendorDecision: acceptedVendorDecision(vendorID: "a108-accepted-vendor"),
            requestedResultShape: .organicLinks
        )
        let vendorBlocked = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: try eligibleDispatchReceipt(),
            vendorDecision: rejectedVendor,
            requestedResultShape: .organicLinks
        )

        XCTAssertEqual(dispatchBlocked.rejection, .dispatchNotEligible)
        XCTAssertEqual(dispatchBlocked.dispatchRejection, .payloadDecisionRejected)
        XCTAssertEqual(dispatchBlocked.vendorDecisionState, .accepted)
        XCTAssertEqual(dispatchBlocked.vendorID, "a108-accepted-vendor")

        XCTAssertEqual(vendorBlocked.rejection, .vendorPolicyNotAccepted)
        XCTAssertEqual(vendorBlocked.dispatchState, .dispatchEligible)
        XCTAssertEqual(vendorBlocked.vendorDecisionState, .rejected)
        XCTAssertEqual(vendorBlocked.vendorPolicyRejection, .privacyBlocked)
        XCTAssertEqual(vendorBlocked.vendorID, "a108-private-vendor")
    }

    func test_authorizationEncodingAndDebugCopyDoNotLeakSensitiveRuntimeFields() throws {
        let dispatchReceipt = try eligibleDispatchReceipt()
        let accepted = acceptedVendorDecision(vendorID: "safe-vendor")
        let rejected = rejectedVendorDecision(vendorID: "blocked-vendor")
        let authorized = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: dispatchReceipt,
            vendorDecision: accepted,
            requestedResultShape: .organicLinks
        )
        let blocked = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: dispatchReceipt,
            vendorDecision: rejected,
            requestedResultShape: .organicLinks
        )
        let text = [
            try encodedString(authorized),
            try encodedString(blocked),
            authorized.description,
            blocked.description,
            authorized.statusLine,
            blocked.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected authorization wording: \(forbidden)")
        }
    }

    private func eligibleDispatchReceipt(
        traceID: String = "a108-dispatch",
        sourceHost: String = "a108.example.com",
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: traceID,
            sourceHost: sourceHost,
            capability: capability,
            costClass: costClass,
            freshness: freshness
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )

        XCTAssertEqual(payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(receipt.state, .dispatchEligible)
        XCTAssertTrue(receipt.isDispatchEligible)
        return receipt
    }

    private func blockedDispatchReceipt() throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: "a108-blocked-baseline",
            sourceHost: "a108-blocked-baseline.example.com"
        )
        let rejectedPayloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(
                    traceID: "a108-blocked-private",
                    privacyClass: .private,
                    sourceHost: "a108-blocked-private.example.com"
                ),
                connectorReceipt: connectorReceipt(traceID: "a108-blocked-private"),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: rejectedPayloadDecision,
            request: request
        )

        XCTAssertEqual(rejectedPayloadDecision.state, .rejected)
        XCTAssertEqual(rejectedPayloadDecision.rejection, .requestDecisionRejected)
        XCTAssertEqual(rejectedPayloadDecision.requestDecisionRejection, .privacyBlocked)
        XCTAssertEqual(receipt.state, .blocked)
        XCTAssertFalse(receipt.isDispatchEligible)
        return receipt
    }

    private func preparedRequest(
        traceID: String,
        sourceHost: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(
                traceID: traceID,
                capability: capability,
                costClass: costClass,
                freshness: freshness,
                sourceHost: sourceHost
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                capability: capability,
                costClass: costClass,
                freshness: freshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        return try XCTUnwrap(decision.request)
    }

    private func acceptedVendorDecision(
        vendorID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: providerFamily,
                capability: capability,
                privacyClass: .general,
                costClass: costClass,
                freshness: freshness,
                citationRequired: true,
                sourceHostRequired: true,
                pageBodyRequirement: .snippetsOnly,
                allowedRetention: .ephemeralOnly,
                resultShape: resultShape,
                quotaSnapshot: quotaSnapshot(for: costClass)
            ),
            vendor: vendorPolicy(
                id: vendorID,
                costClass: costClass,
                supportedFreshness: [.cachedOK, .livePreferred, .liveRequired],
                supportedResultShapes: [.organicLinks, .answerSummary, .documentSnippets]
            )
        )
        XCTAssertEqual(decision.state, .accepted)
        return decision
    }

    private func rejectedVendorDecision(
        vendorID: String
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: .searchAPI,
                capability: .webSearch,
                privacyClass: .private,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                citationRequired: true,
                sourceHostRequired: true,
                pageBodyRequirement: .snippetsOnly,
                allowedRetention: .ephemeralOnly,
                resultShape: .organicLinks,
                quotaSnapshot: quotaSnapshot(for: .meteredPremium)
            ),
            vendor: vendorPolicy(id: vendorID, costClass: .meteredPremium)
        )
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertEqual(decision.rejection, .privacyBlocked)
        return decision
    }

    private func vendorPolicy(
        id: String,
        costClass: ProviderCostClass,
        supportedFreshness: Set<ProviderFreshness> = [.cachedOK, .livePreferred, .liveRequired],
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
            .documentSnippets,
        ]
    ) -> ServerProviderSearchAPIVendorPolicyDescriptor {
        ServerProviderSearchAPIVendorPolicyDescriptor(
            id: id,
            costClass: costClass,
            supportedFreshness: supportedFreshness,
            citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                supportsCitations: true,
                supportsSourceHost: true,
                supportsAttribution: true
            ),
            pageBodyMode: .optional,
            requiredRetention: .ephemeralOnly,
            supportedResultShapes: supportedResultShapes
        )
    }

    private func quotaSnapshot(
        for costClass: ProviderCostClass
    ) -> ServerProviderQuotaSnapshot {
        switch costClass {
        case .includedQuota:
            return ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                remainingIncludedQuota: [.searchAPI: 2]
            )
        case .meteredPremium:
            return ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                meteredEligibleProviderFamilies: [.searchAPI]
            )
        case .freeLocal, .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return ServerProviderQuotaSnapshot()
        }
    }

    private func searchEnvelope(
        traceID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        sourceHost: String
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: privacyClass,
            membershipTier: .plus,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                attributionRequired: true,
                sourceHost: sourceHost
            ),
            confirmationState: .notRequired,
            meteredProviderEntitlements: [.searchAPI],
            enabledExperimentalProviders: []
        )
    }

    private func connectorReceipt(
        traceID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a108-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A108 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a108-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: providerFamily,
            requestID: "a108-connector-request-\(traceID)",
            resultID: "a108-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a108-authorization-\(traceID)",
            boundaryID: "a108-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func copy(
        _ decision: ServerProviderSearchAPIVendorPolicyDecision,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil,
        freshness: ProviderFreshness? = nil,
        resultShape: ServerProviderSearchAPIVendorResultShape? = nil
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        ServerProviderSearchAPIVendorPolicyDecision(
            id: "\(decision.id)-copy",
            state: decision.state,
            vendorID: decision.vendorID,
            providerFamily: providerFamily ?? decision.providerFamily,
            capability: capability ?? decision.capability,
            costClass: costClass ?? decision.costClass,
            freshness: freshness ?? decision.freshness,
            resultShape: resultShape ?? decision.resultShape,
            statusLine: decision.statusLine,
            rejection: decision.rejection
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
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "healthkit",
            "blood",
            "secret",
            "merchant",
            "order",
            "pay" + "ment",
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
