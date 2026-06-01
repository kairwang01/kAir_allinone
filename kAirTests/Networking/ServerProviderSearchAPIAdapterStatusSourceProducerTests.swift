//
//  ServerProviderSearchAPIAdapterStatusSourceProducerTests.swift
//  kAirTests
//
//  A89 Search API adapter status-source producer guard tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPIAdapterStatusSourceProducerTests: XCTestCase {

    func test_inputsPackageRenderedRequestAndResultStatusThroughA87Store() throws {
        let requestDecision = try preparedRequestDecision(
            traceID: "a89-request",
            sourceHost: "request.example.com"
        )
        let resultReceipt = try normalizedResultReceipt(
            traceID: "a89-result",
            sourceHost: "result.example.com"
        )
        let hiddenDecision = try preparedRequestDecision(
            traceID: "a89-hidden",
            sourceHost: "hidden.example.com"
        )
        let source = ServerProviderSearchAPIAdapterStatusSourceProducer().statusSource(
            inputs: [
                .requestDecision(
                    .init(
                        recommendationID: "rec-request",
                        decision: requestDecision
                    )
                ),
                .resultReceipt(
                    .init(
                        recommendationID: "rec-result",
                        receipt: resultReceipt
                    )
                ),
                .requestDecision(
                    .init(
                        recommendationID: "rec-hidden",
                        decision: hiddenDecision
                    )
                ),
            ],
            renderedRecommendationIDs: ["rec-result", "rec-request", "rec-request"]
        )
        let baseline = SearchAPIAdapterProviderStatusStore(
            values: [
                (recommendationID: "rec-request", value: .requestDecision(requestDecision)),
                (recommendationID: "rec-result", value: .resultReceipt(resultReceipt)),
                (recommendationID: "rec-hidden", value: .requestDecision(hiddenDecision)),
            ]
        )

        let requestPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-request")
        )
        let resultPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-result")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-request", "rec-result"])
        XCTAssertEqual(
            requestPresentation,
            baseline.providerStatusPresentation(for: "rec-request")
        )
        XCTAssertEqual(
            resultPresentation,
            baseline.providerStatusPresentation(for: "rec-result")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(requestPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: requestPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: requestPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: requestPresentation)?.tone, .positive)
        XCTAssertTrue(requestPresentation.statusLine.contains("Search API adapter request"))
        XCTAssertTrue(requestPresentation.statusLine.contains("request.example.com"))
        XCTAssertTrue(requestPresentation.statusLine.contains("No provider runtime has run"))

        XCTAssertEqual(resultPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: resultPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: resultPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: resultPresentation)?.tone, .positive)
        XCTAssertTrue(resultPresentation.statusLine.contains("normalized from cited metadata"))
        XCTAssertTrue(resultPresentation.statusLine.contains("result.example.com"))
        XCTAssertTrue(resultPresentation.statusLine.contains("No provider runtime has run"))
    }

    func test_rejectedInputsRemainNonSuccessAndAdvisoryOnly() throws {
        let privateDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: "a89-private",
                privacyClass: .private,
                sourceHost: "private.example.com"
            ),
            connectorReceipt: connectorReceipt(traceID: "a89-private"),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let citationMissingReceipt = try rejectedResultReceipt(
            traceID: "a89-citation-missing",
            sourceHost: "citation.example.com"
        )
        let source = ServerProviderSearchAPIAdapterStatusSourceProducer().statusSource(
            inputs: [
                .requestDecision(
                    .init(
                        recommendationID: "rec-private",
                        decision: privateDecision
                    )
                ),
                .resultReceipt(
                    .init(
                        recommendationID: "rec-citation",
                        receipt: citationMissingReceipt
                    )
                ),
            ],
            renderedRecommendationIDs: ["rec-private", "rec-citation"]
        )

        let privatePresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-private")
        )
        let citationPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-citation")
        )
        let text = [
            privatePresentation,
            citationPresentation,
        ]
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertEqual(privateDecision.state, .rejected)
        XCTAssertEqual(privateDecision.rejection, .privacyBlocked)
        XCTAssertEqual(citationMissingReceipt.state, .rejected)
        XCTAssertEqual(citationMissingReceipt.rejection, .resultCitationMissing)

        XCTAssertEqual(privatePresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: privatePresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: privatePresentation))
        XCTAssertNil(badge(.meteredPremium, in: privatePresentation))
        XCTAssertTrue(privatePresentation.statusLine.contains("privacyBlocked"))

        XCTAssertEqual(citationPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: citationPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: citationPresentation))
        XCTAssertNil(badge(.meteredPremium, in: citationPresentation))
        XCTAssertTrue(citationPresentation.statusLine.contains("resultCitationMissing"))

        XCTAssertTrue(text.contains("no provider runtime has run"))
        for forbidden in sensitiveStatusFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status-source wording: \(forbidden)")
        }
    }

    func test_duplicateRecommendationIDsKeepFirstInput() throws {
        let first = try preparedRequestDecision(
            traceID: "a89-duplicate-first",
            sourceHost: "first.example.com",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let second = try normalizedResultReceipt(
            traceID: "a89-duplicate-second",
            sourceHost: "second.example.com"
        )
        let source = ServerProviderSearchAPIAdapterStatusSourceProducer().statusSource(
            inputs: [
                .requestDecision(
                    .init(
                        recommendationID: "rec-duplicate",
                        decision: first
                    )
                ),
                .resultReceipt(
                    .init(
                        recommendationID: "rec-duplicate",
                        receipt: second
                    )
                ),
            ],
            renderedRecommendationIDs: ["rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("Search API adapter request"))
        XCTAssertTrue(presentation.statusLine.contains("first.example.com"))
        XCTAssertFalse(presentation.statusLine.contains("normalized from cited metadata"))
        XCTAssertFalse(presentation.statusLine.contains("second.example.com"))
    }

    private func preparedRequestDecision(
        traceID: String,
        sourceHost: String,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        entitlements: Set<ProviderFamily> = [.searchAPI]
    ) throws -> ServerProviderSearchAPIAdapterRequestDecision {
        let decision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                privacyClass: privacyClass,
                costClass: costClass,
                freshness: freshness,
                entitlements: entitlements,
                sourceHost: sourceHost
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                costClass: costClass,
                freshness: freshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee"),
            resultLimit: 4
        )
        XCTAssertEqual(decision.state, .requestPrepared)
        XCTAssertNotNil(decision.request)
        return decision
    }

    private func normalizedResultReceipt(
        traceID: String,
        sourceHost: String,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterResultReceipt {
        let request = try XCTUnwrap(
            preparedRequestDecision(
                traceID: traceID,
                sourceHost: sourceHost,
                freshness: freshness
            ).request
        )
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary with cited source metadata.",
                freshness: freshness,
                citations: [
                    ServerProviderSearchAPIAdapterCitation(
                        sourceURL: try citationURL(sourceHost: sourceHost),
                        title: "Coffee source",
                        attribution: "Public Source"
                    ),
                ],
                limitations: ["Read-only public information."]
            )
        )
        XCTAssertEqual(receipt.state, .resultNormalized)
        XCTAssertNotNil(receipt.result)
        return receipt
    }

    private func rejectedResultReceipt(
        traceID: String,
        sourceHost: String
    ) throws -> ServerProviderSearchAPIAdapterResultReceipt {
        let request = try XCTUnwrap(
            preparedRequestDecision(
                traceID: traceID,
                sourceHost: sourceHost
            ).request
        )
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary.",
                freshness: .livePreferred,
                citations: []
            )
        )
        XCTAssertEqual(receipt.state, .rejected)
        XCTAssertEqual(receipt.rejection, .resultCitationMissing)
        return receipt
    }

    private func envelope(
        traceID: String,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        entitlements: Set<ProviderFamily> = [.searchAPI],
        sourceHost: String
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
            id: "a89-search-api-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A89 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a89-search-api-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a89-search-api-connector-request-\(traceID)",
            resultID: "a89-search-api-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a89-search-api-authorization-\(traceID)",
            boundaryID: "a89-search-api-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func citationURL(
        sourceHost: String
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = sourceHost
        components.path = "/coffee"
        return try XCTUnwrap(components.url)
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
            "payload",
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
