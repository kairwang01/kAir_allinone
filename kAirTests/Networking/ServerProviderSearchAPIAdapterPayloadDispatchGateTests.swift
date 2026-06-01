//
//  ServerProviderSearchAPIAdapterPayloadDispatchGateTests.swift
//  kAirTests
//
//  A92 Search API adapter payload dispatch gate proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIAdapterPayloadDispatchGateTests: XCTestCase {

    func test_matchingPreparedPayloadBuildsDeterministicEligibleReceipt() throws {
        let request = try preparedRequest()
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)

        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        let repeated = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )

        assertSendable(receipt)
        XCTAssertEqual(Set([receipt]).count, 1)
        XCTAssertEqual(receipt, repeated)
        XCTAssertTrue(receipt.isDispatchEligible)
        XCTAssertEqual(receipt.state, .dispatchEligible)
        XCTAssertNil(receipt.rejection)
        XCTAssertNil(receipt.payloadDecisionRejection)
        XCTAssertNil(receipt.requestDecisionRejection)
        XCTAssertEqual(receipt.payloadDecisionID, payloadDecision.id)
        XCTAssertEqual(receipt.payloadID, payloadDecision.payload?.id)
        XCTAssertEqual(receipt.requestID, request.id)
        XCTAssertEqual(receipt.traceID, request.traceID)
        XCTAssertEqual(receipt.providerFamily, .searchAPI)
        XCTAssertEqual(receipt.capability, .webSearch)
        XCTAssertEqual(receipt.freshness, .livePreferred)
        XCTAssertEqual(receipt.costClass, .meteredPremium)
        XCTAssertEqual(receipt.resultLimit, 4)
        XCTAssertEqual(receipt.sourcePolicy, request.sourcePolicy)
        XCTAssertTrue(receipt.statusLine.contains("verified metadata only"))
        XCTAssertTrue(receipt.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(receipt.description.contains(request.query.text))
    }

    func test_rejectedAndMissingPayloadDecisionsNeverBecomeEligibleAndPreserveReasons() throws {
        let request = try preparedRequest()
        let rejectedPayloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(privacyClass: .private),
                connectorReceipt: connectorReceipt(),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let missingPayloadDecision = ServerProviderSearchAPIAdapterPayloadDecision(
            id: "a92-missing-payload-decision",
            state: .payloadPrepared,
            statusLine: "A92 missing payload fixture is metadata only. No transport or provider runtime has run.",
            requestID: request.id,
            payload: nil,
            rejection: nil,
            requestDecisionRejection: nil
        )

        let rejectedReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: rejectedPayloadDecision,
            request: request
        )
        let missingReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: missingPayloadDecision,
            request: request
        )

        XCTAssertFalse(rejectedReceipt.isDispatchEligible)
        XCTAssertEqual(rejectedReceipt.state, .blocked)
        XCTAssertNil(rejectedReceipt.payloadID)
        XCTAssertEqual(rejectedReceipt.rejection, .payloadDecisionRejected)
        XCTAssertEqual(rejectedReceipt.payloadDecisionRejection, .requestDecisionRejected)
        XCTAssertEqual(rejectedReceipt.requestDecisionRejection, .privacyBlocked)
        XCTAssertTrue(rejectedReceipt.statusLine.contains("metadata policy"))

        XCTAssertFalse(missingReceipt.isDispatchEligible)
        XCTAssertEqual(missingReceipt.state, .blocked)
        XCTAssertNil(missingReceipt.payloadID)
        XCTAssertEqual(missingReceipt.rejection, .missingPayload)
        XCTAssertNil(missingReceipt.payloadDecisionRejection)
        XCTAssertNil(missingReceipt.requestDecisionRejection)
    }

    func test_payloadRequestMetadataMismatchesBlockDispatchEligibility() throws {
        let request = try preparedRequest()
        let baseDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let basePayload = try XCTUnwrap(baseDecision.payload)

        let cases: [(ServerProviderSearchAPIAdapterPayloadDecision, ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason)] = [
            (
                copy(baseDecision, requestID: "other-request"),
                .requestIDMismatch
            ),
            (
                copy(baseDecision, payload: copy(basePayload, traceID: "other-trace")),
                .traceIDMismatch
            ),
            (
                copy(baseDecision, payload: copy(basePayload, providerFamily: .googleMaps)),
                .providerFamilyMismatch
            ),
            (
                copy(baseDecision, payload: copy(basePayload, capability: .routePlanning)),
                .capabilityMismatch
            ),
            (
                copy(baseDecision, payload: copy(basePayload, freshness: .cachedOK)),
                .freshnessMismatch
            ),
            (
                copy(baseDecision, payload: copy(basePayload, costClass: .includedQuota)),
                .costClassMismatch
            ),
            (
                copy(baseDecision, payload: copy(basePayload, resultLimit: 3)),
                .resultLimitMismatch
            ),
            (
                copy(
                    baseDecision,
                    payload: copy(
                        basePayload,
                        query: ServerProviderSearchAPIAdapterPayloadQuery(
                            requestQuery: ServerProviderSearchAPIAdapterQuery(text: "different public coffee")
                        )
                    )
                ),
                .queryMismatch
            ),
            (
                copy(
                    baseDecision,
                    payload: copy(
                        basePayload,
                        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                            sourcePolicy: ServerSourcePolicy(
                                sourceState: .passed,
                                attributionRequired: true,
                                sourceHost: "other.example.com"
                            )
                        )
                    )
                ),
                .sourcePolicyMismatch
            ),
        ]

        for (payloadDecision, expected) in cases {
            let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
                payloadDecision: payloadDecision,
                request: request
            )

            XCTAssertFalse(receipt.isDispatchEligible)
            XCTAssertEqual(receipt.state, .blocked)
            XCTAssertNil(receipt.payloadID)
            XCTAssertNil(receipt.traceID)
            XCTAssertEqual(receipt.rejection, expected)
            XCTAssertTrue(receipt.statusLine.contains("metadata policy"))
            XCTAssertTrue(receipt.statusLine.contains("No transport or provider runtime has run"))
        }
    }

    func test_unsafeRequestMetadataBlocksEvenWhenForgedPayloadMatches() throws {
        let request = try preparedRequest()
        let cases: [(ServerProviderSearchAPIAdapterRequest, ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason)] = [
            (
                copy(
                    request,
                    providerFamily: .googleMaps,
                    quotaSummary: ServerProviderSearchAPIAdapterQuotaSummary(
                        providerFamily: .googleMaps,
                        membershipTier: request.membershipTier,
                        costClass: request.costClass,
                        entitlementPresent: true
                    )
                ),
                .providerFamilyNotSearchAPI
            ),
            (
                copy(request, capability: .routePlanning),
                .unsupportedCapability
            ),
            (
                copy(request, privacyClass: .health),
                .privacyBlocked
            ),
            (
                copy(
                    request,
                    quotaSummary: ServerProviderSearchAPIAdapterQuotaSummary(
                        providerFamily: .searchAPI,
                        membershipTier: request.membershipTier,
                        costClass: .blockedByCost,
                        entitlementPresent: true
                    )
                ),
                .quotaBlocked
            ),
            (
                copy(request, resultLimit: 0),
                .invalidResultLimit
            ),
            (
                copy(request, query: ServerProviderSearchAPIAdapterQuery(text: "   ")),
                .emptyQuery
            ),
            (
                copy(
                    request,
                    sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                        sourcePolicy: ServerSourcePolicy(
                            sourceState: .blocked,
                            attributionRequired: true,
                            sourceHost: "example.com"
                        )
                    )
                ),
                .sourcePolicyInsufficient
            ),
            (
                copy(
                    request,
                    sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                        sourcePolicy: ServerSourcePolicy(
                            sourceState: .passed,
                            attributionRequired: true,
                            sourceHost: "example.com"
                        ),
                        citationRequired: false
                    )
                ),
                .citationPolicyMissing
            ),
        ]

        for (unsafeRequest, expected) in cases {
            let forgedDecision = forgedPayloadDecision(for: unsafeRequest)

            let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
                payloadDecision: forgedDecision,
                request: unsafeRequest
            )

            XCTAssertFalse(receipt.isDispatchEligible)
            XCTAssertEqual(receipt.state, .blocked)
            XCTAssertNil(receipt.payloadID)
            XCTAssertEqual(receipt.rejection, expected)
            XCTAssertNil(receipt.payloadDecisionRejection)
            XCTAssertNil(receipt.requestDecisionRejection)
        }
    }

    func test_dispatchReceiptEncodingAndDebugCopyStayAdvisoryAndValueOnly() throws {
        let request = try preparedRequest()
        let preparedDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let rejectedDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(entitlements: []),
                connectorReceipt: connectorReceipt(),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let mismatchDecision = copy(
            preparedDecision,
            payload: copy(
                try XCTUnwrap(preparedDecision.payload),
                traceID: "other-trace"
            )
        )

        let receipts = [
            ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
                payloadDecision: preparedDecision,
                request: request
            ),
            ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
                payloadDecision: rejectedDecision,
                request: request
            ),
            ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
                payloadDecision: mismatchDecision,
                request: request
            ),
        ]

        let text = try receipts
            .map { receipt in
                [
                    try encodedString(receipt),
                    receipt.statusLine,
                    receipt.description,
                ].joined(separator: "\n")
            }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains(request.query.text))
        for forbidden in sensitiveDispatchFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected dispatch field or wording: \(forbidden)")
        }
    }

    private func preparedRequest() throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        return try XCTUnwrap(decision.request)
    }

    private func searchEnvelope(
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        sourcePolicy: ServerSourcePolicy = ServerSourcePolicy(
            sourceState: .passed,
            attributionRequired: true,
            sourceHost: "example.com"
        ),
        entitlements: Set<ProviderFamily> = [.searchAPI],
        traceID: String = "a92-search-trace"
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
            privacyClass: privacyClass,
            membershipTier: .plus,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: sourcePolicy,
            confirmationState: .notRequired,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: []
        )
    }

    private func connectorReceipt(
        state: ServerProviderRuntimeConnectorInvocationState = .receiptPrepared,
        providerFamily: ProviderFamily? = .searchAPI,
        capability: ProviderCapability? = .webSearch,
        costClass: ProviderCostClass? = .meteredPremium,
        freshness: ProviderFreshness? = .livePreferred,
        traceID: String? = "a92-search-trace"
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a92-connector-receipt-\(state.rawValue)-\(providerFamily?.rawValue ?? "missing")-\(capability?.rawValue ?? "missing")",
            state: state,
            statusLine: "A92 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a92-planning",
            planningState: state == .receiptPrepared ? .requestPrepared : .rejected,
            planningRejection: state == .receiptPrepared ? nil : .authorizationRejected,
            connectorProviderFamily: providerFamily,
            requestID: "a92-connector-request",
            resultID: state == .receiptPrepared ? "a92-connector-result" : nil,
            connectorResultState: state == .receiptPrepared ? .metadataPrepared : .rejected,
            connectorRejection: state == .receiptPrepared ? nil : .connectorProviderFamilyMismatch,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a92-authorization",
            boundaryID: "a92-boundary",
            traceID: traceID,
            invocationRejection: state == .receiptPrepared ? nil : .connectorRejected
        )
    }

    private func forgedPayloadDecision(
        for request: ServerProviderSearchAPIAdapterRequest
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        let payload = ServerProviderSearchAPIAdapterTransportPayload(
            id: "a92-forged-payload-\(safeID(request.id))",
            requestID: request.id,
            traceID: request.traceID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            costClass: request.costClass,
            freshness: request.freshness,
            resultLimit: request.resultLimit,
            query: ServerProviderSearchAPIAdapterPayloadQuery(requestQuery: request.query),
            sourcePolicy: request.sourcePolicy
        )
        return ServerProviderSearchAPIAdapterPayloadDecision(
            id: "a92-forged-payload-decision-\(safeID(request.id))",
            state: .payloadPrepared,
            statusLine: "A92 forged payload fixture is metadata only. No transport or provider runtime has run.",
            requestID: request.id,
            payload: payload,
            rejection: nil,
            requestDecisionRejection: nil
        )
    }

    private func copy(
        _ request: ServerProviderSearchAPIAdapterRequest,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        privacyClass: ProviderPrivacyClass? = nil,
        resultLimit: Int? = nil,
        query: ServerProviderSearchAPIAdapterQuery? = nil,
        quotaSummary: ServerProviderSearchAPIAdapterQuotaSummary? = nil,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot? = nil
    ) -> ServerProviderSearchAPIAdapterRequest {
        ServerProviderSearchAPIAdapterRequest(
            id: request.id,
            traceID: request.traceID,
            envelopeTraceID: request.envelopeTraceID,
            connectorReceiptID: request.connectorReceiptID,
            connectorRequestID: request.connectorRequestID,
            providerFamily: providerFamily ?? request.providerFamily,
            capability: capability ?? request.capability,
            privacyClass: privacyClass ?? request.privacyClass,
            membershipTier: request.membershipTier,
            costClass: quotaSummary?.costClass ?? request.costClass,
            freshness: request.freshness,
            resultLimit: resultLimit ?? request.resultLimit,
            query: query ?? request.query,
            quotaSummary: quotaSummary ?? request.quotaSummary,
            accessSummary: ServerProviderSearchAPIAdapterAccessSummary(
                membershipTier: request.membershipTier,
                privacyClass: privacyClass ?? request.privacyClass,
                providerFamily: providerFamily ?? request.providerFamily,
                capability: capability ?? request.capability
            ),
            sourcePolicy: sourcePolicy ?? request.sourcePolicy
        )
    }

    private func copy(
        _ decision: ServerProviderSearchAPIAdapterPayloadDecision,
        requestID: String? = nil,
        payload: ServerProviderSearchAPIAdapterTransportPayload? = nil
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        ServerProviderSearchAPIAdapterPayloadDecision(
            id: "\(decision.id)-copy-\(requestID ?? payload?.id ?? "same")",
            state: decision.state,
            statusLine: decision.statusLine,
            requestID: requestID ?? decision.requestID,
            payload: payload ?? decision.payload,
            rejection: decision.rejection,
            requestDecisionRejection: decision.requestDecisionRejection
        )
    }

    private func copy(
        _ payload: ServerProviderSearchAPIAdapterTransportPayload,
        traceID: String? = nil,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        freshness: ProviderFreshness? = nil,
        costClass: ProviderCostClass? = nil,
        resultLimit: Int? = nil,
        query: ServerProviderSearchAPIAdapterPayloadQuery? = nil,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot? = nil
    ) -> ServerProviderSearchAPIAdapterTransportPayload {
        ServerProviderSearchAPIAdapterTransportPayload(
            id: "\(payload.id)-copy",
            requestID: payload.requestID,
            traceID: traceID ?? payload.traceID,
            providerFamily: providerFamily ?? payload.providerFamily,
            capability: capability ?? payload.capability,
            costClass: costClass ?? payload.costClass,
            freshness: freshness ?? payload.freshness,
            resultLimit: resultLimit ?? payload.resultLimit,
            query: query ?? payload.query,
            sourcePolicy: sourcePolicy ?? payload.sourcePolicy
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

    private func safeID(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? "missing-search-api-dispatch-id" : slug
    }

    private func sensitiveDispatchFragments() -> [String] {
        [
            "end" + "point",
            "url",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
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
            "provider raw",
        ]
    }

    private func executionClaimFragments() -> [String] {
        [
            "completed",
            "complete",
            "contact" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "ordered",
            "paid",
        ]
    }
}
