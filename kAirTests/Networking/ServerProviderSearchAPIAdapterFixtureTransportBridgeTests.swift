//
//  ServerProviderSearchAPIAdapterFixtureTransportBridgeTests.swift
//  kAirTests
//
//  A96 Search API adapter fixture bridge proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIAdapterFixtureTransportBridgeTests: XCTestCase {

    func test_eligiblePayloadDispatchBuildsAuditOnlyFixtureResponse() throws {
        let prepared = try preparedBridgeInputs()

        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: prepared.requestDecision,
            payloadDecision: prepared.payloadDecision,
            dispatchReceipt: prepared.dispatchReceipt
        )
        let repeated = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            input: ServerProviderSearchAPIAdapterFixtureTransportBridgeInput(
                requestDecision: prepared.requestDecision,
                payloadDecision: prepared.payloadDecision,
                dispatchReceipt: prepared.dispatchReceipt
            )
        )

        assertSendable(response)
        XCTAssertEqual(Set([response]).count, 1)
        XCTAssertEqual(response, repeated)
        XCTAssertTrue(response.isFixtureReady)
        XCTAssertEqual(response.state, .fixtureReady)
        XCTAssertNil(response.rejection)
        XCTAssertNil(response.requestDecisionRejection)
        XCTAssertNil(response.payloadDecisionRejection)
        XCTAssertNil(response.dispatchReceiptRejection)
        XCTAssertEqual(
            response.id,
            "search-api-adapter-fixture-bridge-\(safeID(prepared.dispatchReceipt.id))"
        )
        XCTAssertEqual(response.requestID, prepared.request.id)
        XCTAssertEqual(response.payloadDecisionID, prepared.payloadDecision.id)
        XCTAssertEqual(response.payloadID, prepared.payloadDecision.payload?.id)
        XCTAssertEqual(response.dispatchReceiptID, prepared.dispatchReceipt.id)
        XCTAssertEqual(response.traceID, prepared.request.traceID)
        XCTAssertEqual(response.providerFamily, .searchAPI)
        XCTAssertEqual(response.capability, .webSearch)
        XCTAssertEqual(response.costClass, .meteredPremium)
        XCTAssertEqual(response.freshness, .livePreferred)
        XCTAssertEqual(response.resultLimit, 4)
        XCTAssertEqual(response.sourcePolicy, prepared.request.sourcePolicy)
        XCTAssertTrue(response.statusLine.contains("fixture audit metadata only"))
        XCTAssertTrue(response.statusLine.contains("No provider runtime has run"))
        XCTAssertFalse(response.statusLine.contains(prepared.request.query.text))
        XCTAssertFalse(response.description.contains(prepared.request.query.text))

        let audit = try XCTUnwrap(response.audit)
        XCTAssertEqual(audit.traceID, prepared.request.traceID)
        XCTAssertEqual(audit.providerFamily, .searchAPI)
        XCTAssertEqual(audit.capability, .webSearch)
        XCTAssertEqual(audit.costClass, .meteredPremium)
        XCTAssertEqual(audit.freshness, .livePreferred)
        XCTAssertEqual(audit.resultLimit, 4)
        XCTAssertEqual(audit.sourceHost, "example.com")
        XCTAssertEqual(audit.requestID, prepared.request.id)
        XCTAssertEqual(audit.payloadDecisionID, prepared.payloadDecision.id)
        XCTAssertEqual(audit.payloadID, prepared.payloadDecision.payload?.id)
        XCTAssertEqual(audit.dispatchReceiptID, prepared.dispatchReceipt.id)
    }

    func test_rejectedInputsNeverProduceFixtureReadyAndPreserveReasons() throws {
        let prepared = try preparedBridgeInputs()
        let rejectedRequestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(privacyClass: .private),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let quotaRejectedRequestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(costClass: .blockedByCost),
            connectorReceipt: connectorReceipt(costClass: .blockedByCost),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let rejectedPayloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(privacyClass: .private),
                connectorReceipt: connectorReceipt(),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let missingPayloadDecision = ServerProviderSearchAPIAdapterPayloadDecision(
            id: "a96-missing-payload-decision",
            state: .payloadPrepared,
            statusLine: "A96 missing payload fixture is metadata only. No provider runtime has run.",
            requestID: prepared.request.id,
            payload: nil,
            rejection: nil,
            requestDecisionRejection: nil
        )
        let mismatchedPayloadDecision = copy(
            prepared.payloadDecision,
            payload: copy(
                try XCTUnwrap(prepared.payloadDecision.payload),
                traceID: "a96-other-trace"
            )
        )
        let blockedDispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: mismatchedPayloadDecision,
            request: prepared.request
        )

        let cases: [(
            ServerProviderSearchAPIAdapterRequestDecision,
            ServerProviderSearchAPIAdapterPayloadDecision,
            ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
            ServerProviderSearchAPIAdapterFixtureTransportBridgeRejectionReason,
            ServerProviderSearchAPIAdapterRejectionReason?,
            ServerProviderSearchAPIAdapterPayloadRejectionReason?,
            ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
        )] = [
            (
                rejectedRequestDecision,
                prepared.payloadDecision,
                prepared.dispatchReceipt,
                .requestDecisionRejected,
                .privacyBlocked,
                nil,
                nil
            ),
            (
                quotaRejectedRequestDecision,
                prepared.payloadDecision,
                prepared.dispatchReceipt,
                .requestDecisionRejected,
                .quotaBlocked,
                nil,
                nil
            ),
            (
                prepared.requestDecision,
                rejectedPayloadDecision,
                prepared.dispatchReceipt,
                .payloadDecisionRejected,
                .privacyBlocked,
                .requestDecisionRejected,
                nil
            ),
            (
                prepared.requestDecision,
                missingPayloadDecision,
                prepared.dispatchReceipt,
                .missingPayload,
                nil,
                nil,
                nil
            ),
            (
                prepared.requestDecision,
                prepared.payloadDecision,
                blockedDispatchReceipt,
                .dispatchReceiptBlocked,
                nil,
                nil,
                .traceIDMismatch
            ),
        ]

        for (
            requestDecision,
            payloadDecision,
            dispatchReceipt,
            expectedReason,
            expectedRequestReason,
            expectedPayloadReason,
            expectedDispatchReason
        ) in cases {
            let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt
            )

            XCTAssertFalse(response.isFixtureReady)
            XCTAssertEqual(response.state, .rejected)
            XCTAssertNil(response.audit)
            XCTAssertEqual(response.rejection, expectedReason)
            XCTAssertEqual(response.requestDecisionRejection, expectedRequestReason)
            XCTAssertEqual(response.payloadDecisionRejection, expectedPayloadReason)
            XCTAssertEqual(response.dispatchReceiptRejection, expectedDispatchReason)
            XCTAssertTrue(response.statusLine.contains("metadata policy"))
            XCTAssertTrue(response.statusLine.contains("No provider runtime has run"))
        }
    }

    func test_metadataMismatchesRejectDeterministically() throws {
        let prepared = try preparedBridgeInputs()
        let payload = try XCTUnwrap(prepared.payloadDecision.payload)
        let otherSourcePolicy = ServerProviderSearchAPIAdapterSourcePolicySnapshot(
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                attributionRequired: true,
                sourceHost: "other.example.com"
            )
        )
        let cases: [(
            ServerProviderSearchAPIAdapterPayloadDecision,
            ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
            ServerProviderSearchAPIAdapterFixtureTransportBridgeRejectionReason
        )] = [
            (
                copy(prepared.payloadDecision, requestID: "a96-other-request"),
                prepared.dispatchReceipt,
                .requestIDMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, traceID: "a96-other-trace")),
                prepared.dispatchReceipt,
                .traceIDMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, providerFamily: .googleMaps)),
                prepared.dispatchReceipt,
                .providerFamilyMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, capability: .routePlanning)),
                prepared.dispatchReceipt,
                .capabilityMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, freshness: .cachedOK)),
                prepared.dispatchReceipt,
                .freshnessMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, costClass: .includedQuota)),
                prepared.dispatchReceipt,
                .costClassMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, resultLimit: 3)),
                prepared.dispatchReceipt,
                .resultLimitMismatch
            ),
            (
                copy(
                    prepared.payloadDecision,
                    payload: copy(
                        payload,
                        query: ServerProviderSearchAPIAdapterPayloadQuery(
                            requestQuery: ServerProviderSearchAPIAdapterQuery(
                                text: "different public coffee"
                            )
                        )
                    )
                ),
                prepared.dispatchReceipt,
                .queryMismatch
            ),
            (
                copy(prepared.payloadDecision, payload: copy(payload, sourcePolicy: otherSourcePolicy)),
                prepared.dispatchReceipt,
                .sourcePolicyMismatch
            ),
            (
                prepared.payloadDecision,
                copy(prepared.dispatchReceipt, payloadDecisionID: "a96-other-payload-decision"),
                .payloadDecisionIDMismatch
            ),
            (
                prepared.payloadDecision,
                copy(prepared.dispatchReceipt, payloadID: "a96-other-payload"),
                .payloadIDMismatch
            ),
            (
                prepared.payloadDecision,
                copy(prepared.dispatchReceipt, traceID: "a96-other-trace"),
                .traceIDMismatch
            ),
            (
                prepared.payloadDecision,
                copy(prepared.dispatchReceipt, sourcePolicy: otherSourcePolicy),
                .sourcePolicyMismatch
            ),
        ]

        for (payloadDecision, dispatchReceipt, expectedReason) in cases {
            let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
                requestDecision: prepared.requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt
            )

            XCTAssertFalse(response.isFixtureReady)
            XCTAssertEqual(response.state, .rejected)
            XCTAssertNil(response.audit)
            XCTAssertEqual(response.rejection, expectedReason)
            XCTAssertTrue(response.statusLine.contains(expectedReason.rawValue))
        }
    }

    func test_bridgeEncodingAndDebugCopyStayAuditOnly() throws {
        let prepared = try preparedBridgeInputs()
        let rejectedRequestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(privacyClass: .private),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let readyResponse = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: prepared.requestDecision,
            payloadDecision: prepared.payloadDecision,
            dispatchReceipt: prepared.dispatchReceipt
        )
        let rejectedResponse = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: rejectedRequestDecision,
            payloadDecision: prepared.payloadDecision,
            dispatchReceipt: prepared.dispatchReceipt
        )

        let text = [
            try encodedString(readyResponse),
            try encodedString(rejectedResponse),
            readyResponse.statusLine,
            rejectedResponse.statusLine,
            readyResponse.description,
            rejectedResponse.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("fixture audit metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        XCTAssertFalse(text.contains(prepared.request.query.text))
        for forbidden in sensitiveBridgeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected bridge field or wording: \(forbidden)")
        }
    }

    private func preparedBridgeInputs() throws -> (
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
        request: ServerProviderSearchAPIAdapterRequest,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        let request = try XCTUnwrap(requestDecision.request)
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: requestDecision
        )
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )

        XCTAssertEqual(requestDecision.state, .requestPrepared)
        XCTAssertEqual(payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(dispatchReceipt.state, .dispatchEligible)
        return (requestDecision, request, payloadDecision, dispatchReceipt)
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
        traceID: String = "a96-search-trace"
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
        traceID: String? = "a96-search-trace"
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a96-connector-receipt-\(state.rawValue)-\(providerFamily?.rawValue ?? "missing")-\(capability?.rawValue ?? "missing")",
            state: state,
            statusLine: "A96 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a96-planning",
            planningState: state == .receiptPrepared ? .requestPrepared : .rejected,
            planningRejection: state == .receiptPrepared ? nil : .authorizationRejected,
            connectorProviderFamily: providerFamily,
            requestID: "a96-connector-request",
            resultID: state == .receiptPrepared ? "a96-connector-result" : nil,
            connectorResultState: state == .receiptPrepared ? .metadataPrepared : .rejected,
            connectorRejection: state == .receiptPrepared ? nil : .connectorProviderFamilyMismatch,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a96-authorization",
            boundaryID: "a96-boundary",
            traceID: traceID,
            invocationRejection: state == .receiptPrepared ? nil : .connectorRejected
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

    private func copy(
        _ receipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        payloadDecisionID: String? = nil,
        payloadID: String? = nil,
        traceID: String? = nil,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        freshness: ProviderFreshness? = nil,
        costClass: ProviderCostClass? = nil,
        resultLimit: Int? = nil,
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot? = nil
    ) -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        ServerProviderSearchAPIAdapterPayloadDispatchReceipt(
            id: "\(receipt.id)-copy-\(payloadDecisionID ?? payloadID ?? traceID ?? "same")",
            state: receipt.state,
            statusLine: receipt.statusLine,
            payloadDecisionID: payloadDecisionID ?? receipt.payloadDecisionID,
            payloadID: payloadID ?? receipt.payloadID,
            requestID: receipt.requestID,
            traceID: traceID ?? receipt.traceID,
            providerFamily: providerFamily ?? receipt.providerFamily,
            capability: capability ?? receipt.capability,
            freshness: freshness ?? receipt.freshness,
            costClass: costClass ?? receipt.costClass,
            resultLimit: resultLimit ?? receipt.resultLimit,
            sourcePolicy: sourcePolicy ?? receipt.sourcePolicy,
            rejection: receipt.rejection,
            payloadDecisionRejection: receipt.payloadDecisionRejection,
            requestDecisionRejection: receipt.requestDecisionRejection
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
        return slug.isEmpty ? "missing-search-api-fixture-bridge-id" : slug
    }

    private func sensitiveBridgeFragments() -> [String] {
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
