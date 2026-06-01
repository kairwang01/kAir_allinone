//
//  ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests.swift
//  kAirTests
//
//  A97 Search API adapter fixture bridge status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducerTests: XCTestCase {

    func test_readyFixtureBridgeResponsesPackageAsAdvisoryStatusForRenderedIDs() throws {
        let ready = try readyResponse(
            traceID: "a97-ready",
            sourceHost: "fixture.example.com"
        )
        let hidden = try readyResponse(
            traceID: "a97-hidden",
            sourceHost: "hidden.example.com"
        )

        let source = ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer()
            .statusSource(
                responses: [
                    .init(recommendationID: "rec-ready", response: ready.response),
                    .init(recommendationID: "rec-hidden", response: hidden.response),
                ],
                renderedRecommendationIDs: ["rec-ready", "rec-ready"]
            )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-ready")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-ready"])
        XCTAssertEqual(presentation.recommendationID, "rec-ready")
        XCTAssertEqual(presentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: presentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: presentation)?.tone, .positive)
        XCTAssertTrue(presentation.statusLine.contains("fixture bridge audit metadata"))
        XCTAssertTrue(presentation.statusLine.contains(ready.request.id))
        XCTAssertTrue(presentation.statusLine.contains(try XCTUnwrap(ready.response.payloadID)))
        XCTAssertTrue(presentation.statusLine.contains(try XCTUnwrap(ready.response.dispatchReceiptID)))
        XCTAssertTrue(presentation.statusLine.contains("fixture.example.com"))
        XCTAssertTrue(presentation.statusLine.contains("No transport or provider runtime has run"))
        XCTAssertFalse(presentation.statusLine.contains("public coffee"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_rejectedFixtureBridgeResponsesPackageAsNonSuccessAdvisoryStatus() throws {
        let privateRejected = try rejectedResponseFromPrivateRequest()
        let sourceMismatch = try rejectedResponseFromSourceMismatch()

        let source = ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer()
            .statusSource(
                responses: [
                    .init(recommendationID: "rec-private", response: privateRejected),
                    .init(recommendationID: "rec-source", response: sourceMismatch),
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

        XCTAssertEqual(privateRejected.state, .rejected)
        XCTAssertEqual(privateRejected.rejection, .requestDecisionRejected)
        XCTAssertEqual(privateRejected.requestDecisionRejection, .privacyBlocked)
        XCTAssertEqual(privatePresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: privatePresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: privatePresentation))
        XCTAssertNil(badge(.meteredPremium, in: privatePresentation))
        XCTAssertTrue(privatePresentation.statusLine.contains("requestDecisionRejected"))
        XCTAssertTrue(privatePresentation.statusLine.contains("privacyBlocked"))

        XCTAssertEqual(sourceMismatch.state, .rejected)
        XCTAssertEqual(sourceMismatch.rejection, .sourcePolicyMismatch)
        XCTAssertEqual(sourcePresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.termsBlocked, in: sourcePresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: sourcePresentation))
        XCTAssertNil(badge(.meteredPremium, in: sourcePresentation))
        XCTAssertTrue(sourcePresentation.statusLine.contains("sourcePolicyMismatch"))

        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        for forbidden in sensitiveStatusFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected fixture status wording: \(forbidden)")
        }
    }

    func test_duplicateRecommendationIDsKeepFirstInputAndMissingIDsReturnNil() throws {
        let first = try readyResponse(
            traceID: "a97-duplicate-first",
            sourceHost: "first.example.com",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let second = try readyResponse(
            traceID: "a97-duplicate-second",
            sourceHost: "second.example.com",
            costClass: .meteredPremium,
            freshness: .livePreferred
        )

        let source = ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer()
            .statusSource(
                responses: [
                    .init(recommendationID: "rec-duplicate", response: first.response),
                    .init(recommendationID: "rec-duplicate", response: second.response),
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
        XCTAssertNil(source.providerStatusPresentation(for: "a97-duplicate-first"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyStaysAdvisoryAndValueOnly() throws {
        let ready = try readyResponse(
            traceID: "a97-copy-ready",
            sourceHost: "copy.example.com"
        )
        let privateRejected = try rejectedResponseFromPrivateRequest()
        let source = ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer()
            .statusSource(
                responses: [
                    .init(recommendationID: "rec-copy-ready", response: ready.response),
                    .init(recommendationID: "rec-copy-private", response: privateRejected),
                ],
                renderedRecommendationIDs: ["rec-copy-ready", "rec-copy-private"]
            )

        let text = [
            try XCTUnwrap(source.providerStatusPresentation(for: "rec-copy-ready")),
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

    func test_costAndEntitlementMatrixPreservesExplicitStatusAcrossAdapterChain() throws {
        let included = try allowedMatrixChain(
            traceID: "a100-included-quota",
            sourceHost: "included.example.com",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let metered = try allowedMatrixChain(
            traceID: "a100-metered-premium",
            sourceHost: "metered.example.com",
            costClass: .meteredPremium,
            freshness: .livePreferred
        )
        let missingEntitlement = try blockedMatrixChain(
            traceID: "a100-missing-entitlement",
            sourceHost: "missing-entitlement.example.com",
            costClass: .meteredPremium,
            entitlements: [],
            expectedRequestRejection: .entitlementMissing
        )
        let blockedCost = try blockedMatrixChain(
            traceID: "a100-blocked-cost",
            sourceHost: "blocked-cost.example.com",
            costClass: .blockedByCost,
            expectedRequestRejection: .quotaBlocked
        )
        let privatePrivacy = try blockedMatrixChain(
            traceID: "a100-private-privacy",
            sourceHost: "private-privacy.example.com",
            privacyClass: .private,
            costClass: .meteredPremium,
            expectedRequestRejection: .privacyBlocked
        )
        let freeLocal = try blockedMatrixChain(
            traceID: "a100-free-local",
            sourceHost: "free-local.example.com",
            costClass: .freeLocal,
            expectedRequestRejection: .quotaBlocked
        )

        XCTAssertEqual(included.requestDecision.state, .requestPrepared)
        XCTAssertEqual(included.request.costClass, .includedQuota)
        XCTAssertEqual(included.payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(included.dispatchReceipt.state, .dispatchEligible)
        XCTAssertTrue(included.dispatchReceipt.isDispatchEligible)
        XCTAssertEqual(included.response.state, .fixtureReady)
        XCTAssertEqual(included.response.costClass, .includedQuota)
        XCTAssertEqual(included.presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: included.presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: included.presentation))
        XCTAssertTrue(included.presentation.statusLine.contains("Cost: includedQuota"))
        XCTAssertFalse(included.presentation.statusLine.contains("meteredPremium"))

        XCTAssertEqual(metered.requestDecision.state, .requestPrepared)
        XCTAssertEqual(metered.request.costClass, .meteredPremium)
        XCTAssertEqual(metered.payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(metered.dispatchReceipt.state, .dispatchEligible)
        XCTAssertTrue(metered.dispatchReceipt.isDispatchEligible)
        XCTAssertEqual(metered.response.state, .fixtureReady)
        XCTAssertEqual(metered.response.costClass, .meteredPremium)
        XCTAssertEqual(metered.presentation.cardHint, .warning)
        XCTAssertEqual(badge(.meteredPremium, in: metered.presentation)?.tone, .neutral)
        XCTAssertNil(badge(.includedQuota, in: metered.presentation))
        XCTAssertTrue(metered.presentation.statusLine.contains("Cost: meteredPremium"))
        XCTAssertFalse(metered.presentation.statusLine.contains("includedQuota"))

        let blockedCases = [
            missingEntitlement,
            blockedCost,
            privatePrivacy,
            freeLocal,
        ]
        for blocked in blockedCases {
            XCTAssertEqual(blocked.requestDecision.state, .rejected, blocked.id)
            XCTAssertEqual(blocked.requestDecision.rejection, blocked.expectedRequestRejection, blocked.id)
            XCTAssertEqual(blocked.payloadDecision.state, .rejected, blocked.id)
            XCTAssertEqual(blocked.payloadDecision.rejection, .requestDecisionRejected, blocked.id)
            XCTAssertEqual(blocked.payloadDecision.requestDecisionRejection, blocked.expectedRequestRejection, blocked.id)
            XCTAssertEqual(blocked.dispatchReceipt.state, .blocked, blocked.id)
            XCTAssertFalse(blocked.dispatchReceipt.isDispatchEligible, blocked.id)
            XCTAssertEqual(blocked.dispatchReceipt.rejection, .payloadDecisionRejected, blocked.id)
            XCTAssertEqual(blocked.response.state, .rejected, blocked.id)
            XCTAssertFalse(blocked.response.isFixtureReady, blocked.id)
            XCTAssertEqual(blocked.response.rejection, .requestDecisionRejected, blocked.id)
            XCTAssertEqual(blocked.response.requestDecisionRejection, blocked.expectedRequestRejection, blocked.id)
            XCTAssertEqual(blocked.presentation.cardHint, .disabled, blocked.id)
            XCTAssertNil(badge(.meteredPremium, in: blocked.presentation), blocked.id)
            XCTAssertNil(badge(.includedQuota, in: blocked.presentation), blocked.id)
            XCTAssertFalse(blocked.presentation.statusLine.contains("Cost: meteredPremium"), blocked.id)
            XCTAssertTrue(
                blocked.presentation.statusLine.contains(blocked.expectedRequestRejection.rawValue),
                blocked.id
            )
        }

        XCTAssertEqual(badge(.unavailable, in: missingEntitlement.presentation)?.tone, .warning)
        XCTAssertEqual(badge(.costBlocked, in: blockedCost.presentation)?.tone, .warning)
        XCTAssertEqual(badge(.privacyBlocked, in: privatePrivacy.presentation)?.tone, .warning)
        XCTAssertEqual(badge(.costBlocked, in: freeLocal.presentation)?.tone, .warning)

        let matrixText = ([included.presentation, metered.presentation] + blockedCases.map(\.presentation))
            .flatMap { [$0.statusLine] + $0.badges.map(\.label) }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(matrixText.contains("included quota"))
        XCTAssertTrue(matrixText.contains("premium metered"))
        XCTAssertTrue(matrixText.contains("entitlementmissing"))
        XCTAssertTrue(matrixText.contains("quotablocked"))
        XCTAssertTrue(matrixText.contains("privacyblocked"))
        XCTAssertFalse(matrixText.contains("public coffee"))
        for forbidden in sensitiveStatusFragments() + executionClaimFragments() {
            XCTAssertFalse(matrixText.contains(forbidden), "Unexpected matrix status wording: \(forbidden)")
        }
    }

    func test_sourceCitationAttributionMatrixPreservesExplicitStatusAcrossAdapterChain() throws {
        let accepted = try acceptedSourceCitationChain(
            traceID: "a101-accepted-source",
            sourceHost: "selected-source.example.com"
        )
        let sourceBlocked = try blockedSourceCitationChain(
            traceID: "a101-source-blocked",
            sourceHost: "blocked-source.example.com",
            sourceState: .blocked,
            attributionRequired: true,
            expectedRequestRejection: .sourcePolicyInsufficient
        )
        let citationPolicyMissing = try blockedSourceCitationChain(
            traceID: "a101-citation-policy-missing",
            sourceHost: "citation-policy.example.com",
            sourceState: .passed,
            attributionRequired: false,
            expectedRequestRejection: .citationPolicyMissing
        )
        let citationMissing = try rejectedResultCitationStatus(
            traceID: "a101-result-citation-missing",
            requiredSourceHost: "result-citation.example.com",
            citationSourceHost: nil,
            expectedResultRejection: .resultCitationMissing
        )
        let citationSourceMismatch = try rejectedResultCitationStatus(
            traceID: "a101-result-citation-mismatch",
            requiredSourceHost: "result-required.example.com",
            citationSourceHost: "mismatched-source.example.com",
            expectedResultRejection: .resultCitationSourceMismatch
        )

        XCTAssertEqual(accepted.requestDecision.state, .requestPrepared)
        XCTAssertEqual(accepted.request.sourcePolicy.sourceState, .passed)
        XCTAssertTrue(accepted.request.sourcePolicy.attributionRequired)
        XCTAssertTrue(accepted.request.sourcePolicy.citationRequired)
        XCTAssertEqual(accepted.request.sourcePolicy.sourceHost, "selected-source.example.com")
        XCTAssertEqual(accepted.payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(accepted.dispatchReceipt.state, .dispatchEligible)
        XCTAssertTrue(accepted.dispatchReceipt.isDispatchEligible)
        XCTAssertEqual(accepted.response.state, .fixtureReady)
        XCTAssertEqual(accepted.resultReceipt.state, .resultNormalized)
        XCTAssertEqual(
            accepted.resultReceipt.result?.citations.first?.sourceHost,
            "selected-source.example.com"
        )
        XCTAssertEqual(
            accepted.resultReceipt.result?.citations.first?.attribution,
            "Public Source"
        )
        XCTAssertTrue(accepted.fixtureText.contains("source: passed"))
        XCTAssertTrue(accepted.fixtureText.contains("citation required"))
        XCTAssertTrue(accepted.fixtureText.contains("selected-source.example.com"))
        XCTAssertTrue(accepted.resultText.contains("selected-source.example.com"))
        XCTAssertFalse(accepted.fixtureText.contains("hidden-source.example.com"))
        XCTAssertFalse(accepted.resultText.contains("hidden-source.example.com"))
        XCTAssertFalse(accepted.fixtureText.contains("public coffee"))
        XCTAssertFalse(accepted.resultText.contains("public coffee"))

        for blocked in [sourceBlocked, citationPolicyMissing] {
            XCTAssertEqual(blocked.requestDecision.state, .rejected, blocked.id)
            XCTAssertEqual(blocked.requestDecision.rejection, blocked.expectedRequestRejection, blocked.id)
            XCTAssertEqual(blocked.payloadDecision.state, .rejected, blocked.id)
            XCTAssertEqual(blocked.payloadDecision.rejection, .requestDecisionRejected, blocked.id)
            XCTAssertEqual(blocked.dispatchReceipt.state, .blocked, blocked.id)
            XCTAssertFalse(blocked.dispatchReceipt.isDispatchEligible, blocked.id)
            XCTAssertEqual(blocked.response.state, .rejected, blocked.id)
            XCTAssertFalse(blocked.response.isFixtureReady, blocked.id)
            XCTAssertEqual(blocked.response.rejection, .requestDecisionRejected, blocked.id)
            XCTAssertEqual(blocked.response.requestDecisionRejection, blocked.expectedRequestRejection, blocked.id)
            XCTAssertEqual(blocked.presentation.cardHint, .disabled, blocked.id)
            XCTAssertTrue(blocked.text.contains(blocked.expectedRequestRejection.rawValue.lowercased()), blocked.id)
            XCTAssertFalse(blocked.text.contains("hidden-source.example.com"), blocked.id)
            XCTAssertFalse(blocked.text.contains("public coffee"), blocked.id)
        }

        for rejectedResult in [citationMissing, citationSourceMismatch] {
            XCTAssertEqual(rejectedResult.receipt.state, .rejected, rejectedResult.id)
            XCTAssertEqual(rejectedResult.receipt.rejection, rejectedResult.expectedResultRejection, rejectedResult.id)
            XCTAssertNil(rejectedResult.receipt.result, rejectedResult.id)
            XCTAssertEqual(rejectedResult.presentation.cardHint, .disabled, rejectedResult.id)
            XCTAssertEqual(badge(.termsBlocked, in: rejectedResult.presentation)?.tone, .warning, rejectedResult.id)
            XCTAssertNil(badge(.remoteProvider, in: rejectedResult.presentation), rejectedResult.id)
            XCTAssertNil(badge(.meteredPremium, in: rejectedResult.presentation), rejectedResult.id)
            XCTAssertTrue(rejectedResult.text.contains(rejectedResult.expectedResultRejection.rawValue.lowercased()), rejectedResult.id)
            XCTAssertFalse(rejectedResult.text.contains("public coffee"), rejectedResult.id)
            XCTAssertFalse(rejectedResult.text.contains("hidden-source.example.com"), rejectedResult.id)
        }
        XCTAssertFalse(citationSourceMismatch.text.contains("mismatched-source.example.com"))
        XCTAssertFalse(citationSourceMismatch.fixtureText.contains("mismatched-source.example.com"))
        XCTAssertTrue(citationSourceMismatch.fixtureText.contains("result-required.example.com"))

        let matrixText = [
            accepted.fixtureText,
            accepted.resultText,
            sourceBlocked.text,
            citationPolicyMissing.text,
            citationMissing.text,
            citationSourceMismatch.text,
        ].joined(separator: "\n")

        for forbidden in sensitiveStatusFragments() + executionClaimFragments() {
            XCTAssertFalse(matrixText.contains(forbidden), "Unexpected source/citation matrix wording: \(forbidden)")
        }
    }

    func test_resultFreshnessContentAndLimitationsMatrixPreservesExplicitStatus() throws {
        let fresh = try acceptedResultFreshnessStatus(
            traceID: "a102-fresh-result",
            requestFreshness: .livePreferred,
            resultFreshness: .livePreferred,
            sourceHost: "fresh-result.example.com"
        )
        let cached = try acceptedResultFreshnessStatus(
            traceID: "a102-cached-result",
            requestFreshness: .cachedOK,
            resultFreshness: .cachedOK,
            sourceHost: "cached-result.example.com"
        )
        let limitations = try acceptedResultFreshnessStatus(
            traceID: "a102-limitations-result",
            requestFreshness: .livePreferred,
            resultFreshness: .livePreferred,
            sourceHost: "limitations-result.example.com",
            limitations: [
                "Read-only limitation summary.",
                "Hidden host hidden-result.example.com.",
            ]
        )
        let stale = try rejectedResultFreshnessStatus(
            traceID: "a102-stale-live-required",
            requestFreshness: .liveRequired,
            resultFreshness: .cachedOK,
            sourceHost: "stale-result.example.com",
            expectedResultRejection: .resultStaleForLiveRequired
        )
        let missingContent = try rejectedResultFreshnessStatus(
            traceID: "a102-missing-content",
            requestFreshness: .livePreferred,
            resultFreshness: .livePreferred,
            sourceHost: "missing-content.example.com",
            title: " ",
            snippet: " ",
            expectedResultRejection: .resultContentMissing
        )

        XCTAssertEqual(fresh.receipt.state, .resultNormalized)
        XCTAssertEqual(fresh.receipt.result?.freshness, .livePreferred)
        XCTAssertEqual(fresh.presentation.cardHint, .warning)
        XCTAssertEqual(badge(.liveFreshness, in: fresh.presentation)?.tone, .positive)
        XCTAssertTrue(fresh.text.contains("freshness: livepreferred"))
        XCTAssertTrue(fresh.text.contains("fresh-result.example.com"))
        XCTAssertFalse(fresh.text.contains("hidden-result.example.com"))
        XCTAssertFalse(fresh.text.contains("public coffee"))

        XCTAssertEqual(cached.receipt.state, .resultNormalized)
        XCTAssertEqual(cached.receipt.result?.freshness, .cachedOK)
        XCTAssertEqual(cached.presentation.cardHint, .warning)
        XCTAssertNil(badge(.liveFreshness, in: cached.presentation))
        XCTAssertTrue(cached.text.contains("freshness: cachedok"))
        XCTAssertTrue(cached.text.contains("cached-result.example.com"))
        XCTAssertFalse(cached.text.contains("freshness: livepreferred"))
        XCTAssertFalse(cached.text.contains("hidden-result.example.com"))
        XCTAssertFalse(cached.text.contains("public coffee"))

        XCTAssertEqual(limitations.receipt.state, .resultNormalized)
        XCTAssertEqual(
            limitations.receipt.result?.limitations,
            [
                "Read-only limitation summary.",
                "Hidden host hidden-result.example.com.",
            ]
        )
        XCTAssertTrue(limitations.text.contains("limitations-result.example.com"))
        XCTAssertFalse(limitations.text.contains("read-only limitation summary"))
        XCTAssertFalse(limitations.text.contains("hidden-result.example.com"))
        XCTAssertFalse(limitations.text.contains("public coffee"))

        for rejected in [stale, missingContent] {
            XCTAssertEqual(rejected.receipt.state, .rejected, rejected.id)
            XCTAssertEqual(rejected.receipt.rejection, rejected.expectedResultRejection, rejected.id)
            XCTAssertNil(rejected.receipt.result, rejected.id)
            XCTAssertEqual(rejected.presentation.cardHint, .disabled, rejected.id)
            XCTAssertNil(badge(.remoteProvider, in: rejected.presentation), rejected.id)
            XCTAssertNil(badge(.meteredPremium, in: rejected.presentation), rejected.id)
            XCTAssertTrue(rejected.text.contains(rejected.expectedResultRejection.rawValue.lowercased()), rejected.id)
            XCTAssertFalse(rejected.text.contains("hidden-result.example.com"), rejected.id)
            XCTAssertFalse(rejected.text.contains("public coffee"), rejected.id)
        }
        XCTAssertEqual(badge(.staleCache, in: stale.presentation)?.tone, .warning)
        XCTAssertEqual(badge(.termsBlocked, in: missingContent.presentation)?.tone, .warning)

        let matrixText = [
            fresh.text,
            cached.text,
            limitations.text,
            stale.text,
            missingContent.text,
        ].joined(separator: "\n")

        for forbidden in sensitiveStatusFragments() + executionClaimFragments() {
            XCTAssertFalse(matrixText.contains(forbidden), "Unexpected freshness/content matrix wording: \(forbidden)")
        }
    }

    private func readyResponse(
        traceID: String,
        sourceHost: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> (
        request: ServerProviderSearchAPIAdapterRequest,
        response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
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
        let request = try XCTUnwrap(requestDecision.request)
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: requestDecision
        )
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )

        XCTAssertEqual(response.state, .fixtureReady)
        XCTAssertTrue(response.isFixtureReady)
        return (request, response)
    }

    private func allowedMatrixChain(
        traceID: String,
        sourceHost: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness
    ) throws -> (
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
        request: ServerProviderSearchAPIAdapterRequest,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse,
        presentation: ProviderStatusPresentation
    ) {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
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
        let request = try XCTUnwrap(requestDecision.request)
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: requestDecision
        )
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )
        let presentation = try fixturePresentation(
            recommendationID: "rec-\(traceID)",
            response: response
        )

        return (
            requestDecision,
            request,
            payloadDecision,
            dispatchReceipt,
            response,
            presentation
        )
    }

    private func blockedMatrixChain(
        traceID: String,
        sourceHost: String,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass,
        entitlements: Set<ProviderFamily> = [.searchAPI],
        expectedRequestRejection: ServerProviderSearchAPIAdapterRejectionReason
    ) throws -> (
        id: String,
        expectedRequestRejection: ServerProviderSearchAPIAdapterRejectionReason,
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse,
        presentation: ProviderStatusPresentation
    ) {
        let baseline = try readyResponse(
            traceID: "\(traceID)-baseline",
            sourceHost: "\(sourceHost)-baseline"
        )
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                sourceHost: sourceHost,
                privacyClass: privacyClass,
                costClass: costClass,
                entitlements: entitlements
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                costClass: costClass
            ),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: requestDecision
        )
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: baseline.request
        )
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )
        let presentation = try fixturePresentation(
            recommendationID: "rec-\(traceID)",
            response: response
        )

        return (
            traceID,
            expectedRequestRejection,
            requestDecision,
            payloadDecision,
            dispatchReceipt,
            response,
            presentation
        )
    }

    private func fixturePresentation(
        recommendationID: String,
        response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse
    ) throws -> ProviderStatusPresentation {
        let source = ServerProviderSearchAPIAdapterFixtureTransportStatusSourceProducer()
            .statusSource(
                responses: [
                    .init(recommendationID: recommendationID, response: response),
                ],
                renderedRecommendationIDs: [recommendationID]
            )
        return try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))
    }

    private func acceptedSourceCitationChain(
        traceID: String,
        sourceHost: String
    ) throws -> (
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
        request: ServerProviderSearchAPIAdapterRequest,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse,
        resultReceipt: ServerProviderSearchAPIAdapterResultReceipt,
        fixtureText: String,
        resultText: String
    ) {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                sourceHost: sourceHost
            ),
            connectorReceipt: connectorReceipt(traceID: traceID),
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
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )
        let resultReceipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: try resultCandidate(
                sourceHost: sourceHost
            )
        )
        let fixturePresentation = try fixturePresentation(
            recommendationID: "rec-\(traceID)-fixture",
            response: response
        )
        let resultPresentation = try resultStatusPresentation(
            recommendationID: "rec-\(traceID)-result",
            receipt: resultReceipt
        )

        return (
            requestDecision,
            request,
            payloadDecision,
            dispatchReceipt,
            response,
            resultReceipt,
            providerStatusText(fixturePresentation),
            providerStatusText(resultPresentation)
        )
    }

    private func blockedSourceCitationChain(
        traceID: String,
        sourceHost: String,
        sourceState: ServerSourcePolicyState,
        attributionRequired: Bool,
        expectedRequestRejection: ServerProviderSearchAPIAdapterRejectionReason
    ) throws -> (
        id: String,
        expectedRequestRejection: ServerProviderSearchAPIAdapterRejectionReason,
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        response: ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse,
        presentation: ProviderStatusPresentation,
        text: String
    ) {
        let baseline = try readyResponse(
            traceID: "\(traceID)-baseline",
            sourceHost: "\(sourceHost)-baseline"
        )
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                sourceHost: sourceHost,
                sourceState: sourceState,
                attributionRequired: attributionRequired
            ),
            connectorReceipt: connectorReceipt(traceID: traceID),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: requestDecision
        )
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: baseline.request
        )
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )
        let presentation = try fixturePresentation(
            recommendationID: "rec-\(traceID)",
            response: response
        )

        return (
            traceID,
            expectedRequestRejection,
            requestDecision,
            payloadDecision,
            dispatchReceipt,
            response,
            presentation,
            providerStatusText(presentation)
        )
    }

    private func rejectedResultCitationStatus(
        traceID: String,
        requiredSourceHost: String,
        citationSourceHost: String?,
        expectedResultRejection: ServerProviderSearchAPIAdapterRejectionReason
    ) throws -> (
        id: String,
        expectedResultRejection: ServerProviderSearchAPIAdapterRejectionReason,
        receipt: ServerProviderSearchAPIAdapterResultReceipt,
        presentation: ProviderStatusPresentation,
        text: String,
        fixtureText: String
    ) {
        let accepted = try acceptedSourceCitationChain(
            traceID: "\(traceID)-baseline",
            sourceHost: requiredSourceHost
        )
        let candidate: ServerProviderSearchAPIAdapterResultCandidate
        if let citationSourceHost {
            candidate = try resultCandidate(sourceHost: citationSourceHost)
        } else {
            candidate = ServerProviderSearchAPIAdapterResultCandidate(
                title: "Coffee options",
                snippet: "Public summary with cited source metadata.",
                freshness: .livePreferred,
                citations: []
            )
        }
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: accepted.request,
            candidate: candidate
        )
        let presentation = try resultStatusPresentation(
            recommendationID: "rec-\(traceID)",
            receipt: receipt
        )

        return (
            traceID,
            expectedResultRejection,
            receipt,
            presentation,
            providerStatusText(presentation),
            accepted.fixtureText
        )
    }

    private func resultStatusPresentation(
        recommendationID: String,
        receipt: ServerProviderSearchAPIAdapterResultReceipt
    ) throws -> ProviderStatusPresentation {
        let source = ServerProviderSearchAPIAdapterStatusSourceProducer().statusSource(
            inputs: [
                .resultReceipt(
                    .init(recommendationID: recommendationID, receipt: receipt)
                ),
            ],
            renderedRecommendationIDs: [recommendationID]
        )
        return try XCTUnwrap(source.providerStatusPresentation(for: recommendationID))
    }

    private func acceptedResultFreshnessStatus(
        traceID: String,
        requestFreshness: ProviderFreshness,
        resultFreshness: ProviderFreshness,
        sourceHost: String,
        limitations: [String] = ["Read-only public information."]
    ) throws -> (
        receipt: ServerProviderSearchAPIAdapterResultReceipt,
        presentation: ProviderStatusPresentation,
        text: String
    ) {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                sourceHost: sourceHost,
                freshness: requestFreshness
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                freshness: requestFreshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        let request = try XCTUnwrap(requestDecision.request)
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: try resultCandidate(
                sourceHost: sourceHost,
                freshness: resultFreshness,
                limitations: limitations
            )
        )
        let presentation = try resultStatusPresentation(
            recommendationID: "rec-\(traceID)",
            receipt: receipt
        )

        return (
            receipt,
            presentation,
            providerStatusText(presentation)
        )
    }

    private func rejectedResultFreshnessStatus(
        traceID: String,
        requestFreshness: ProviderFreshness,
        resultFreshness: ProviderFreshness,
        sourceHost: String,
        title: String = "Coffee options",
        snippet: String = "Public summary with cited source metadata.",
        expectedResultRejection: ServerProviderSearchAPIAdapterRejectionReason
    ) throws -> (
        id: String,
        expectedResultRejection: ServerProviderSearchAPIAdapterRejectionReason,
        receipt: ServerProviderSearchAPIAdapterResultReceipt,
        presentation: ProviderStatusPresentation,
        text: String
    ) {
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: traceID,
                sourceHost: sourceHost,
                freshness: requestFreshness
            ),
            connectorReceipt: connectorReceipt(
                traceID: traceID,
                freshness: requestFreshness
            ),
            query: ServerProviderSearchAPIAdapterQuery(
                text: "public coffee",
                localeHint: "en-US"
            ),
            resultLimit: 4
        )
        let request = try XCTUnwrap(requestDecision.request)
        let receipt = ServerProviderSearchAPIAdapterContract.normalizeResult(
            request: request,
            candidate: try resultCandidate(
                sourceHost: sourceHost,
                freshness: resultFreshness,
                title: title,
                snippet: snippet
            )
        )
        let presentation = try resultStatusPresentation(
            recommendationID: "rec-\(traceID)",
            receipt: receipt
        )

        return (
            traceID,
            expectedResultRejection,
            receipt,
            presentation,
            providerStatusText(presentation)
        )
    }

    private func resultCandidate(
        sourceHost: String,
        freshness: ProviderFreshness = .livePreferred,
        title: String = "Coffee options",
        snippet: String = "Public summary with cited source metadata.",
        limitations: [String] = ["Read-only public information."]
    ) throws -> ServerProviderSearchAPIAdapterResultCandidate {
        ServerProviderSearchAPIAdapterResultCandidate(
            title: title,
            snippet: snippet,
            freshness: freshness,
            citations: [
                ServerProviderSearchAPIAdapterCitation(
                    sourceURL: try citationLink(sourceHost: sourceHost),
                    title: "Coffee source",
                    attribution: "Public Source"
                ),
            ],
            limitations: limitations
        )
    }

    private func citationLink(sourceHost: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = sourceHost
        components.path = "/coffee"
        return try XCTUnwrap(components.url)
    }

    private func providerStatusText(
        _ presentation: ProviderStatusPresentation
    ) -> String {
        ([presentation.statusLine] + presentation.badges.map(\.label))
            .joined(separator: "\n")
            .lowercased()
    }

    private func rejectedResponseFromPrivateRequest() throws -> ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse {
        let ready = try readyResponse(
            traceID: "a97-private-baseline",
            sourceHost: "private-baseline.example.com"
        )
        let request = ready.request
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: request
        )
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        let rejectedRequestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: "a97-private-rejected",
                sourceHost: "private.example.com",
                privacyClass: .private
            ),
            connectorReceipt: connectorReceipt(traceID: "a97-private-rejected"),
            query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
        )
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: rejectedRequestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )
        XCTAssertEqual(response.state, .rejected)
        return response
    }

    private func rejectedResponseFromSourceMismatch() throws -> ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse {
        let ready = try readyResponse(
            traceID: "a97-source-mismatch",
            sourceHost: "source.example.com"
        )
        let request = ready.request
        let requestDecision = ServerProviderSearchAPIAdapterContract.prepareRequest(
            envelope: envelope(
                traceID: request.traceID,
                sourceHost: "source.example.com"
            ),
            connectorReceipt: connectorReceipt(traceID: request.traceID),
            query: request.query,
            resultLimit: request.resultLimit
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: requestDecision
        )
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
        let dispatchReceipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )
        let response = ServerProviderSearchAPIAdapterFixtureTransportBridge.evaluate(
            requestDecision: requestDecision,
            payloadDecision: mismatchedDecision,
            dispatchReceipt: dispatchReceipt
        )
        XCTAssertEqual(response.state, .rejected)
        return response
    }

    private func envelope(
        traceID: String,
        sourceHost: String,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        entitlements: Set<ProviderFamily> = [.searchAPI],
        sourceState: ServerSourcePolicyState = .passed,
        attributionRequired: Bool = true
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
                sourceState: sourceState,
                robotsState: .notApplicable,
                attributionRequired: attributionRequired,
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
            id: "a97-search-api-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A97 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a97-search-api-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: .searchAPI,
            requestID: "a97-search-api-connector-request-\(traceID)",
            resultID: "a97-search-api-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: .searchAPI,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a97-search-api-authorization-\(traceID)",
            boundaryID: "a97-search-api-boundary-\(traceID)",
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
