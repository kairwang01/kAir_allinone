//
//  ServerProviderSearchAPIAdapterPayloadTests.swift
//  kAirTests
//
//  A91 Search API adapter transport payload boundary proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIAdapterPayloadTests: XCTestCase {

    func test_preparedRequestDecisionBuildsDeterministicPayload() throws {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(
                capability: .webSearch,
                freshness: .livePreferred
            ),
            connectorReceipt: connectorReceipt(
                capability: .webSearch,
                freshness: .livePreferred
            ),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "  public   coffee  ",
                localeHint: " en-US "
            ),
            resultLimit: 4
        )
        let request = try XCTUnwrap(requestDecision.request)

        let decision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: requestDecision)
        let directDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)

        assertSendable(decision)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision, directDecision)
        XCTAssertEqual(decision.state, .payloadPrepared)
        XCTAssertNil(decision.rejection)
        XCTAssertNil(decision.requestDecisionRejection)
        XCTAssertEqual(decision.requestID, request.id)
        XCTAssertTrue(decision.statusLine.contains("approved request metadata only"))
        XCTAssertTrue(decision.statusLine.contains("No transport or provider runtime has run"))

        let payload = try XCTUnwrap(decision.payload)
        XCTAssertEqual(payload.id, "search-api-adapter-payload-\(safeID(request.id))")
        XCTAssertEqual(payload.requestID, request.id)
        XCTAssertEqual(payload.traceID, request.traceID)
        XCTAssertEqual(payload.providerFamily, .searchAPI)
        XCTAssertEqual(payload.capability, .webSearch)
        XCTAssertEqual(payload.costClass, .meteredPremium)
        XCTAssertEqual(payload.freshness, .livePreferred)
        XCTAssertEqual(payload.resultLimit, 4)
        XCTAssertEqual(payload.query.text, "public coffee")
        XCTAssertEqual(payload.query.localeHint, "en-US")
        XCTAssertEqual(payload.sourcePolicy.sourceState, .passed)
        XCTAssertEqual(payload.sourcePolicy.robotsState, .notApplicable)
        XCTAssertTrue(payload.sourcePolicy.attributionRequired)
        XCTAssertTrue(payload.sourcePolicy.citationRequired)
        XCTAssertEqual(payload.sourcePolicy.sourceHost, "example.com")
        XCTAssertFalse(payload.description.contains(payload.query.text))
    }

    func test_rejectedRequestDecisionDoesNotBuildPayloadAndPreservesReason() {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(privacyClass: .private),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )

        let decision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: requestDecision)

        XCTAssertEqual(requestDecision.state, .rejected)
        XCTAssertEqual(requestDecision.rejection, .privacyBlocked)
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertNil(decision.requestID)
        XCTAssertNil(decision.payload)
        XCTAssertEqual(decision.rejection, .requestDecisionRejected)
        XCTAssertEqual(decision.requestDecisionRejection, .privacyBlocked)
        XCTAssertTrue(decision.statusLine.contains("request decision is not prepared"))
        XCTAssertTrue(decision.statusLine.contains("No transport or provider runtime has run"))
    }

    func test_directRequestBuilderRejectsUnsafeMutatedMetadata() throws {
        let request = try preparedRequest()
        let cases: [(ServerProviderSearchAPIAdapterRequest, ServerProviderSearchAPIAdapterPayloadRejectionReason)] = [
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
                            attributionRequired: false,
                            sourceHost: "example.com"
                        )
                    )
                ),
                .citationPolicyMissing
            ),
            (
                copy(request, query: ServerProviderSearchAPIAdapterQuery(text: "   ")),
                .emptyQuery
            ),
        ]

        for (mutatedRequest, expected) in cases {
            let decision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: mutatedRequest)

            XCTAssertEqual(decision.state, .rejected)
            XCTAssertNil(decision.payload)
            XCTAssertEqual(decision.requestID, mutatedRequest.id)
            XCTAssertEqual(decision.rejection, expected)
            XCTAssertNil(decision.requestDecisionRejection)
            XCTAssertTrue(decision.statusLine.contains("metadata policy"))
            XCTAssertTrue(decision.statusLine.contains("No transport or provider runtime has run"))
        }
    }

    func test_payloadEncodingAndDebugCopyStayAdvisoryAndValueOnly() throws {
        let preparedDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: try preparedRequest()
        )
        let rejectedDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(entitlements: []),
                connectorReceipt: connectorReceipt(),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let payload = try XCTUnwrap(preparedDecision.payload)

        let text = [
            try encodedString(preparedDecision),
            try encodedString(rejectedDecision),
            try encodedString(payload),
            preparedDecision.statusLine,
            rejectedDecision.statusLine,
            payload.statusLine,
            preparedDecision.description,
            rejectedDecision.description,
            payload.description,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        for forbidden in sensitiveTransportFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected payload field or wording: \(forbidden)")
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
        traceID: String = "a91-search-trace"
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
        traceID: String? = "a91-search-trace"
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a91-connector-receipt-\(state.rawValue)-\(providerFamily?.rawValue ?? "missing")-\(capability?.rawValue ?? "missing")",
            state: state,
            statusLine: "A91 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a91-planning",
            planningState: state == .receiptPrepared ? .requestPrepared : .rejected,
            planningRejection: state == .receiptPrepared ? nil : .authorizationRejected,
            connectorProviderFamily: providerFamily,
            requestID: "a91-connector-request",
            resultID: state == .receiptPrepared ? "a91-connector-result" : nil,
            connectorResultState: state == .receiptPrepared ? .metadataPrepared : .rejected,
            connectorRejection: state == .receiptPrepared ? nil : .connectorProviderFamilyMismatch,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a91-authorization",
            boundaryID: "a91-boundary",
            traceID: traceID,
            invocationRejection: state == .receiptPrepared ? nil : .connectorRejected
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
        return slug.isEmpty ? "missing-search-api-payload-id" : slug
    }

    private func sensitiveTransportFragments() -> [String] {
        [
            "end" + "point",
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
