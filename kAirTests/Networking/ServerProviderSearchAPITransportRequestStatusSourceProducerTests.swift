//
//  ServerProviderSearchAPITransportRequestStatusSourceProducerTests.swift
//  kAirTests
//
//  A127 Search API transport request status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPITransportRequestStatusSourceProducerTests: XCTestCase {

    func test_transportRequestDecisionsPackageRenderedPreparedAndRejectedStatus() throws {
        let prepared = preparedDecision(
            traceID: "a127-prepared",
            vendorID: "a127-prepared-vendor",
            costClass: .meteredPremium,
            freshness: .livePreferred,
            resultShape: .organicLinks,
            resultLimit: 5
        )
        let rejected = rejectedDecision(
            id: "a127-rejected-authorization",
            reason: .authorizationNotAccepted,
            authorizationRejection: .vendorPolicyNotAccepted,
            leaseRejection: .authorizationNotAccepted
        )
        let hidden = preparedDecision(
            traceID: "a127-hidden",
            vendorID: "a127-hidden-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            resultShape: .answerSummary,
            resultLimit: 2
        )
        let source = ServerProviderSearchAPITransportRequestStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-prepared", decision: prepared),
                    .init(recommendationID: "rec-rejected", decision: rejected),
                    .init(recommendationID: "rec-hidden", decision: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-rejected",
                    "rec-prepared",
                    "rec-prepared",
                ]
            )
        let baseline = SearchAPITransportRequestProviderStatusStore(
            decisions: [
                (recommendationID: "rec-prepared", decision: prepared),
                (recommendationID: "rec-rejected", decision: rejected),
                (recommendationID: "rec-hidden", decision: hidden),
            ]
        )

        let preparedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-prepared")
        )
        let rejectedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-rejected")
        )

        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-prepared", "rec-rejected"])
        XCTAssertEqual(
            preparedPresentation,
            baseline.providerStatusPresentation(for: "rec-prepared")
        )
        XCTAssertEqual(
            rejectedPresentation,
            baseline.providerStatusPresentation(for: "rec-rejected")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(preparedPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: preparedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: preparedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: preparedPresentation)?.tone, .positive)
        XCTAssertTrue(preparedPresentation.statusLine.contains("transport request prepared"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("a127-prepared-vendor"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("a127-prepared-lease"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("a127-prepared-budget"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("a127-prepared-metered"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("searchAPI"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("webSearch"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("meteredPremium"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("livePreferred"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("organicLinks"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Result limit: 5"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("Source policy: passed"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("robots notApplicable"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("attribution required true"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("citation required true"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("source host metadata required true"))
        XCTAssertTrue(preparedPresentation.statusLine.contains("No transport or provider runtime has run"))

        XCTAssertEqual(rejectedPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: rejectedPresentation)?.tone, .warning)
        XCTAssertNil(badge(.remoteProvider, in: rejectedPresentation))
        XCTAssertNil(badge(.meteredPremium, in: rejectedPresentation))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("blocked by metadata policy"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("authorizationNotAccepted"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("vendorPolicyNotAccepted"))
        XCTAssertTrue(rejectedPresentation.statusLine.contains("No transport or provider runtime has run"))
    }

    func test_duplicateRecommendationIDsKeepFirstDecisionAndHiddenMissingStayNil() throws {
        let first = preparedDecision(
            traceID: "a127-first",
            vendorID: "a127-first-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK,
            resultShape: .answerSummary,
            resultLimit: 3
        )
        let duplicate = preparedDecision(
            traceID: "a127-duplicate",
            vendorID: "a127-duplicate-vendor",
            costClass: .meteredPremium,
            freshness: .liveRequired,
            resultShape: .localBusiness,
            resultLimit: 8
        )
        let source = ServerProviderSearchAPITransportRequestStatusSourceProducer()
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
        XCTAssertTrue(presentation.statusLine.contains("a127-first-vendor"))
        XCTAssertTrue(presentation.statusLine.contains("a127-first-lease"))
        XCTAssertFalse(presentation.statusLine.contains("a127-duplicate-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("a127-duplicate-lease"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden-filtered"))
    }

    func test_rejectionMatrixMapsBlockedReasonsAndNestedReasonsToAdvisoryCopy() throws {
        let cases: [
            (
                String,
                ServerProviderSearchAPITransportRequestDecision,
                ProviderStatusBadgeKind
            )
        ] = [
            (
                "missing-lease",
                rejectedDecision(id: "a127-missing-lease", reason: .missingLease),
                .unavailable
            ),
            (
                "budget",
                rejectedDecision(id: "a127-budget", reason: .budgetContextMismatch),
                .costBlocked
            ),
            (
                "metered",
                rejectedDecision(id: "a127-metered", reason: .missingMeteredDecisionID),
                .costBlocked
            ),
            (
                "freshness",
                rejectedDecision(id: "a127-freshness", reason: .freshnessMismatch),
                .staleCache
            ),
            (
                "terms",
                rejectedDecision(id: "a127-terms", reason: .sourcePolicyMismatch),
                .termsBlocked
            ),
            (
                "nested-request",
                rejectedDecision(
                    id: "a127-nested-request",
                    reason: .requestDecisionRejected,
                    requestDecisionRejection: .privacyBlocked
                ),
                .unavailable
            ),
            (
                "nested-payload",
                rejectedDecision(
                    id: "a127-nested-payload",
                    reason: .payloadNotPrepared,
                    payloadDecisionRejection: .sourcePolicyInsufficient
                ),
                .unavailable
            ),
            (
                "nested-dispatch",
                rejectedDecision(
                    id: "a127-nested-dispatch",
                    reason: .dispatchNotEligible,
                    dispatchReceiptRejection: .queryMismatch
                ),
                .unavailable
            ),
            (
                "nested-vendor",
                rejectedDecision(
                    id: "a127-nested-vendor",
                    reason: .vendorPolicyNotAccepted,
                    vendorPolicyRejection: .sourceSupportMissing
                ),
                .unavailable
            ),
            (
                "nested-auth",
                rejectedDecision(
                    id: "a127-nested-auth",
                    reason: .authorizationNotAccepted,
                    authorizationRejection: .costClassMismatch
                ),
                .unavailable
            ),
            (
                "nested-lease",
                rejectedDecision(
                    id: "a127-nested-lease",
                    reason: .leaseAuthorizationMismatch,
                    leaseRejection: .dispatchAuthorizationMismatch
                ),
                .unavailable
            ),
        ]
        let source = ServerProviderSearchAPITransportRequestStatusSourceProducer()
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
            XCTAssertTrue(
                presentation.statusLine.contains(try XCTUnwrap(decision.rejection).rawValue),
                id
            )
            if let requestDecisionRejection = decision.requestDecisionRejection {
                XCTAssertTrue(presentation.statusLine.contains(requestDecisionRejection.rawValue), id)
            }
            if let payloadDecisionRejection = decision.payloadDecisionRejection {
                XCTAssertTrue(presentation.statusLine.contains(payloadDecisionRejection.rawValue), id)
            }
            if let dispatchReceiptRejection = decision.dispatchReceiptRejection {
                XCTAssertTrue(presentation.statusLine.contains(dispatchReceiptRejection.rawValue), id)
            }
            if let vendorPolicyRejection = decision.vendorPolicyRejection {
                XCTAssertTrue(presentation.statusLine.contains(vendorPolicyRejection.rawValue), id)
            }
            if let authorizationRejection = decision.authorizationRejection {
                XCTAssertTrue(presentation.statusLine.contains(authorizationRejection.rawValue), id)
            }
            if let leaseRejection = decision.leaseRejection {
                XCTAssertTrue(presentation.statusLine.contains(leaseRejection.rawValue), id)
            }
            XCTAssertTrue(
                presentation.statusLine.contains("No transport or provider runtime has run"),
                id
            )
        }
    }

    func test_encodedDebugAndStatusCopiesDoNotLeakRuntimeOrSensitiveFragments() throws {
        let prepared = preparedDecision(
            traceID: "a127-safe",
            vendorID: "a127-safe-vendor",
            costClass: .meteredPremium,
            freshness: .liveRequired,
            resultShape: .localBusiness,
            resultLimit: 6
        )
        let source = ServerProviderSearchAPITransportRequestStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", decision: prepared),
                ],
                renderedRecommendationIDs: ["rec-safe"]
            )
        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-safe")
        )
        let encoded = try String(
            decoding: JSONEncoder().encode(prepared),
            as: UTF8.self
        )
        let debugCopy = [
            String(describing: prepared),
            String(describing: try XCTUnwrap(prepared.request)),
            String(describing: presentation),
            presentation.statusLine,
            presentation.badges.map(\.label).joined(separator: " "),
        ]
            .joined(separator: " ")
        let combined = encoded + " " + debugCopy

        for forbidden in forbiddenFragments {
            XCTAssertFalse(
                combined.localizedCaseInsensitiveContains(forbidden),
                "Leaked forbidden fragment: \(forbidden)"
            )
        }
        XCTAssertTrue(combined.contains("a127-safe-vendor"))
        XCTAssertTrue(combined.contains("a127-safe-lease"))
        XCTAssertTrue(combined.contains("a127-safe-budget"))
        XCTAssertTrue(combined.contains("a127-safe-metered"))
    }

    private func preparedDecision(
        traceID: String,
        vendorID: String,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        resultShape: ServerProviderSearchAPIVendorResultShape,
        resultLimit: Int
    ) -> ServerProviderSearchAPITransportRequestDecision {
        let request = ServerProviderSearchAPITransportRequest(
            id: "\(traceID)-transport-request",
            requestID: "\(traceID)-adapter-request",
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
            resultLimit: resultLimit,
            sourceCitationSummary: ServerProviderSearchAPITransportSourceCitationSummary(
                sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                    sourcePolicy: ServerSourcePolicy(
                        sourceState: .passed,
                        robotsState: .notApplicable,
                        attributionRequired: true,
                        sourceHost: "\(traceID).example.com"
                    ),
                    citationRequired: true
                )
            )
        )

        return ServerProviderSearchAPITransportRequestDecision(
            id: "\(traceID)-transport-request-decision",
            state: .requestPrepared,
            statusLine: request.statusLine,
            request: request,
            rejection: nil,
            requestDecisionRejection: nil,
            payloadDecisionRejection: nil,
            dispatchReceiptRejection: nil,
            vendorPolicyRejection: nil,
            authorizationRejection: nil,
            leaseRejection: nil
        )
    }

    private func rejectedDecision(
        id: String,
        reason: ServerProviderSearchAPITransportRequestRejectionReason,
        requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason? = nil,
        payloadDecisionRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason? = nil,
        dispatchReceiptRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason? = nil,
        vendorPolicyRejection: ServerProviderSearchAPIVendorPolicyRejectionReason? = nil,
        authorizationRejection: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason? = nil,
        leaseRejection: ServerProviderSearchAPITransportLeaseRejectionReason? = nil
    ) -> ServerProviderSearchAPITransportRequestDecision {
        ServerProviderSearchAPITransportRequestDecision(
            id: id,
            state: .rejected,
            statusLine: "Search API transport request is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            request: nil,
            rejection: reason,
            requestDecisionRejection: requestDecisionRejection,
            payloadDecisionRejection: payloadDecisionRejection,
            dispatchReceiptRejection: dispatchReceiptRejection,
            vendorPolicyRejection: vendorPolicyRejection,
            authorizationRejection: authorizationRejection,
            leaseRejection: leaseRejection
        )
    }

    private func badge(
        _ kind: ProviderStatusBadgeKind,
        in presentation: ProviderStatusPresentation
    ) -> ProviderStatusBadgeModel? {
        presentation.badges.first { $0.kind == kind }
    }

    private var forbiddenFragments: [String] {
        [
            "public coffee",
            "a127-safe.example.com",
            "https" + "://",
            "http" + "://",
            "end" + "point",
            "end" + "pointURL",
            "api" + "Key",
            "api_" + "key",
            "oa" + "uth",
            "bear" + "er",
            "cred" + "ential",
            "url" + "session",
            "s" + "dk",
            "client handle",
            "raw" + " query",
            "raw" + " page",
            "page body",
            "provider payload",
            "crawler",
            "mcp",
            "google" + "maps",
            "a" + "map",
            "pay" + "ment",
            "order",
            "booking",
            "execut" + "ed",
            "fetch" + "ed",
            "provider called",
            "transport sent",
        ]
    }
}
