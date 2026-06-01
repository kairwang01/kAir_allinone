//
//  ServerProviderSearchAPITransportResponseTests.swift
//  kAirTests
//
//  A131 Search API transport response receipt contract proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPITransportResponseTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_preparedRequestAndNormalizedResultAcceptDeterministicResponseWithoutRuntimeExecution() throws {
        let chain = try transportChain(
            traceID: "a131-accepted",
            sourceHost: "a131-accepted.example.com",
            vendorID: "a131-accepted-vendor"
        )
        let resultReceipt = try normalizedResultReceipt(
            for: chain.request,
            sourceHost: "a131-accepted.example.com",
            freshness: chain.transportRequest.freshness
        )

        let decision = ServerProviderSearchAPITransportResponseBuilder.accept(
            transportRequestDecision: chain.transportRequestDecision,
            adapterResultReceipt: resultReceipt
        )
        let repeated = ServerProviderSearchAPITransportResponseBuilder.accept(
            transportRequestDecision: chain.transportRequestDecision,
            adapterResultReceipt: resultReceipt
        )
        let response = try XCTUnwrap(decision.response)

        assertSendable(decision)
        assertSendable(response)
        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertTrue(decision.isAccepted)
        XCTAssertEqual(decision.state, .responseAccepted)
        XCTAssertNil(decision.rejection)
        XCTAssertNil(decision.transportRequestRejection)
        XCTAssertNil(decision.adapterResultRejection)

        XCTAssertEqual(response.transportRequestID, chain.transportRequest.id)
        XCTAssertEqual(response.adapterResultReceiptID, resultReceipt.id)
        XCTAssertEqual(response.requestID, chain.transportRequest.requestID)
        XCTAssertEqual(response.payloadDecisionID, chain.transportRequest.payloadDecisionID)
        XCTAssertEqual(response.payloadID, chain.transportRequest.payloadID)
        XCTAssertEqual(response.dispatchReceiptID, chain.transportRequest.dispatchReceiptID)
        XCTAssertEqual(response.vendorDecisionID, chain.transportRequest.vendorDecisionID)
        XCTAssertEqual(response.authorizationID, chain.transportRequest.authorizationID)
        XCTAssertEqual(response.leaseID, chain.transportRequest.leaseID)
        XCTAssertEqual(response.budgetID, chain.transportRequest.budgetID)
        XCTAssertEqual(response.meteredDecisionID, chain.transportRequest.meteredDecisionID)
        XCTAssertEqual(response.providerFamily, .searchAPI)
        XCTAssertEqual(response.vendorID, "a131-accepted-vendor")
        XCTAssertEqual(response.capability, .webSearch)
        XCTAssertEqual(response.costClass, .meteredPremium)
        XCTAssertEqual(response.freshness, .livePreferred)
        XCTAssertEqual(response.resultShape, .organicLinks)
        XCTAssertEqual(response.requestedResultLimit, 4)
        XCTAssertEqual(response.returnedResultCount, 1)
        XCTAssertEqual(response.citationCount, 1)
        XCTAssertEqual(response.sourceCitationSummary, chain.transportRequest.sourceCitationSummary)
        XCTAssertTrue(response.statusLine.contains("request-bound cited metadata only"))
        XCTAssertTrue(response.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(response.description.contains("public coffee"))
        XCTAssertFalse(response.description.contains("a131-accepted.example.com"))
    }

    func test_rejectionMatrixBlocksMissingRejectedAndMalformedInputs() throws {
        let chain = try transportChain(
            traceID: "a131-rejection",
            sourceHost: "a131-rejection.example.com",
            vendorID: "a131-rejection-vendor"
        )
        let resultReceipt = try normalizedResultReceipt(
            for: chain.request,
            sourceHost: "a131-rejection.example.com",
            freshness: chain.transportRequest.freshness
        )
        let rejectedTransportRequestDecision = ServerProviderSearchAPITransportRequestBuilder.prepare(
            requestDecision: chain.requestDecision,
            payloadDecision: chain.payloadDecision,
            dispatchReceipt: chain.dispatchReceipt,
            vendorDecision: chain.vendorDecision,
            authorization: chain.authorization,
            lease: nil,
            budgetContext: chain.budgetContext
        )
        let rejectedResultReceipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: chain.request,
            candidate: try resultCandidate(
                freshness: chain.transportRequest.freshness,
                citations: []
            )
        )

        XCTAssertEqual(rejectedTransportRequestDecision.state, .rejected)
        XCTAssertEqual(rejectedResultReceipt.state, .rejected)

        let cases: [
            (
                id: String,
                transportRequestDecision: ServerProviderSearchAPITransportRequestDecision?,
                adapterResultReceipt: ServerProviderSearchAPIAdapterResultReceipt?,
                expected: ServerProviderSearchAPITransportResponseRejectionReason
            )
        ] = [
            (
                "missing transport request decision",
                nil,
                resultReceipt,
                .missingTransportRequestDecision
            ),
            (
                "rejected transport request decision",
                rejectedTransportRequestDecision,
                resultReceipt,
                .transportRequestDecisionRejected
            ),
            (
                "missing transport request",
                copy(chain.transportRequestDecision, request: nil),
                resultReceipt,
                .missingTransportRequest
            ),
            (
                "missing adapter result receipt",
                chain.transportRequestDecision,
                nil,
                .missingAdapterResultReceipt
            ),
            (
                "rejected adapter result receipt",
                chain.transportRequestDecision,
                rejectedResultReceipt,
                .adapterResultRejected
            ),
            (
                "missing normalized result",
                chain.transportRequestDecision,
                copy(resultReceipt, result: nil),
                .missingResult
            ),
            (
                "missing vendor metadata",
                copy(
                    chain.transportRequestDecision,
                    request: copy(chain.transportRequest, vendorID: "")
                ),
                resultReceipt,
                .vendorMissing
            ),
            (
                "missing lease metadata",
                copy(
                    chain.transportRequestDecision,
                    request: copy(chain.transportRequest, leaseID: "")
                ),
                resultReceipt,
                .leaseMetadataMissing
            ),
            (
                "missing budget metadata",
                copy(
                    chain.transportRequestDecision,
                    request: copy(chain.transportRequest, budgetID: "")
                ),
                resultReceipt,
                .budgetMetadataMissing
            ),
            (
                "missing metered metadata",
                copy(
                    chain.transportRequestDecision,
                    request: copy(chain.transportRequest, meteredDecisionID: "")
                ),
                resultReceipt,
                .meteredMetadataMissing
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPITransportResponseBuilder.accept(
                transportRequestDecision: testCase.transportRequestDecision,
                adapterResultReceipt: testCase.adapterResultReceipt
            )

            XCTAssertFalse(decision.isAccepted, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertNil(decision.response, testCase.id)
            XCTAssertEqual(decision.rejection, testCase.expected, testCase.id)
            XCTAssertTrue(decision.statusLine.contains(testCase.expected.rawValue), testCase.id)
            XCTAssertTrue(
                decision.statusLine.contains("No transport or provider runtime has run"),
                testCase.id
            )
        }
    }

    func test_metadataMismatchesRejectBeforeResponseReceipt() throws {
        let chain = try transportChain(
            traceID: "a131-mismatch",
            sourceHost: "a131-mismatch.example.com",
            vendorID: "a131-mismatch-vendor"
        )
        let resultReceipt = try normalizedResultReceipt(
            for: chain.request,
            sourceHost: "a131-mismatch.example.com",
            freshness: chain.transportRequest.freshness
        )
        let result = try XCTUnwrap(resultReceipt.result)

        let cases: [
            (
                id: String,
                transportRequestDecision: ServerProviderSearchAPITransportRequestDecision,
                adapterResultReceipt: ServerProviderSearchAPIAdapterResultReceipt,
                returnedResultCount: Int,
                expected: ServerProviderSearchAPITransportResponseRejectionReason
            )
        ] = [
            (
                "request id mismatch",
                chain.transportRequestDecision,
                copy(resultReceipt, requestID: "a131-other-request"),
                1,
                .requestIDMismatch
            ),
            (
                "result request id mismatch",
                chain.transportRequestDecision,
                copy(resultReceipt, result: copy(result, requestID: "a131-other-request")),
                1,
                .requestIDMismatch
            ),
            (
                "provider family mismatch",
                chain.transportRequestDecision,
                copy(resultReceipt, providerFamily: .googleMaps),
                1,
                .providerFamilyMismatch
            ),
            (
                "capability mismatch",
                chain.transportRequestDecision,
                copy(resultReceipt, capability: .localServiceSearch),
                1,
                .capabilityMismatch
            ),
            (
                "cost class mismatch",
                chain.transportRequestDecision,
                copy(resultReceipt, costClass: .includedQuota),
                1,
                .costClassMismatch
            ),
            (
                "freshness mismatch",
                chain.transportRequestDecision,
                copy(resultReceipt, result: copy(result, freshness: .cachedOK)),
                1,
                .freshnessMismatch
            ),
            (
                "result limit overflow",
                chain.transportRequestDecision,
                resultReceipt,
                chain.transportRequest.resultLimit + 1,
                .resultLimitOverflow
            ),
            (
                "source policy mismatch",
                copy(
                    chain.transportRequestDecision,
                    request: copy(
                        chain.transportRequest,
                        sourceCitationSummary: sourceCitationSummary(
                            sourceState: .blocked,
                            citationRequired: true,
                            sourceHost: "a131-mismatch.example.com"
                        )
                    )
                ),
                resultReceipt,
                1,
                .sourceCitationPolicyMismatch
            ),
            (
                "citation missing",
                chain.transportRequestDecision,
                copy(resultReceipt, result: copy(result, citations: [])),
                1,
                .citationMissing
            ),
            (
                "normalized content missing",
                chain.transportRequestDecision,
                copy(resultReceipt, result: copy(result, title: "")),
                1,
                .normalizedContentMissing
            ),
            (
                "zero returned result count",
                chain.transportRequestDecision,
                resultReceipt,
                0,
                .normalizedContentMissing
            ),
        ]

        for testCase in cases {
            let decision = ServerProviderSearchAPITransportResponseBuilder.accept(
                transportRequestDecision: testCase.transportRequestDecision,
                adapterResultReceipt: testCase.adapterResultReceipt,
                returnedResultCount: testCase.returnedResultCount
            )

            XCTAssertFalse(decision.isAccepted, testCase.id)
            XCTAssertEqual(decision.state, .rejected, testCase.id)
            XCTAssertEqual(decision.rejection, testCase.expected, testCase.id)
            XCTAssertNil(decision.response, testCase.id)
            XCTAssertTrue(decision.statusLine.contains(testCase.expected.rawValue), testCase.id)
        }
    }

    func test_encodingAndDebugStatusCopyDoNotLeakSensitiveRuntimeFields() throws {
        let chain = try transportChain(
            traceID: "a131-copy",
            sourceHost: "a131-copy.example.com",
            vendorID: "a131-copy-vendor"
        )
        let resultReceipt = try normalizedResultReceipt(
            for: chain.request,
            sourceHost: "a131-copy.example.com",
            freshness: chain.transportRequest.freshness
        )
        let accepted = ServerProviderSearchAPITransportResponseBuilder.accept(
            transportRequestDecision: chain.transportRequestDecision,
            adapterResultReceipt: resultReceipt
        )
        let rejected = ServerProviderSearchAPITransportResponseBuilder.accept(
            transportRequestDecision: chain.transportRequestDecision,
            adapterResultReceipt: copy(resultReceipt, result: nil)
        )
        let response = try XCTUnwrap(accepted.response)
        let text = [
            try encodedString(accepted),
            try encodedString(rejected),
            try encodedString(response),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
            response.description,
            response.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("a131-copy.example.com"))
        XCTAssertFalse(text.contains("/source"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected response wording: \(forbidden)")
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
        let transportRequestDecision: ServerProviderSearchAPITransportRequestDecision
        let transportRequest: ServerProviderSearchAPITransportRequest
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
        let transportRequestDecision = ServerProviderSearchAPITransportRequestBuilder.prepare(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt,
            vendorDecision: vendorDecision,
            authorization: authorization,
            lease: lease,
            budgetContext: budgetContext
        )
        let transportRequest = try XCTUnwrap(transportRequestDecision.request)

        XCTAssertEqual(requestDecision.state, .requestPrepared)
        XCTAssertEqual(payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(dispatchReceipt.state, .dispatchEligible)
        XCTAssertEqual(vendorDecision.state, .accepted)
        XCTAssertEqual(authorization.state, .authorized)
        XCTAssertEqual(meteredDecision.state, .accepted)
        XCTAssertEqual(lease.state, .issued)
        XCTAssertEqual(transportRequestDecision.state, .requestPrepared)

        return TransportChain(
            requestDecision: requestDecision,
            request: request,
            payloadDecision: payloadDecision,
            payload: payload,
            dispatchReceipt: dispatchReceipt,
            vendorDecision: vendorDecision,
            authorization: authorization,
            budgetContext: budgetContext,
            lease: lease,
            transportRequestDecision: transportRequestDecision,
            transportRequest: transportRequest
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

    private func normalizedResultReceipt(
        for request: ServerProviderSearchAPIAdapterRequest,
        sourceHost: String,
        freshness: ProviderFreshness
    ) throws -> ServerProviderSearchAPIAdapterResultReceipt {
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: try resultCandidate(
                sourceHost: sourceHost,
                freshness: freshness
            )
        )
        XCTAssertEqual(receipt.state, .resultNormalized)
        return receipt
    }

    private func resultCandidate(
        sourceHost: String = "a131-result.example.com",
        freshness: ProviderFreshness,
        citations: [ServerProviderSearchAPIAdapterCitation]? = nil
    ) throws -> ServerProviderSearchAPIAdapterResultCandidate {
        let resolvedCitations: [ServerProviderSearchAPIAdapterCitation]
        if let citations {
            resolvedCitations = citations
        } else {
            resolvedCitations = [
                ServerProviderSearchAPIAdapterCitation(
                    sourceURL: try citationURL(host: sourceHost),
                    title: "Public source",
                    attribution: "Source attribution"
                ),
            ]
        }

        return ServerProviderSearchAPIAdapterResultCandidate(
            title: "Public information result",
            snippet: "Cited public summary metadata.",
            freshness: freshness,
            citations: resolvedCitations,
            limitations: ["Read-only public information."]
        )
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
                quotaPeriodID: "a131-2026-05",
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
            id: "a131-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A131 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a131-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a131-connector-request-\(traceID)",
            resultID: "a131-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a131-authorization-\(traceID)",
            boundaryID: "a131-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func sourceCitationSummary(
        sourceState: ServerSourcePolicyState,
        citationRequired: Bool,
        sourceHost: String
    ) -> ServerProviderSearchAPITransportSourceCitationSummary {
        ServerProviderSearchAPITransportSourceCitationSummary(
            sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                sourcePolicy: ServerSourcePolicy(
                    sourceState: sourceState,
                    attributionRequired: true,
                    sourceHost: sourceHost
                ),
                citationRequired: citationRequired
            )
        )
    }

    private func citationURL(host: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/source"
        return try XCTUnwrap(components.url)
    }

    private func copy(
        _ decision: ServerProviderSearchAPITransportRequestDecision,
        request: ServerProviderSearchAPITransportRequest?
    ) -> ServerProviderSearchAPITransportRequestDecision {
        ServerProviderSearchAPITransportRequestDecision(
            id: "\(decision.id)-copy",
            state: decision.state,
            statusLine: decision.statusLine,
            request: request,
            rejection: decision.rejection,
            requestDecisionRejection: decision.requestDecisionRejection,
            payloadDecisionRejection: decision.payloadDecisionRejection,
            dispatchReceiptRejection: decision.dispatchReceiptRejection,
            vendorPolicyRejection: decision.vendorPolicyRejection,
            authorizationRejection: decision.authorizationRejection,
            leaseRejection: decision.leaseRejection
        )
    }

    private func copy(
        _ request: ServerProviderSearchAPITransportRequest,
        vendorID: String? = nil,
        leaseID: String? = nil,
        budgetID: String? = nil,
        meteredDecisionID: String? = nil,
        sourceCitationSummary: ServerProviderSearchAPITransportSourceCitationSummary? = nil
    ) -> ServerProviderSearchAPITransportRequest {
        ServerProviderSearchAPITransportRequest(
            id: "\(request.id)-copy",
            requestID: request.requestID,
            payloadDecisionID: request.payloadDecisionID,
            payloadID: request.payloadID,
            dispatchReceiptID: request.dispatchReceiptID,
            vendorDecisionID: request.vendorDecisionID,
            authorizationID: request.authorizationID,
            leaseID: leaseID ?? request.leaseID,
            budgetID: budgetID ?? request.budgetID,
            meteredDecisionID: meteredDecisionID ?? request.meteredDecisionID,
            providerFamily: request.providerFamily,
            vendorID: vendorID ?? request.vendorID,
            capability: request.capability,
            costClass: request.costClass,
            freshness: request.freshness,
            resultShape: request.resultShape,
            resultLimit: request.resultLimit,
            sourceCitationSummary: sourceCitationSummary ?? request.sourceCitationSummary
        )
    }

    private func copy(
        _ receipt: ServerProviderSearchAPIAdapterResultReceipt,
        requestID: String? = nil,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil
    ) -> ServerProviderSearchAPIAdapterResultReceipt {
        ServerProviderSearchAPIAdapterResultReceipt(
            id: "\(receipt.id)-copy",
            state: receipt.state,
            statusLine: receipt.statusLine,
            requestID: requestID ?? receipt.requestID,
            traceID: receipt.traceID,
            providerFamily: providerFamily ?? receipt.providerFamily,
            capability: capability ?? receipt.capability,
            costClass: costClass ?? receipt.costClass,
            result: receipt.result,
            rejection: receipt.rejection
        )
    }

    private func copy(
        _ receipt: ServerProviderSearchAPIAdapterResultReceipt,
        result: ServerProviderSearchAPIAdapterResult?
    ) -> ServerProviderSearchAPIAdapterResultReceipt {
        ServerProviderSearchAPIAdapterResultReceipt(
            id: "\(receipt.id)-copy",
            state: receipt.state,
            statusLine: receipt.statusLine,
            requestID: receipt.requestID,
            traceID: receipt.traceID,
            providerFamily: receipt.providerFamily,
            capability: receipt.capability,
            costClass: receipt.costClass,
            result: result,
            rejection: receipt.rejection
        )
    }

    private func copy(
        _ result: ServerProviderSearchAPIAdapterResult,
        requestID: String? = nil,
        title: String? = nil,
        freshness: ProviderFreshness? = nil,
        citations: [ServerProviderSearchAPIAdapterCitation]? = nil
    ) -> ServerProviderSearchAPIAdapterResult {
        ServerProviderSearchAPIAdapterResult(
            id: "\(result.id)-copy",
            requestID: requestID ?? result.requestID,
            traceID: result.traceID,
            providerFamily: result.providerFamily,
            capability: result.capability,
            costClass: result.costClass,
            title: title ?? result.title,
            snippet: result.snippet,
            freshness: freshness ?? result.freshness,
            citations: citations ?? result.citations,
            limitations: result.limitations
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
