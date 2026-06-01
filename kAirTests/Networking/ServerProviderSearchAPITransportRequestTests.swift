//
//  ServerProviderSearchAPITransportRequestTests.swift
//  kAirTests
//
//  A126 Search API transport request contract proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPITransportRequestTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_issuedMeteredLeasePreparesDeterministicRequestWithoutRuntimeExecution() throws {
        let chain = try transportChain(
            traceID: "a126-issued",
            sourceHost: "a126-issued.example.com",
            vendorID: "a126-issued-vendor"
        )

        let decision = ServerProviderSearchAPITransportRequestBuilder.prepare(
            requestDecision: chain.requestDecision,
            payloadDecision: chain.payloadDecision,
            dispatchReceipt: chain.dispatchReceipt,
            vendorDecision: chain.vendorDecision,
            authorization: chain.authorization,
            lease: chain.lease,
            budgetContext: chain.budgetContext
        )
        let repeated = ServerProviderSearchAPITransportRequestBuilder.prepare(
            requestDecision: chain.requestDecision,
            payloadDecision: chain.payloadDecision,
            dispatchReceipt: chain.dispatchReceipt,
            vendorDecision: chain.vendorDecision,
            authorization: chain.authorization,
            lease: chain.lease,
            budgetContext: chain.budgetContext
        )
        let request = try XCTUnwrap(decision.request)

        assertSendable(decision)
        assertSendable(request)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertTrue(decision.isPrepared)
        XCTAssertEqual(decision.state, .requestPrepared)
        XCTAssertNil(decision.rejection)
        XCTAssertNil(decision.requestDecisionRejection)
        XCTAssertNil(decision.payloadDecisionRejection)
        XCTAssertNil(decision.dispatchReceiptRejection)
        XCTAssertNil(decision.vendorPolicyRejection)
        XCTAssertNil(decision.authorizationRejection)
        XCTAssertNil(decision.leaseRejection)

        XCTAssertEqual(request.requestID, chain.request.id)
        XCTAssertEqual(request.payloadDecisionID, chain.payloadDecision.id)
        XCTAssertEqual(request.payloadID, chain.payload.id)
        XCTAssertEqual(request.dispatchReceiptID, chain.dispatchReceipt.id)
        XCTAssertEqual(request.vendorDecisionID, chain.vendorDecision.id)
        XCTAssertEqual(request.authorizationID, chain.authorization.id)
        XCTAssertEqual(request.leaseID, chain.lease.id)
        XCTAssertEqual(request.budgetID, chain.budgetContext.id)
        XCTAssertEqual(request.meteredDecisionID, chain.budgetContext.meteredDecisionID)
        XCTAssertEqual(request.providerFamily, .searchAPI)
        XCTAssertEqual(request.vendorID, "a126-issued-vendor")
        XCTAssertEqual(request.capability, .webSearch)
        XCTAssertEqual(request.costClass, .meteredPremium)
        XCTAssertEqual(request.freshness, .livePreferred)
        XCTAssertEqual(request.resultShape, .organicLinks)
        XCTAssertEqual(request.resultLimit, 4)
        XCTAssertEqual(request.sourceCitationSummary.sourceState, .passed)
        XCTAssertEqual(request.sourceCitationSummary.robotsState, .notApplicable)
        XCTAssertTrue(request.sourceCitationSummary.attributionRequired)
        XCTAssertTrue(request.sourceCitationSummary.citationRequired)
        XCTAssertTrue(request.sourceCitationSummary.sourceHostRequired)
        XCTAssertTrue(request.statusLine.contains("lease-bound metadata only"))
        XCTAssertTrue(request.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(request.description.contains("public coffee"))
        XCTAssertFalse(request.description.contains("a126-issued.example.com"))
    }

    func test_rejectionMatrixBlocksMissingRejectedAndGenericInputs() throws {
        let chain = try transportChain(
            traceID: "a126-matrix",
            sourceHost: "a126-matrix.example.com",
            vendorID: "a126-matrix-vendor"
        )
        let genericBudget = ServerProviderSearchAPITransportBudgetContext(
            id: "a126-generic-budget",
            quotaSnapshot: ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                meteredEligibleProviderFamilies: [.searchAPI]
            ),
            allowedCostClasses: [.meteredPremium]
        )
        let genericLease = copy(chain.lease, budgetID: genericBudget.id)
        let rejectedLease = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: chain.payloadDecision,
            dispatchReceipt: chain.dispatchReceipt,
            authorization: nil,
            requestedResultShape: .organicLinks,
            budgetContext: chain.budgetContext
        )
        let rejectedRequestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(
                traceID: "a126-rejected-request",
                privacyClass: .private,
                sourceHost: "a126-rejected-request.example.com"
            ),
            connectorReceipt: connectorReceipt(traceID: "a126-rejected-request"),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        let rejectedPayloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: rejectedRequestDecision
        )
        let blockedDispatch = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: rejectedPayloadDecision,
            request: chain.request
        )
        let rejectedVendor = rejectedVendorDecision(vendorID: "a126-rejected-vendor")
        let rejectedAuthorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate
            .authorize(
                dispatchReceipt: chain.dispatchReceipt,
                vendorDecision: rejectedVendor,
                requestedResultShape: .organicLinks
            )

        XCTAssertEqual(rejectedRequestDecision.state, .rejected)
        XCTAssertEqual(rejectedPayloadDecision.state, .rejected)
        XCTAssertEqual(blockedDispatch.state, .blocked)
        XCTAssertEqual(rejectedVendor.state, .rejected)
        XCTAssertEqual(rejectedAuthorization.state, .rejected)

        let cases: [
            (
                id: String,
                requestDecision: ServerProviderSearchAPIAdapterRequestDecision?,
                payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision?,
                dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
                vendorDecision: ServerProviderSearchAPIVendorPolicyDecision?,
                authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization?,
                lease: ServerProviderSearchAPITransportLease?,
                budgetContext: ServerProviderSearchAPITransportBudgetContext?,
                expected: ServerProviderSearchAPITransportRequestRejectionReason
            )
        ] = [
            (
                "missing lease",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                nil,
                chain.budgetContext,
                .missingLease
            ),
            (
                "rejected lease",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                rejectedLease,
                chain.budgetContext,
                .leaseNotIssued
            ),
            (
                "missing budget context",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                nil,
                .missingBudgetContext
            ),
            (
                "generic budget",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                genericLease,
                genericBudget,
                .missingMeteredDecisionID
            ),
            (
                "missing request decision",
                nil,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .missingRequestDecision
            ),
            (
                "rejected request decision",
                rejectedRequestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .requestDecisionRejected
            ),
            (
                "missing request",
                copy(chain.requestDecision, request: nil),
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .missingRequest
            ),
            (
                "missing payload decision",
                chain.requestDecision,
                nil,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .missingPayloadDecision
            ),
            (
                "rejected payload decision",
                chain.requestDecision,
                rejectedPayloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .payloadNotPrepared
            ),
            (
                "missing payload",
                chain.requestDecision,
                copy(chain.payloadDecision, payload: nil),
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .missingPayload
            ),
            (
                "missing dispatch",
                chain.requestDecision,
                chain.payloadDecision,
                nil,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .missingDispatchReceipt
            ),
            (
                "blocked dispatch",
                chain.requestDecision,
                chain.payloadDecision,
                blockedDispatch,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .dispatchNotEligible
            ),
            (
                "missing vendor",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                nil,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .missingVendorPolicyDecision
            ),
            (
                "rejected vendor",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                rejectedVendor,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .vendorPolicyNotAccepted
            ),
            (
                "missing authorization",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                nil,
                chain.lease,
                chain.budgetContext,
                .missingAuthorization
            ),
            (
                "rejected authorization",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                rejectedAuthorization,
                chain.lease,
                chain.budgetContext,
                .authorizationNotAccepted
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPITransportRequestBuilder.prepare(
                requestDecision: testCase.requestDecision,
                payloadDecision: testCase.payloadDecision,
                dispatchReceipt: testCase.dispatchReceipt,
                vendorDecision: testCase.vendorDecision,
                authorization: testCase.authorization,
                lease: testCase.lease,
                budgetContext: testCase.budgetContext
            )

            XCTAssertFalse(decision.isPrepared, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertNil(decision.request, testCase.id)
            XCTAssertEqual(decision.rejection, testCase.expected, testCase.id)
            XCTAssertTrue(decision.statusLine.contains(testCase.expected.rawValue), testCase.id)
            XCTAssertTrue(
                decision.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
        }
    }

    func test_metadataMismatchesRejectBeforeTransportRequest() throws {
        let chain = try transportChain(
            traceID: "a126-mismatch",
            sourceHost: "a126-mismatch.example.com",
            vendorID: "a126-mismatch-vendor"
        )
        let alternateSourcePolicy = sourcePolicy(
            sourceState: .passed,
            attributionRequired: true,
            sourceHost: "a126-other-source.example.com"
        )
        let missingCitationPolicy = sourcePolicy(
            sourceState: .passed,
            attributionRequired: true,
            citationRequired: false,
            sourceHost: "a126-mismatch.example.com"
        )
        let noCitationRequest = copy(chain.request, sourcePolicy: missingCitationPolicy)
        let noCitationPayload = copy(chain.payload, sourcePolicy: missingCitationPolicy)
        let noCitationPayloadDecision = copy(
            chain.payloadDecision,
            payload: noCitationPayload
        )
        let noCitationDispatch = copy(
            chain.dispatchReceipt,
            sourcePolicy: missingCitationPolicy
        )
        let noCitationLease = copy(chain.lease, citationRequired: false)

        let cases: [
            (
                id: String,
                requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
                payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
                dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
                vendorDecision: ServerProviderSearchAPIVendorPolicyDecision,
                authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
                lease: ServerProviderSearchAPITransportLease,
                budgetContext: ServerProviderSearchAPITransportBudgetContext,
                expected: ServerProviderSearchAPITransportRequestRejectionReason
            )
        ] = [
            (
                "request payload mismatch",
                chain.requestDecision,
                copy(
                    chain.payloadDecision,
                    requestID: "a126-other-request",
                    payload: chain.payload
                ),
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .requestPayloadMismatch
            ),
            (
                "request dispatch mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                copy(chain.dispatchReceipt, requestID: "a126-other-request"),
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .requestDispatchMismatch
            ),
            (
                "dispatch authorization mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                copy(chain.authorization, dispatchReceiptID: "a126-other-dispatch"),
                chain.lease,
                chain.budgetContext,
                .dispatchAuthorizationMismatch
            ),
            (
                "vendor authorization mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                copy(chain.authorization, vendorDecisionID: "a126-other-vendor-decision"),
                chain.lease,
                chain.budgetContext,
                .vendorAuthorizationMismatch
            ),
            (
                "lease payload mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, payloadID: "a126-other-payload"),
                chain.budgetContext,
                .leasePayloadMismatch
            ),
            (
                "lease dispatch mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, dispatchReceiptID: "a126-other-dispatch"),
                chain.budgetContext,
                .leaseDispatchMismatch
            ),
            (
                "lease authorization mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, authorizationID: "a126-other-authorization"),
                chain.budgetContext,
                .leaseAuthorizationMismatch
            ),
            (
                "provider mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, providerFamily: .googleMaps),
                chain.budgetContext,
                .providerFamilyMismatch
            ),
            (
                "vendor mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, vendorID: "a126-other-vendor"),
                chain.budgetContext,
                .vendorMismatch
            ),
            (
                "capability mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, capability: .localServiceSearch),
                chain.budgetContext,
                .capabilityMismatch
            ),
            (
                "cost mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, costClass: .includedQuota),
                chain.budgetContext,
                .costClassMismatch
            ),
            (
                "freshness mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, freshness: .cachedOK),
                chain.budgetContext,
                .freshnessMismatch
            ),
            (
                "result shape mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, resultShape: .answerSummary),
                chain.budgetContext,
                .resultShapeMismatch
            ),
            (
                "result limit mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                chain.dispatchReceipt,
                chain.vendorDecision,
                chain.authorization,
                copy(chain.lease, resultLimit: 3),
                chain.budgetContext,
                .resultLimitMismatch
            ),
            (
                "source policy mismatch",
                chain.requestDecision,
                chain.payloadDecision,
                copy(chain.dispatchReceipt, sourcePolicy: alternateSourcePolicy),
                chain.vendorDecision,
                chain.authorization,
                chain.lease,
                chain.budgetContext,
                .sourcePolicyMismatch
            ),
            (
                "citation policy missing",
                copy(chain.requestDecision, request: noCitationRequest),
                noCitationPayloadDecision,
                noCitationDispatch,
                chain.vendorDecision,
                chain.authorization,
                noCitationLease,
                chain.budgetContext,
                .citationPolicyMissing
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPITransportRequestBuilder.prepare(
                requestDecision: testCase.requestDecision,
                payloadDecision: testCase.payloadDecision,
                dispatchReceipt: testCase.dispatchReceipt,
                vendorDecision: testCase.vendorDecision,
                authorization: testCase.authorization,
                lease: testCase.lease,
                budgetContext: testCase.budgetContext
            )

            XCTAssertFalse(decision.isPrepared, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertEqual(decision.rejection, testCase.expected, testCase.id)
            XCTAssertNil(decision.request, testCase.id)
            XCTAssertTrue(decision.statusLine.contains(testCase.expected.rawValue), testCase.id)
        }
    }

    func test_encodingAndDebugCopyDoNotLeakSensitiveRuntimeFields() throws {
        let chain = try transportChain(
            traceID: "a126-copy",
            sourceHost: "a126-copy.example.com",
            vendorID: "a126-copy-vendor"
        )
        let prepared = ServerProviderSearchAPITransportRequestBuilder.prepare(
            requestDecision: chain.requestDecision,
            payloadDecision: chain.payloadDecision,
            dispatchReceipt: chain.dispatchReceipt,
            vendorDecision: chain.vendorDecision,
            authorization: chain.authorization,
            lease: chain.lease,
            budgetContext: chain.budgetContext
        )
        let rejected = ServerProviderSearchAPITransportRequestBuilder.prepare(
            requestDecision: chain.requestDecision,
            payloadDecision: chain.payloadDecision,
            dispatchReceipt: chain.dispatchReceipt,
            vendorDecision: chain.vendorDecision,
            authorization: chain.authorization,
            lease: copy(chain.lease, resultLimit: 3),
            budgetContext: chain.budgetContext
        )
        let text = [
            try encodedString(prepared),
            try encodedString(rejected),
            prepared.description,
            rejected.description,
            prepared.statusLine,
            rejected.statusLine,
            prepared.request?.description ?? "",
            prepared.request?.statusLine ?? "",
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("a126-copy.example.com"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected request wording: \(forbidden)")
        }
    }

    private struct TransportChain {
        let requestDecision: ServerProviderSearchAPIAdapterRequestDecision
        let request: ServerProviderSearchAPIAdapterRequest
        let payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision
        let payload: ServerProviderSearchAPIAdapterTransportPayload
        let dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
        let vendorDecision: ServerProviderSearchAPIVendorPolicyDecision
        let authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
        let budgetContext: ServerProviderSearchAPITransportBudgetContext
        let lease: ServerProviderSearchAPITransportLease
    }

    private func transportChain(
        traceID: String,
        sourceHost: String,
        vendorID: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks
    ) throws -> TransportChain {
        let requestDecision = preparedRequestDecision(
            traceID: traceID,
            sourceHost: sourceHost,
            capability: capability,
            costClass: costClass,
            freshness: freshness
        )
        let request = try XCTUnwrap(requestDecision.request)
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: request
        )
        let payload = try XCTUnwrap(payloadDecision.payload)
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate
            .evaluate(payloadDecision: payloadDecision, request: request)
        let vendorDecision = acceptedVendorDecision(
            vendorID: vendorID,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            resultShape: resultShape
        )
        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate
            .authorize(
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision,
                requestedResultShape: resultShape
            )
        let meteredDecision = meteredUsageDecision(
            id: traceID,
            vendorID: vendorID,
            capability: capability,
            costClass: costClass,
            freshness: freshness
        )
        let budgetContext = try XCTUnwrap(
            meteredDecision.transportBudgetContext(id: "\(traceID)-budget")
        )
        let lease = ServerProviderSearchAPITransportLeaseGate.evaluate(
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt,
            authorization: authorization,
            requestedResultShape: resultShape,
            budgetContext: budgetContext
        )

        XCTAssertEqual(requestDecision.state, .requestPrepared)
        XCTAssertEqual(payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(dispatchReceipt.state, .dispatchEligible)
        XCTAssertEqual(vendorDecision.state, .accepted)
        XCTAssertEqual(authorization.state, .authorized)
        XCTAssertEqual(meteredDecision.state, .accepted)
        XCTAssertEqual(lease.state, .issued)

        return TransportChain(
            requestDecision: requestDecision,
            request: request,
            payloadDecision: payloadDecision,
            payload: payload,
            dispatchReceipt: dispatchReceipt,
            vendorDecision: vendorDecision,
            authorization: authorization,
            budgetContext: budgetContext,
            lease: lease
        )
    }

    private func preparedRequestDecision(
        traceID: String,
        sourceHost: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderSearchAPIAdapterRequestDecision {
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
        return decision
    }

    private func acceptedVendorDecision(
        vendorID: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: .searchAPI,
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
                supportedResultShapes: [
                    .organicLinks,
                    .answerSummary,
                    .documentSnippets,
                ]
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
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
            .documentSnippets,
        ]
    ) -> ServerProviderSearchAPIVendorPolicyDescriptor {
        ServerProviderSearchAPIVendorPolicyDescriptor(
            id: id,
            costClass: costClass,
            supportedFreshness: [.cachedOK, .livePreferred, .liveRequired],
            citationSupport: .full,
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
                remainingIncludedQuota: [.searchAPI: 20]
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

    private func meteredUsageDecision(
        id: String,
        vendorID: String,
        capability: ProviderCapability = .webSearch,
        estimatedUnits: Int = 4,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderMeteredUsageDecision {
        ServerProviderMeteredEntitlementLedger.evaluate(
            request: ServerProviderMeteredUsageRequest(
                id: id,
                traceID: "\(id)-trace",
                providerFamily: .searchAPI,
                vendorID: vendorID,
                capability: capability,
                estimatedUnits: estimatedUnits,
                costClass: costClass,
                privacyClass: .general,
                freshness: freshness,
                membershipTier: .plus,
                currencyCode: "usd",
                unitLabel: "search-unit",
                userFacingReason: "public-info lookup"
            ),
            snapshot: ServerProviderMeteredEntitlementSnapshot(
                id: "\(id)-snapshot",
                providerFamily: .searchAPI,
                vendorID: vendorID,
                capability: capability,
                costClass: costClass,
                isVendorEnabled: true,
                membershipTier: .plus,
                minimumMembershipTier: .plus,
                hasEntitlement: true,
                quotaPeriodID: "a126-2026-05",
                includedUnits: 100,
                usedUnits: 12,
                reservedUnits: 8,
                remainingUnits: 40,
                currencyCode: "usd",
                unitLabel: "search-unit",
                sourceTimestamp: now,
                staleAfter: 600
            ),
            now: now
        )
    }

    private func searchEnvelope(
        traceID: String,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        sourceHost: String
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: .searchAPI,
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
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a126-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A126 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a126-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a126-connector-request-\(traceID)",
            resultID: "a126-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a126-authorization-\(traceID)",
            boundaryID: "a126-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func sourcePolicy(
        sourceState: ServerSourcePolicyState,
        attributionRequired: Bool,
        citationRequired: Bool = true,
        sourceHost: String
    ) -> ServerProviderSearchAPIAdapterSourcePolicySnapshot {
        ServerProviderSearchAPIAdapterSourcePolicySnapshot(
            sourcePolicy: ServerSourcePolicy(
                sourceState: sourceState,
                attributionRequired: attributionRequired,
                sourceHost: sourceHost
            ),
            citationRequired: citationRequired
        )
    }

    private func copy(
        _ decision: ServerProviderSearchAPIAdapterRequestDecision,
        request: ServerProviderSearchAPIAdapterRequest?
    ) -> ServerProviderSearchAPIAdapterRequestDecision {
        ServerProviderSearchAPIAdapterRequestDecision(
            id: decision.id,
            state: decision.state,
            statusLine: decision.statusLine,
            request: request,
            rejection: decision.rejection
        )
    }

    private func copy(
        _ request: ServerProviderSearchAPIAdapterRequest,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot
    ) -> ServerProviderSearchAPIAdapterRequest {
        ServerProviderSearchAPIAdapterRequest(
            id: request.id,
            traceID: request.traceID,
            envelopeTraceID: request.envelopeTraceID,
            connectorReceiptID: request.connectorReceiptID,
            connectorRequestID: request.connectorRequestID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            costClass: request.costClass,
            freshness: request.freshness,
            resultLimit: request.resultLimit,
            query: request.query,
            quotaSummary: request.quotaSummary,
            accessSummary: request.accessSummary,
            sourcePolicy: sourcePolicy
        )
    }

    private func copy(
        _ decision: ServerProviderSearchAPIAdapterPayloadDecision,
        requestID: String? = nil,
        payload: ServerProviderSearchAPIAdapterTransportPayload?
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        ServerProviderSearchAPIAdapterPayloadDecision(
            id: decision.id,
            state: decision.state,
            statusLine: decision.statusLine,
            requestID: requestID ?? decision.requestID,
            payload: payload,
            rejection: decision.rejection,
            requestDecisionRejection: decision.requestDecisionRejection
        )
    }

    private func copy(
        _ payload: ServerProviderSearchAPIAdapterTransportPayload,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot
    ) -> ServerProviderSearchAPIAdapterTransportPayload {
        ServerProviderSearchAPIAdapterTransportPayload(
            id: payload.id,
            requestID: payload.requestID,
            traceID: payload.traceID,
            providerFamily: payload.providerFamily,
            capability: payload.capability,
            costClass: payload.costClass,
            freshness: payload.freshness,
            resultLimit: payload.resultLimit,
            query: payload.query,
            sourcePolicy: sourcePolicy
        )
    }

    private func copy(
        _ receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        requestID: String? = nil,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot? = nil
    ) -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        ServerProviderSearchAPIAdapterPayloadDispatchReceipt(
            id: receipt.id,
            state: receipt.state,
            statusLine: receipt.statusLine,
            payloadDecisionID: receipt.payloadDecisionID,
            payloadID: receipt.payloadID,
            requestID: requestID ?? receipt.requestID,
            traceID: receipt.traceID,
            providerFamily: receipt.providerFamily,
            capability: receipt.capability,
            freshness: receipt.freshness,
            costClass: receipt.costClass,
            resultLimit: receipt.resultLimit,
            sourcePolicy: sourcePolicy ?? receipt.sourcePolicy,
            rejection: receipt.rejection,
            payloadDecisionRejection: receipt.payloadDecisionRejection,
            requestDecisionRejection: receipt.requestDecisionRejection
        )
    }

    private func copy(
        _ authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
        dispatchReceiptID: String? = nil,
        vendorDecisionID: String? = nil
    ) -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        ServerProviderSearchAPIVendorPolicyDispatchAuthorization(
            id: "\(authorization.id)-copy",
            state: authorization.state,
            statusLine: authorization.statusLine,
            dispatchReceiptID: dispatchReceiptID ?? authorization.dispatchReceiptID,
            dispatchState: authorization.dispatchState,
            dispatchRejection: authorization.dispatchRejection,
            vendorDecisionID: vendorDecisionID ?? authorization.vendorDecisionID,
            vendorDecisionState: authorization.vendorDecisionState,
            vendorPolicyRejection: authorization.vendorPolicyRejection,
            vendorID: authorization.vendorID,
            providerFamily: authorization.providerFamily,
            capability: authorization.capability,
            costClass: authorization.costClass,
            freshness: authorization.freshness,
            resultShape: authorization.resultShape,
            rejection: authorization.rejection
        )
    }

    private func copy(
        _ lease: ServerProviderSearchAPITransportLease,
        payloadID: String? = nil,
        dispatchReceiptID: String? = nil,
        authorizationID: String? = nil,
        budgetID: String? = nil,
        vendorID: String? = nil,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil,
        freshness: ProviderFreshness? = nil,
        resultShape: ServerProviderSearchAPIVendorResultShape? = nil,
        resultLimit: Int? = nil,
        citationRequired: Bool? = nil
    ) -> ServerProviderSearchAPITransportLease {
        ServerProviderSearchAPITransportLease(
            id: "\(lease.id)-copy",
            state: lease.state,
            statusLine: lease.statusLine,
            payloadDecisionID: lease.payloadDecisionID,
            payloadID: payloadID ?? lease.payloadID,
            dispatchReceiptID: dispatchReceiptID ?? lease.dispatchReceiptID,
            authorizationID: authorizationID ?? lease.authorizationID,
            budgetID: budgetID ?? lease.budgetID,
            vendorID: vendorID ?? lease.vendorID,
            providerFamily: providerFamily ?? lease.providerFamily,
            capability: capability ?? lease.capability,
            costClass: costClass ?? lease.costClass,
            freshness: freshness ?? lease.freshness,
            resultShape: resultShape ?? lease.resultShape,
            resultLimit: resultLimit ?? lease.resultLimit,
            sourceState: lease.sourceState,
            citationRequired: citationRequired ?? lease.citationRequired,
            rejection: lease.rejection,
            payloadRejection: lease.payloadRejection,
            dispatchRejection: lease.dispatchRejection,
            authorizationRejection: lease.authorizationRejection
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
            "urlsession",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "oa" + "uth",
            "s" + "dk",
            "raw" + "query",
            "raw" + "prompt",
            "raw prompt",
            "raw" + " page",
            "raw" + "content",
            "raw" + "source",
            "hea" + "lthkit",
            "blood",
            "secret",
            "merchant",
            "order",
            "pay" + "ment",
            "provider" + " raw",
            "crawler",
            "mcp",
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
