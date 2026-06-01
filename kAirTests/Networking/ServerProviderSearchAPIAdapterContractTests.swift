//
//  ServerProviderSearchAPIAdapterContractTests.swift
//  kAirTests
//
//  A86 Search API adapter contract proof tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIAdapterContractTests: XCTestCase {

    func test_prepareRequest_acceptsEligibleWebSearchMetadataAndCopiesPolicy() throws {
        let envelope = searchEnvelope(
            capability: .webSearch,
            freshness: .livePreferred
        )
        let receipt = connectorReceipt(
            capability: .webSearch,
            freshness: .livePreferred
        )
        let query = ServerProviderSearchAPIAdapterQuery(
            text: "  coffee   shops near union square  ",
            localeHint: " en-US "
        )

        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope,
            connectorReceipt: receipt,
            query: query,
            resultLimit: 5
        )

        assertSendable(decision)
        XCTAssertEqual(Set([decision]).count, 1)
        XCTAssertEqual(decision.state, .requestPrepared)
        XCTAssertNil(decision.rejection)
        XCTAssertTrue(decision.statusLine.contains("approved metadata only"))
        XCTAssertTrue(decision.statusLine.contains("No provider runtime has run"))

        let request = try XCTUnwrap(decision.request)
        XCTAssertEqual(request.providerFamily, .searchAPI)
        XCTAssertEqual(request.capability, .webSearch)
        XCTAssertEqual(request.privacyClass, .general)
        XCTAssertEqual(request.membershipTier, .plus)
        XCTAssertEqual(request.costClass, .meteredPremium)
        XCTAssertEqual(request.freshness, .livePreferred)
        XCTAssertEqual(request.resultLimit, 5)
        XCTAssertEqual(request.query.text, "coffee shops near union square")
        XCTAssertEqual(request.query.localeHint, "en-US")
        XCTAssertEqual(request.traceID, envelope.traceID)
        XCTAssertEqual(request.envelopeTraceID, envelope.traceID)
        XCTAssertEqual(request.connectorReceiptID, receipt.id)
        XCTAssertEqual(request.connectorRequestID, receipt.requestID)
        XCTAssertEqual(request.quotaSummary.providerFamily, .searchAPI)
        XCTAssertEqual(request.quotaSummary.membershipTier, .plus)
        XCTAssertEqual(request.quotaSummary.costClass, .meteredPremium)
        XCTAssertTrue(request.quotaSummary.entitlementPresent)
        XCTAssertTrue(request.quotaSummary.isAllowed)
        XCTAssertEqual(request.accessSummary.providerFamily, .searchAPI)
        XCTAssertEqual(request.accessSummary.capability, .webSearch)
        XCTAssertEqual(request.sourcePolicy.sourceState, .passed)
        XCTAssertEqual(request.sourcePolicy.robotsState, .notApplicable)
        XCTAssertTrue(request.sourcePolicy.attributionRequired)
        XCTAssertTrue(request.sourcePolicy.citationRequired)
        XCTAssertEqual(request.sourcePolicy.sourceHost, "example.com")
    }

    func test_prepareRequest_acceptsEligibleLocalServiceSearchMetadata() throws {
        let envelope = searchEnvelope(
            capability: .localServiceSearch,
            freshness: .cachedOK
        )
        let receipt = connectorReceipt(
            capability: .localServiceSearch,
            freshness: .cachedOK
        )

        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope,
            connectorReceipt: receipt,
            query: ServerProviderSearchAPIAdapterQuery(text: "late night pharmacy"),
            resultLimit: 3
        )

        let request = try XCTUnwrap(decision.request)
        XCTAssertEqual(decision.state, .requestPrepared)
        XCTAssertEqual(request.capability, .localServiceSearch)
        XCTAssertEqual(request.freshness, .cachedOK)
        XCTAssertEqual(request.resultLimit, 3)
    }

    func test_prepareRequest_rejectsNonSearchProviderFamilies() {
        let families: [ProviderFamily] = [
            .googleMaps,
            .gaode,
            .crawler,
            .mcp,
            .appleLocal,
            .cache,
        ]

        for family in families {
            let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(providerFamily: family),
                connectorReceipt: connectorReceipt(providerFamily: family),
                query: ServerProviderSearchAPIAdapterQuery(text: "public lunch options")
            )

            XCTAssertEqual(decision.state, .rejected)
            XCTAssertNil(decision.request)
            XCTAssertEqual(decision.rejection, .providerFamilyNotSearchAPI)
            XCTAssertTrue(decision.statusLine.contains("metadata policy"))
            XCTAssertTrue(decision.statusLine.contains("No provider runtime has run"))
        }
    }

    func test_prepareRequest_rejectsPrivacyQuotaEntitlementAndSourcePolicyFailures() {
        let cases: [(ServerProviderEnvelope, ServerProviderSearchAPIAdapterRejectionReason)] = [
            (
                searchEnvelope(privacyClass: .private),
                .privacyBlocked
            ),
            (
                searchEnvelope(privacyClass: .health),
                .privacyBlocked
            ),
            (
                searchEnvelope(costClass: .blockedByCost),
                .quotaBlocked
            ),
            (
                searchEnvelope(entitlements: []),
                .entitlementMissing
            ),
            (
                searchEnvelope(sourcePolicy: .notApplicable),
                .sourcePolicyInsufficient
            ),
            (
                searchEnvelope(
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        attributionRequired: false,
                        sourceHost: "example.com"
                    )
                ),
                .citationPolicyMissing
            ),
        ]

        for (envelope, expected) in cases {
            let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: envelope,
                connectorReceipt: connectorReceipt(
                    capability: envelope.capability,
                    costClass: envelope.costClass,
                    freshness: envelope.freshness,
                    traceID: envelope.traceID
                ),
                query: ServerProviderSearchAPIAdapterQuery(text: "public park hours")
            )

            XCTAssertEqual(decision.state, .rejected)
            XCTAssertNil(decision.request)
            XCTAssertEqual(decision.rejection, expected)
        }
    }

    func test_prepareRequest_rejectsMalformedQueryAndResultLimit() {
        let envelope = searchEnvelope()
        let receipt = connectorReceipt()

        let emptyQuery = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope,
            connectorReceipt: receipt,
            query: ServerProviderSearchAPIAdapterQuery(text: "   ")
        )
        let highLimit = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope,
            connectorReceipt: receipt,
            query: ServerProviderSearchAPIAdapterQuery(text: "public events"),
            resultLimit: ServerProviderSearchAPIAdapterContract.maximumResultLimit + 1
        )
        let zeroLimit = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope,
            connectorReceipt: receipt,
            query: ServerProviderSearchAPIAdapterQuery(text: "public events"),
            resultLimit: 0
        )

        XCTAssertEqual(emptyQuery.rejection, .emptyQuery)
        XCTAssertEqual(highLimit.rejection, .invalidResultLimit)
        XCTAssertEqual(zeroLimit.rejection, .invalidResultLimit)
    }

    func test_prepareRequest_rejectsConnectorReceiptProblems() {
        let envelope = searchEnvelope()
        let cases: [(ServerProviderRuntimeConnectorInvocationReceipt, ServerProviderSearchAPIAdapterRejectionReason)] = [
            (
                connectorReceipt(state: .rejected),
                .connectorReceiptRejected
            ),
            (
                connectorReceipt(providerFamily: nil),
                .connectorMetadataMissing
            ),
            (
                connectorReceipt(providerFamily: .googleMaps),
                .connectorProviderFamilyMismatch
            ),
            (
                connectorReceipt(capability: .localServiceSearch),
                .connectorCapabilityMismatch
            ),
            (
                connectorReceipt(traceID: "different-trace"),
                .connectorTraceMismatch
            ),
            (
                connectorReceipt(costClass: .includedQuota),
                .connectorCostMismatch
            ),
            (
                connectorReceipt(freshness: .cachedOK),
                .connectorFreshnessMismatch
            ),
        ]

        for (receipt, expected) in cases {
            let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: envelope,
                connectorReceipt: receipt,
                query: ServerProviderSearchAPIAdapterQuery(text: "public museums")
            )

            XCTAssertEqual(decision.state, .rejected)
            XCTAssertNil(decision.request)
            XCTAssertEqual(decision.rejection, expected)
        }
    }

    func test_normalizeResult_acceptsCitedResultAndKeepsReceiptAdvisory() throws {
        let request = try preparedRequest()
        let candidate = resultCandidate(
            freshness: .livePreferred,
            sourceURL: try XCTUnwrap(URL(string: "https://example.com/coffee"))
        )

        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: candidate
        )

        assertSendable(receipt)
        XCTAssertEqual(Set([receipt]).count, 1)
        XCTAssertEqual(receipt.state, .resultNormalized)
        XCTAssertNil(receipt.rejection)
        XCTAssertEqual(receipt.requestID, request.id)
        XCTAssertEqual(receipt.traceID, request.traceID)
        XCTAssertEqual(receipt.providerFamily, .searchAPI)
        XCTAssertEqual(receipt.capability, .webSearch)
        XCTAssertTrue(receipt.statusLine.contains("cited metadata only"))
        XCTAssertTrue(receipt.statusLine.contains("No provider runtime has run"))

        let result = try XCTUnwrap(receipt.result)
        XCTAssertEqual(result.requestID, request.id)
        XCTAssertEqual(result.traceID, request.traceID)
        XCTAssertEqual(result.providerFamily, .searchAPI)
        XCTAssertEqual(result.capability, .webSearch)
        XCTAssertEqual(result.title, "Coffee options")
        XCTAssertEqual(result.snippet, "Public summary with cited source metadata.")
        XCTAssertEqual(result.freshness, .livePreferred)
        XCTAssertEqual(result.citations.first?.sourceHost, "example.com")
        XCTAssertEqual(result.limitations, ["Read-only public information."])
    }

    func test_normalizeResult_rejectsMissingCitationSourceMismatchAndStaleLiveRequirement() throws {
        let liveRequired = try preparedRequest(freshness: .liveRequired)
        let livePreferred = try preparedRequest(freshness: .livePreferred)

        let noCitation = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: livePreferred,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary.",
                freshness: .livePreferred,
                citations: []
            )
        )
        let wrongSource = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: livePreferred,
            candidate: resultCandidate(
                freshness: .livePreferred,
                sourceURL: try XCTUnwrap(URL(string: "https://other.example/source"))
            )
        )
        let stale = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: liveRequired,
            candidate: resultCandidate(
                freshness: .cachedOK,
                sourceURL: try XCTUnwrap(URL(string: "https://example.com/cached"))
            )
        )
        let missingContent = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: livePreferred,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: " ",
                snippet: " ",
                freshness: .livePreferred,
                citations: [
                    ServerProviderSearchAPIAdapterCitation(
                        sourceURL: try XCTUnwrap(URL(string: "https://example.com/source")),
                        title: "Source",
                        attribution: "Public Source"
                    ),
                ]
            )
        )

        XCTAssertEqual(noCitation.state, .rejected)
        XCTAssertEqual(noCitation.rejection, .resultCitationMissing)
        XCTAssertNil(noCitation.result)
        XCTAssertNil(noCitation.providerFamily)
        XCTAssertEqual(wrongSource.rejection, .resultCitationSourceMismatch)
        XCTAssertEqual(stale.rejection, .resultStaleForLiveRequired)
        XCTAssertEqual(missingContent.rejection, .resultContentMissing)
    }

    func test_encodingStatusAndDebugCopyDoNotExposeSensitiveRuntimeFields() throws {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        let request = try XCTUnwrap(requestDecision.request)
        let resultReceipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: resultCandidate(
                freshness: .livePreferred,
                sourceURL: try XCTUnwrap(URL(string: "https://example.com/coffee"))
            )
        )
        let rejectedRequest = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(entitlements: []),
            connectorReceipt: connectorReceipt(),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let rejectedResult = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary.",
                freshness: .livePreferred,
                citations: []
            )
        )

        let text = [
            try encodedString(requestDecision),
            try encodedString(resultReceipt),
            try encodedString(rejectedRequest),
            try encodedString(rejectedResult),
            requestDecision.statusLine,
            requestDecision.description,
            resultReceipt.statusLine,
            resultReceipt.description,
            rejectedRequest.statusLine,
            rejectedResult.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata only"))
        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected adapter field or wording: \(forbidden)")
        }
    }

    private func preparedRequest(
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: searchEnvelope(freshness: freshness),
            connectorReceipt: connectorReceipt(freshness: freshness),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
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
        traceID: String = "a86-search-trace"
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
        traceID: String? = "a86-search-trace"
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a86-connector-receipt-\(state.rawValue)-\(providerFamily?.rawValue ?? "missing")-\(capability?.rawValue ?? "missing")",
            state: state,
            statusLine: "A86 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a86-planning",
            planningState: state == .receiptPrepared ? .requestPrepared : .rejected,
            planningRejection: state == .receiptPrepared ? nil : .authorizationRejected,
            connectorProviderFamily: providerFamily,
            requestID: "a86-connector-request",
            resultID: state == .receiptPrepared ? "a86-connector-result" : nil,
            connectorResultState: state == .receiptPrepared ? .metadataPrepared : .rejected,
            connectorRejection: state == .receiptPrepared ? nil : .connectorProviderFamilyMismatch,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a86-authorization",
            boundaryID: "a86-boundary",
            traceID: traceID,
            invocationRejection: state == .receiptPrepared ? nil : .connectorRejected
        )
    }

    private func resultCandidate(
        freshness: ProviderFreshness,
        sourceURL: URL
    ) -> ServerProviderSearchAPIAdapterResultCandidate {
        ServerProviderSearchAPIAdapterResultCandidate(
            title: "Coffee options",
            snippet: "Public summary with cited source metadata.",
            freshness: freshness,
            citations: [
                ServerProviderSearchAPIAdapterCitation(
                    sourceURL: sourceURL,
                    title: "Coffee source",
                    attribution: "Public Source"
                ),
            ],
            limitations: ["Read-only public information."]
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
            "provider raw",
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
