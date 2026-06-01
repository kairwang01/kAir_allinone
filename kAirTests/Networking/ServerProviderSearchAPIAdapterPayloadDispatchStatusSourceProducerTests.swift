//
//  ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducerTests.swift
//  kAirTests
//
//  A93 Search API adapter payload dispatch status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducerTests: XCTestCase {

    func test_eligibleDispatchReceiptsPackageAsAdvisoryStatusForRenderedIDs() throws {
        let eligible = try eligibleReceipt(
            traceID: "a93-eligible",
            sourceHost: "dispatch.example.com"
        )
        let hidden = try eligibleReceipt(
            traceID: "a93-hidden",
            sourceHost: "hidden.example.com"
        )

        let source = ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer().statusSource(
            receipts: [
                .init(recommendationID: "rec-eligible", receipt: eligible),
                .init(recommendationID: "rec-hidden", receipt: hidden),
            ],
            renderedRecommendationIDs: ["rec-eligible", "rec-eligible"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-eligible")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-eligible"])
        XCTAssertEqual(presentation.recommendationID, "rec-eligible")
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("dispatch-ready metadata"))
        XCTAssertTrue(presentation.statusLine.contains(eligible.requestID))
        XCTAssertTrue(presentation.statusLine.contains(try XCTUnwrap(eligible.payloadID)))
        XCTAssertTrue(presentation.statusLine.contains("dispatch.example.com"))
        XCTAssertTrue(presentation.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(presentation.statusLine.contains("public coffee"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_blockedDispatchReceiptsPackageAsNonSuccessAdvisoryStatus() throws {
        let privateBlocked = try blockedReceiptFromRejectedDecision()
        let sourceMismatch = try blockedReceiptFromSourceMismatch()

        let source = ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer().statusSource(
            receipts: [
                .init(recommendationID: "rec-private", receipt: privateBlocked),
                .init(recommendationID: "rec-source", receipt: sourceMismatch),
            ],
            renderedRecommendationIDs: ["rec-private", "rec-source"]
        )

        let privatePresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-private")
        )
        let sourcePresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-source")
        )
        let text = [
            privatePresentation.statusLine,
            sourcePresentation.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertEqual(privateBlocked.state, .blocked)
        XCTAssertEqual(privateBlocked.rejection, .payloadDecisionRejected)
        XCTAssertEqual(privateBlocked.payloadDecisionRejection, .requestDecisionRejected)
        XCTAssertEqual(privateBlocked.requestDecisionRejection, .privacyBlocked)
        XCTAssertEqual(privatePresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: privatePresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: privatePresentation))
        XCTAssertNil(badge(.meteredPremium, in: privatePresentation))
        XCTAssertTrue(privatePresentation.statusLine.contains("payloadDecisionRejected"))
        XCTAssertTrue(privatePresentation.statusLine.contains("requestDecisionRejected"))
        XCTAssertTrue(privatePresentation.statusLine.contains("privacyBlocked"))

        XCTAssertEqual(sourceMismatch.state, .blocked)
        XCTAssertEqual(sourceMismatch.rejection, .sourcePolicyMismatch)
        XCTAssertEqual(sourcePresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: sourcePresentation)?.tone, .warning)
        XCTAssertTrue(sourcePresentation.statusLine.contains("sourcePolicyMismatch"))

        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        for forbidden in sensitiveStatusFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected dispatch status wording: \(forbidden)")
        }
    }

    func test_duplicateRecommendationIDsKeepFirstInputAndMissingIDsReturnNil() throws {
        let first = try eligibleReceipt(
            traceID: "a93-duplicate-first",
            sourceHost: "first.example.com",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let second = try eligibleReceipt(
            traceID: "a93-duplicate-second",
            sourceHost: "second.example.com",
            costClass: .meteredPremium,
            freshness: .livePreferred
        )

        let source = ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer().statusSource(
            receipts: [
                .init(recommendationID: "rec-duplicate", receipt: first),
                .init(recommendationID: "rec-duplicate", receipt: second),
            ],
            renderedRecommendationIDs: ["rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertNil(badge(.liveFreshness, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("first.example.com"))
        XCTAssertFalse(presentation.statusLine.contains("second.example.com"))
        XCTAssertNil(source.providerStatusPresentation(for: "a93-duplicate-first"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyStaysAdvisoryAndValueOnly() throws {
        let eligible = try eligibleReceipt(
            traceID: "a93-copy-eligible",
            sourceHost: "copy.example.com"
        )
        let privateBlocked = try blockedReceiptFromRejectedDecision()
        let source = ServerProviderSearchAPIAdapterPayloadDispatchStatusSourceProducer().statusSource(
            receipts: [
                .init(recommendationID: "rec-copy-eligible", receipt: eligible),
                .init(recommendationID: "rec-copy-private", receipt: privateBlocked),
            ],
            renderedRecommendationIDs: ["rec-copy-eligible", "rec-copy-private"]
        )

        let text = [
            try XCTUnwrap(source.providerStatusPresentation(for: "rec-copy-eligible")),
            try XCTUnwrap(source.providerStatusPresentation(for: "rec-copy-private")),
        ]
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        for forbidden in sensitiveStatusFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status-source wording: \(forbidden)")
        }
    }

    private func eligibleReceipt(
        traceID: String,
        sourceHost: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: traceID,
            sourceHost: sourceHost,
            costClass: costClass,
            freshness: freshness
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        XCTAssertEqual(receipt.state, .dispatchEligible)
        return receipt
    }

    private func blockedReceiptFromRejectedDecision() throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: "a93-private-baseline",
            sourceHost: "private-baseline.example.com"
        )
        let rejectedPayloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: envelope(
                    traceID: "a93-private-rejected",
                    sourceHost: "private.example.com",
                    privacyClass: .private
                ),
                connectorReceipt: connectorReceipt(traceID: "a93-private-rejected"),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: rejectedPayloadDecision,
            request: request
        )
        XCTAssertEqual(receipt.state, .blocked)
        return receipt
    }

    private func blockedReceiptFromSourceMismatch() throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: "a93-source-mismatch",
            sourceHost: "source.example.com"
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let payload = try XCTUnwrap(payloadDecision.payload)
        let mismatchedPayload = ServerProviderSearchAPIAdapterTransportPayload(
            id: "\(payload.id)-source-copy",
            requestID: payload.requestID,
            traceID: payload.traceID,
            providerFamily: payload.providerFamily,
            capability: payload.capability,
            costClass: payload.costClass,
            freshness: payload.freshness,
            resultLimit: payload.resultLimit,
            query: payload.query,
            sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    attributionRequired: true,
                    sourceHost: "other.example.com"
                )
            )
        )
        let mismatchedDecision = ServerProviderSearchAPIAdapterPayloadDecision(
            id: "\(payloadDecision.id)-source-copy",
            state: payloadDecision.state,
            statusLine: payloadDecision.statusLine,
            requestID: payloadDecision.requestID,
            payload: mismatchedPayload,
            rejection: payloadDecision.rejection,
            requestDecisionRejection: payloadDecision.requestDecisionRejection
        )
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: mismatchedDecision,
            request: request
        )
        XCTAssertEqual(receipt.state, .blocked)
        return receipt
    }

    private func preparedRequest(
        traceID: String,
        sourceHost: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequest {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                sourceHost: sourceHost,
                costClass: costClass,
                freshness: freshness
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                costClass: costClass,
                freshness: freshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        return try XCTUnwrap(decision.request)
    }

    private func envelope(
        traceID: String,
        sourceHost: String,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        entitlements: Set<ProviderFamily> = [.searchAPI]
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: .webSearch,
            providerFamily: .searchAPI,
            privacyClass: privacyClass,
            membershipTier: .plus,
            costClass: costClass,
            freshness: freshness,
            sourcePolicy: ServerSourcePolicy(
                sourceState: .passed,
                robotsState: .notApplicable,
                attributionRequired: true,
                sourceHost: sourceHost
            ),
            confirmationState: .notRequired,
            meteredProviderEntitlements: entitlements,
            enabledExperimentalProviders: []
        )
    }

    private func connectorReceipt(
        traceID: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a93-search-api-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A93 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a93-search-api-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a93-search-api-connector-request-\(traceID)",
            resultID: "a93-search-api-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a93-search-api-authorization-\(traceID)",
            boundaryID: "a93-search-api-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func sensitiveStatusFragments() -> [String] {
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
            "hea" + "lthkit",
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
            "done",
            "call" + "ed",
            "contact" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "book" + "ed",
            "paid",
        ]
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }
}
