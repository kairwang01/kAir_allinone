//
//  ServerProviderSearchAPITransportResponseStatusSourceProducerTests.swift
//  kAirTests
//
//  A132 Search API transport response status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPITransportResponseStatusSourceProducerTests: XCTestCase {

    func test_responseDecisionsPackageRenderedAcceptedAndRejectedStatus() throws {
        let accepted = acceptedDecision(
            traceID: "a132-accepted",
            vendorID: "a132-accepted-vendor",
            costClass: .meteredPremium,
            freshness: .livePreferred,
            resultShape: .organicLinks,
            requestedResultLimit: 5,
            returnedResultCount: 2,
            citationCount: 3
        )
        let rejected = rejectedDecision(
            id: "a132-rejected-result",
            reason: .adapterResultRejected,
            transportRequestRejection: .resultLimitMismatch,
            adapterResultRejection: .resultCitationMissing
        )
        let hidden = acceptedDecision(
            traceID: "a132-hidden",
            vendorID: "a132-hidden-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            resultShape: .answerSummary,
            requestedResultLimit: 2,
            returnedResultCount: 1,
            citationCount: 1
        )
        let source = ServerProviderSearchAPITransportResponseStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-accepted", decision: accepted),
                    .init(recommendationID: "rec-rejected", decision: rejected),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-rejected",
                    "rec-accepted",
                    "rec-accepted",
                ]
            )
        let baseline = SearchAPITransportResponseProviderStatusStore(
            decisions: [
                (recommendationID: "rec-accepted", decision: accepted),
                (recommendationID: "rec-rejected", decision: rejected),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )

        let acceptedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-accepted")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-accepted", "rec-rejected"])
        XCTAssertEqual(
            acceptedPresentation,
            baseline.providerStatusPresentation(for: "rec-accepted")
        )
        XCTAssertEqual(
            rejectedPresentation,
            baseline.providerStatusPresentation(for: "rec-rejected")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(acceptedPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: acceptedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: acceptedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: acceptedPresentation)?.tone, .positive)
        XCTAssertTrue(acceptedPresentation.statusLine.contains("transport response accepted"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("a132-accepted-vendor"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("a132-accepted-response"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("a132-accepted-transport-request"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("a132-accepted-lease"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("a132-accepted-budget"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("a132-accepted-metered"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("searchAPI"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("webSearch"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("meteredPremium"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("livePreferred"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("organicLinks"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Requested result limit: 5"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Returned results: 2"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Citations: 3"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("Source policy: passed"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("robots notApplicable"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("attribution required true"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("citation required true"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("source host metadata required true"))
        XCTAssertTrue(acceptedPresentation.statusLine.contains("No transport or provider runtime has run"))

        XCTAssertEqual(rejectedPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: rejectedPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: rejectedPresentation))
        XCTAssertNil(badge(.meteredPremium, in: rejectedPresentation))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("blocked by metadata policy"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("adapterResultRejected"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("resultLimitMismatch"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("resultCitationMissing"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
    }

    func test_duplicateRecommendationIDsKeepFirstDecisionAndHiddenMissingStayNil() throws {
        let first = acceptedDecision(
            traceID: "a132-first",
            vendorID: "a132-first-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            resultShape: .answerSummary,
            requestedResultLimit: 3,
            returnedResultCount: 1,
            citationCount: 1
        )
        let duplicate = acceptedDecision(
            traceID: "a132-duplicate",
            vendorID: "a132-duplicate-vendor",
            costClass: .meteredPremium,
            freshness: .liveRequired,
            resultShape: .localBusiness,
            requestedResultLimit: 8,
            returnedResultCount: 4,
            citationCount: 4
        )
        let source = ServerProviderSearchAPITransportResponseStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-dup", decision: first),
                    .init(recommendationID: "rec-dup", decision: duplicate),
                    .init(recommendationID: "rec-hidden", decision: duplicate),
                ],
                renderedRecommendationIDs: [
                    "rec-dup",
                    "rec-hidden-filtered",
                ]
            )

        let presentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-dup"))

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-dup", "rec-hidden-filtered"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertNil(badge(.liveFreshness, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("a132-first-vendor"))
        XCTAssertTrue(presentation.statusLine.contains("a132-first-response"))
        XCTAssertFalse(presentation.statusLine.contains("a132-duplicate-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("a132-duplicate-response"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden-filtered"))
    }

    func test_rejectionMatrixMapsBlockedReasonsAndNestedReasonsToAdvisoryCopy() throws {
        let cases: [
            (
                String,
                ServerProviderSearchAPITransportResponseDecision,
                ProviderStatusBadgeKind
            )
        ] = [
            (
                "missing-request",
                rejectedDecision(id: "a132-missing-request", reason: .missingTransportRequest),
                .unavailable
            ),
            (
                "adapter",
                rejectedDecision(
                    id: "a132-adapter",
                    reason: .adapterResultRejected,
                    adapterResultRejection: .resultCitationMissing
                ),
                .unavailable
            ),
            (
                "request-mismatch",
                rejectedDecision(id: "a132-request-mismatch", reason: .requestIDMismatch),
                .termsBlocked
            ),
            (
                "cost",
                rejectedDecision(id: "a132-cost", reason: .costClassMismatch),
                .costBlocked
            ),
            (
                "overflow",
                rejectedDecision(id: "a132-overflow", reason: .resultLimitOverflow),
                .costBlocked
            ),
            (
                "freshness",
                rejectedDecision(id: "a132-freshness", reason: .freshnessMismatch),
                .staleCache
            ),
            (
                "citation",
                rejectedDecision(id: "a132-citation", reason: .citationMissing),
                .termsBlocked
            ),
            (
                "budget",
                rejectedDecision(id: "a132-budget", reason: .budgetMetadataMissing),
                .costBlocked
            ),
            (
                "nested-request",
                rejectedDecision(
                    id: "a132-nested-request",
                    reason: .transportRequestDecisionRejected,
                    transportRequestRejection: .authorizationNotAccepted
                ),
                .unavailable
            ),
        ]
        let source = ServerProviderSearchAPITransportResponseStatusSourceProducer()
            .statusSource(
                inputs: cases.map { entry in
                    .init(recommendationID: "rec-\(entry.0)", decision: entry.1)
                },
                renderedRecommendationIDs: cases.map { entry in "rec-\(entry.0)" }
            )

        for (id, decision, expectedBadgeKind) in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(id)"),
                id
            )

            XCTAssertEqual(presentation.cardHint, .disabled, id)
            XCTAssertEqual(badge(expectedBadgeKind, in: presentation)?.tone, .warning, id)
            XCTAssertNil(badge(.remoteProvider, in: presentation), id)
            XCTAssertTrue(presentation.statusLine.contains("blocked by metadata policy"), id)
            XCTAssertTrue(presentation.statusLine.contains(try XCTUnwrap(decision.rejection).rawValue), id)
            if let requestReason = decision.transportRequestRejection {
                XCTAssertTrue(presentation.statusLine.contains(requestReason.rawValue), id)
            }
            if let resultReason = decision.adapterResultRejection {
                XCTAssertTrue(presentation.statusLine.contains(resultReason.rawValue), id)
            }
            XCTAssertTrue(presentation.statusLine.contains("No transport or provider runtime has run"), id)
        }
    }

    func test_encodedDebugAndStatusCopiesDoNotLeakRuntimeOrSensitiveFragments() throws {
        let accepted = acceptedDecision(
            traceID: "a132-copy",
            vendorID: "a132-copy-vendor",
            costClass: .meteredPremium,
            freshness: .livePreferred,
            resultShape: .organicLinks,
            requestedResultLimit: 5,
            returnedResultCount: 2,
            citationCount: 3
        )
        let rejected = rejectedDecision(
            id: "a132-copy-rejected",
            reason: .citationMissing,
            transportRequestRejection: .citationPolicyMissing,
            adapterResultRejection: .resultCitationMissing
        )
        let hidden = acceptedDecision(
            traceID: "a132-copy-hidden",
            vendorID: "a132-copy-hidden-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            resultShape: .answerSummary,
            requestedResultLimit: 3,
            returnedResultCount: 1,
            citationCount: 1
        )
        let source = ServerProviderSearchAPITransportResponseStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-copy-accepted", decision: accepted),
                    .init(recommendationID: "rec-copy-rejected", decision: rejected),
                    .init(recommendationID: "rec-copy-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-copy-accepted",
                    "rec-copy-rejected",
                ]
            )
        let acceptedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-copy-accepted")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-copy-rejected")
        )
        let text = [
            try encodedString(accepted),
            try encodedString(rejected),
            accepted.description,
            rejected.description,
            accepted.statusLine,
            rejected.statusLine,
            accepted.response?.description ?? "",
            accepted.response?.statusLine ?? "",
            acceptedPresentation.statusLine,
            rejectedPresentation.statusLine,
            acceptedPresentation.badges.map(\.label).joined(separator: " "),
            rejectedPresentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertNil(source.providerStatusPresentation(for: "rec-copy-hidden"))
        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("a132-copy.example.com"))
        XCTAssertFalse(text.contains("/source"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status wording: \(forbidden)")
        }
    }

    private func acceptedDecision(
        traceID: String,
        vendorID: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        resultShape: ServerProviderSearchAPIVendorResultShape,
        requestedResultLimit: Int,
        returnedResultCount: Int,
        citationCount: Int
    ) -> ServerProviderSearchAPITransportResponseDecision {
        let response = ServerProviderSearchAPITransportResponse(
            id: "\(traceID)-response",
            transportRequestID: "\(traceID)-transport-request",
            adapterResultReceiptID: "\(traceID)-adapter-result-receipt",
            requestID: "\(traceID)-request",
            payloadDecisionID: "\(traceID)-payload-decision",
            payloadID: "\(traceID)-payload",
            dispatchReceiptID: "\(traceID)-dispatch",
            vendorDecisionID: "\(traceID)-vendor-decision",
            authorizationID: "\(traceID)-authorization",
            leaseID: "\(traceID)-lease",
            budgetID: "\(traceID)-budget",
            meteredDecisionID: "\(traceID)-metered",
            providerFamily: .searchAPI,
            vendorID: vendorID,
            capability: .webSearch,
            costClass: costClass,
            freshness: freshness,
            resultShape: resultShape,
            requestedResultLimit: requestedResultLimit,
            returnedResultCount: returnedResultCount,
            citationCount: citationCount,
            sourceCitationSummary: sourceCitationSummary(
                sourceState: .passed,
                citationRequired: true,
                sourceHost: "\(traceID).example.com"
            )
        )

        return ServerProviderSearchAPITransportResponseDecision(
            id: "\(traceID)-response-decision",
            state: .responseAccepted,
            statusLine: response.statusLine,
            response: response,
            rejection: nil,
            transportRequestRejection: nil,
            adapterResultRejection: nil
        )
    }

    private func rejectedDecision(
        id: String,
        reason: ServerProviderSearchAPITransportResponseRejectionReason,
        transportRequestRejection: ServerProviderSearchAPITransportRequestRejectionReason? = nil,
        adapterResultRejection: ServerProviderSearchAPIAdapterRejectionReason? = nil
    ) -> ServerProviderSearchAPITransportResponseDecision {
        ServerProviderSearchAPITransportResponseDecision(
            id: id,
            state: .rejected,
            statusLine: "Search API transport response is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            response: nil,
            rejection: reason,
            transportRequestRejection: transportRequestRejection,
            adapterResultRejection: adapterResultRejection
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

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }

    private func encodedString<T: Encodable>(
        _ value: T
    ) throws -> String {
        try XCTUnwrap(
            String(data: JSONEncoder().encode(value), encoding: .utf8)
        )
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
            "crawl" + "er",
            "m" + "cp",
            "source-host",
            "citation" + "url",
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
