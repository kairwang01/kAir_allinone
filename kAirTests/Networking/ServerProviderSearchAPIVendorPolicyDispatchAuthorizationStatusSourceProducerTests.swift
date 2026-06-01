//
//  ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducerTests.swift
//  kAirTests
//
//  A109 Search API vendor dispatch authorization status-source proof tests.
//

import XCTest
@testable import kAir

@MainActor
final class ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducerTests: XCTestCase {

    func test_authorizationsPackageRenderedAuthorizedAndBlockedStatus() throws {
        let authorized = try authorizedDispatchAuthorization(
            traceID: "a109-authorized",
            vendorID: "a109-balanced-vendor"
        )
        let blockedDispatch = try dispatchBlockedAuthorization()
        let blockedVendor = try vendorBlockedAuthorization(vendorID: "a109-private-vendor")
        let hidden = try authorizedDispatchAuthorization(
            traceID: "a109-hidden",
            vendorID: "a109-hidden-vendor"
        )
        let source = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-authorized", authorization: authorized),
                    .init(recommendationID: "rec-blocked-dispatch", authorization: blockedDispatch),
                    .init(recommendationID: "rec-blocked-vendor", authorization: blockedVendor),
                    .init(recommendationID: "rec-hidden", authorization: hidden),
                ],
                renderedRecommendationIDs: [
                    "rec-blocked-vendor",
                    "rec-authorized",
                    "rec-blocked-dispatch",
                    "rec-authorized",
                ]
            )
        let baseline = SearchAPIVendorDispatchAuthorizationProviderStatusStore(
            authorizations: [
                (recommendationID: "rec-authorized", authorization: authorized),
                (recommendationID: "rec-blocked-dispatch", authorization: blockedDispatch),
                (recommendationID: "rec-blocked-vendor", authorization: blockedVendor),
                (recommendationID: "rec-hidden", authorization: hidden),
            ]
        )

        let authorizedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-authorized")
        )
        let dispatchBlockedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-blocked-dispatch")
        )
        let vendorBlockedPresentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-blocked-vendor")
        )

        XCTAssertEqual(
            source.renderedRecommendationIDs,
            ["rec-authorized", "rec-blocked-dispatch", "rec-blocked-vendor"]
        )
        XCTAssertEqual(
            authorizedPresentation,
            baseline.providerStatusPresentation(for: "rec-authorized")
        )
        XCTAssertEqual(
            dispatchBlockedPresentation,
            baseline.providerStatusPresentation(for: "rec-blocked-dispatch")
        )
        XCTAssertEqual(
            vendorBlockedPresentation,
            baseline.providerStatusPresentation(for: "rec-blocked-vendor")
        )
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))

        XCTAssertEqual(authorized.state, .authorized)
        XCTAssertEqual(authorizedPresentation.cardHint, .warning)
        XCTAssertEqual(badge(.remoteProvider, in: authorizedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.meteredPremium, in: authorizedPresentation)?.tone, .neutral)
        XCTAssertEqual(badge(.liveFreshness, in: authorizedPresentation)?.tone, .positive)
        XCTAssertTrue(authorizedPresentation.statusLine.contains("ready from verified metadata only"))
        XCTAssertTrue(authorizedPresentation.statusLine.contains("a109-balanced-vendor"))
        XCTAssertTrue(authorizedPresentation.statusLine.contains("webSearch"))
        XCTAssertTrue(authorizedPresentation.statusLine.contains("meteredPremium"))
        XCTAssertTrue(authorizedPresentation.statusLine.contains("livePreferred"))
        XCTAssertTrue(authorizedPresentation.statusLine.contains("organicLinks"))
        XCTAssertTrue(authorizedPresentation.statusLine.contains("No transport or provider runtime has run"))

        XCTAssertEqual(blockedDispatch.state, .rejected)
        XCTAssertEqual(blockedDispatch.rejection, .dispatchNotEligible)
        XCTAssertEqual(dispatchBlockedPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.unavailable, in: dispatchBlockedPresentation)?.tone, .warning)
        XCTAssertTrue(dispatchBlockedPresentation.statusLine.contains("dispatchNotEligible"))
        XCTAssertTrue(dispatchBlockedPresentation.statusLine.contains("payloadDecisionRejected"))
        XCTAssertTrue(dispatchBlockedPresentation.statusLine.contains("a109-accepted-vendor"))
        XCTAssertTrue(
            dispatchBlockedPresentation.statusLine.contains(
                "No transport or provider runtime has run"
            )
        )

        XCTAssertEqual(blockedVendor.state, .rejected)
        XCTAssertEqual(blockedVendor.rejection, .vendorPolicyNotAccepted)
        XCTAssertEqual(blockedVendor.vendorPolicyRejection, .privacyBlocked)
        XCTAssertEqual(vendorBlockedPresentation.cardHint, .disabled)
        XCTAssertEqual(badge(.privacyBlocked, in: vendorBlockedPresentation)?.tone, .warning)
        XCTAssertTrue(vendorBlockedPresentation.statusLine.contains("vendorPolicyNotAccepted"))
        XCTAssertTrue(vendorBlockedPresentation.statusLine.contains("privacyBlocked"))
        XCTAssertTrue(vendorBlockedPresentation.statusLine.contains("a109-private-vendor"))
        XCTAssertTrue(
            vendorBlockedPresentation.statusLine.contains(
                "No transport or provider runtime has run"
            )
        )
    }

    func test_rejectionMatrixMapsToStableProviderStatusCopy() throws {
        let dispatchReceipt = try eligibleDispatchReceipt(
            traceID: "a109-matrix",
            sourceHost: "a109-matrix.example.com"
        )
        let vendorDecision = acceptedVendorDecision(
            vendorID: "a109-matrix-vendor",
            capability: .webSearch,
            costClass: .meteredPremium,
            freshness: .livePreferred,
            resultShape: .organicLinks
        )
        let blockedDispatch = try blockedDispatchReceipt()
        let rejectedVendor = rejectedVendorDecision(vendorID: "a109-rejected-vendor")

        let cases: [
            (
                String,
                ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason,
                ProviderStatusBadgeKind
            )
        ] = [
            (
                "missing-dispatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: nil,
                    vendorDecision: vendorDecision,
                    requestedResultShape: .organicLinks
                ),
                .missingDispatchReceipt,
                .unavailable
            ),
            (
                "blocked-dispatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: blockedDispatch,
                    vendorDecision: vendorDecision,
                    requestedResultShape: .organicLinks
                ),
                .dispatchNotEligible,
                .unavailable
            ),
            (
                "missing-vendor-policy",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: nil,
                    requestedResultShape: .organicLinks
                ),
                .missingVendorPolicyDecision,
                .unavailable
            ),
            (
                "rejected-vendor-policy",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: rejectedVendor,
                    requestedResultShape: .organicLinks
                ),
                .vendorPolicyNotAccepted,
                .privacyBlocked
            ),
            (
                "provider-mismatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: copy(vendorDecision, providerFamily: .googleMaps),
                    requestedResultShape: .organicLinks
                ),
                .providerFamilyMismatch,
                .termsBlocked
            ),
            (
                "capability-mismatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: copy(vendorDecision, capability: .localServiceSearch),
                    requestedResultShape: .organicLinks
                ),
                .capabilityMismatch,
                .termsBlocked
            ),
            (
                "cost-mismatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: copy(vendorDecision, costClass: .includedQuota),
                    requestedResultShape: .organicLinks
                ),
                .costClassMismatch,
                .costBlocked
            ),
            (
                "freshness-mismatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: copy(vendorDecision, freshness: .cachedOK),
                    requestedResultShape: .organicLinks
                ),
                .freshnessMismatch,
                .staleCache
            ),
            (
                "result-shape-mismatch",
                ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                    dispatchReceipt: dispatchReceipt,
                    vendorDecision: copy(vendorDecision, resultShape: .answerSummary),
                    requestedResultShape: .organicLinks
                ),
                .resultShapeMismatch,
                .termsBlocked
            ),
        ]
        let source = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer()
            .statusSource(
                inputs: cases.map { entry in
                    .init(recommendationID: "rec-\(entry.0)", authorization: entry.1)
                },
                renderedRecommendationIDs: cases.map { entry in "rec-\(entry.0)" }
            )

        for (id, authorization, expectedReason, expectedBadgeKind) in cases {
            let presentation = try XCTUnwrap(
                source.providerStatusPresentation(for: "rec-\(id)"),
                id
            )

            XCTAssertEqual(authorization.state, .rejected, id)
            XCTAssertEqual(authorization.rejection, expectedReason, id)
            XCTAssertEqual(presentation.cardHint, .disabled, id)
            XCTAssertNotNil(badge(expectedBadgeKind, in: presentation), id)
            XCTAssertNil(badge(.remoteProvider, in: presentation), id)
            XCTAssertNil(badge(.meteredPremium, in: presentation), id)
            XCTAssertTrue(presentation.statusLine.contains("blocked by metadata policy"), id)
            XCTAssertTrue(presentation.statusLine.contains(expectedReason.rawValue), id)
            XCTAssertTrue(
                presentation.statusLine.contains("No transport or provider runtime has run"),
                id
            )
        }
    }

    func test_duplicateIDsKeepFirstAndRenderedGuardHidesUnrenderedAuthorizations() throws {
        let first = try authorizedDispatchAuthorization(
            traceID: "a109-first",
            vendorID: "a109-first-vendor",
            costClass: .includedQuota,
            freshness: .cachedOK
        )
        let second = try vendorBlockedAuthorization(vendorID: "a109-second-vendor")
        let hidden = try authorizedDispatchAuthorization(
            traceID: "a109-hidden",
            vendorID: "a109-hidden-vendor"
        )
        let store = SearchAPIVendorDispatchAuthorizationProviderStatusStore(
            authorizations: [
                (recommendationID: "rec-duplicate", authorization: first),
                (recommendationID: "rec-duplicate", authorization: second),
                (recommendationID: "rec-hidden", authorization: hidden),
            ]
        )
        let source = ServerProviderRenderedRuntimeStatusSource(
            source: store,
            renderedRecommendationIDs: ["rec-duplicate"]
        )

        let presentation = try XCTUnwrap(
            source.providerStatusPresentation(for: "rec-duplicate")
        )

        XCTAssertEqual(store.recommendationIDs, ["rec-duplicate", "rec-hidden"])
        XCTAssertEqual(source.renderedRecommendationIDs, ["rec-duplicate"])
        XCTAssertEqual(presentation.cardHint, .normal)
        XCTAssertEqual(badge(.includedQuota, in: presentation)?.tone, .neutral)
        XCTAssertNil(badge(.meteredPremium, in: presentation))
        XCTAssertNil(badge(.liveFreshness, in: presentation))
        XCTAssertTrue(presentation.statusLine.contains("a109-first-vendor"))
        XCTAssertFalse(presentation.statusLine.contains("a109-second-vendor"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-hidden"))
        XCTAssertNil(source.providerStatusPresentation(for: "rec-missing"))
    }

    func test_statusSourceCopyAndAuthorizationDebugTextDoNotLeakSensitiveRuntimeFields() throws {
        let authorized = try authorizedDispatchAuthorization(
            traceID: "a109-safe",
            vendorID: "a109-safe-vendor"
        )
        let blocked = try vendorBlockedAuthorization(vendorID: "a109-blocked-vendor")
        let source = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer()
            .statusSource(
                inputs: [
                    .init(recommendationID: "rec-safe", authorization: authorized),
                    .init(recommendationID: "rec-blocked", authorization: blocked),
                ],
                renderedRecommendationIDs: ["rec-safe", "rec-blocked"]
            )
        let safePresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-safe"))
        let blockedPresentation = try XCTUnwrap(source.providerStatusPresentation(for: "rec-blocked"))
        let text = [
            try encodedString(authorized),
            try encodedString(blocked),
            authorized.description,
            blocked.description,
            safePresentation.statusLine,
            blockedPresentation.statusLine,
        ]
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(text.contains("metadata"))
        XCTAssertTrue(text.contains("no transport or provider runtime has run"))
        XCTAssertFalse(text.contains("public coffee"))
        XCTAssertFalse(text.contains("a109-hidden-vendor"))
        for forbidden in sensitiveRuntimeFragments() + executionClaimFragments() {
            XCTAssertFalse(text.contains(forbidden), "Unexpected status-source wording: \(forbidden)")
        }
    }

    private func authorizedDispatchAuthorization(
        traceID: String,
        vendorID: String,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        let dispatchReceipt = try eligibleDispatchReceipt(
            traceID: traceID,
            sourceHost: "\(traceID).example.com",
            costClass: costClass,
            freshness: freshness
        )
        let vendorDecision = acceptedVendorDecision(
            vendorID: vendorID,
            costClass: costClass,
            freshness: freshness
        )

        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: dispatchReceipt,
            vendorDecision: vendorDecision,
            requestedResultShape: .organicLinks
        )
        XCTAssertEqual(authorization.state, .authorized)
        return authorization
    }

    private func dispatchBlockedAuthorization(
        vendorID: String = "a109-accepted-vendor"
    ) throws -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: try blockedDispatchReceipt(),
            vendorDecision: acceptedVendorDecision(vendorID: vendorID),
            requestedResultShape: .organicLinks
        )
        XCTAssertEqual(authorization.rejection, .dispatchNotEligible)
        return authorization
    }

    private func vendorBlockedAuthorization(
        vendorID: String
    ) throws -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
            dispatchReceipt: try eligibleDispatchReceipt(
                traceID: "a109-vendor-blocked-\(vendorID)",
                sourceHost: "a109-vendor-blocked.example.com"
            ),
            vendorDecision: rejectedVendorDecision(vendorID: vendorID),
            requestedResultShape: .organicLinks
        )
        XCTAssertEqual(authorization.rejection, .vendorPolicyNotAccepted)
        return authorization
    }

    private func eligibleDispatchReceipt(
        traceID: String = "a109-dispatch",
        sourceHost: String = "a109.example.com",
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: traceID,
            sourceHost: sourceHost,
            capability: capability,
            costClass: costClass,
            freshness: freshness
        )
        let payloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(from: request)
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: payloadDecision,
            request: request
        )

        XCTAssertEqual(payloadDecision.state, .payloadPrepared)
        XCTAssertEqual(receipt.state, .dispatchEligible)
        XCTAssertTrue(receipt.isDispatchEligible)
        return receipt
    }

    private func blockedDispatchReceipt() throws -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        let request = try preparedRequest(
            traceID: "a109-blocked-baseline",
            sourceHost: "a109-blocked-baseline.example.com"
        )
        let rejectedPayloadDecision = ServerProviderSearchAPIAdapterPayloadBuilder.build(
            from: ServerProviderSearchAPIAdapterContract.prepareRequest(
                envelope: searchEnvelope(
                    traceID: "a109-blocked-private",
                    privacyClass: .private,
                    sourceHost: "a109-blocked-private.example.com"
                ),
                connectorReceipt: connectorReceipt(traceID: "a109-blocked-private"),
                query: ServerProviderSearchAPIAdapterQuery(text: "public coffee")
            )
        )
        let receipt = ServerProviderSearchAPIAdapterPayloadDispatchGate.evaluate(
            payloadDecision: rejectedPayloadDecision,
            request: request
        )

        XCTAssertEqual(rejectedPayloadDecision.state, .rejected)
        XCTAssertEqual(rejectedPayloadDecision.rejection, .requestDecisionRejected)
        XCTAssertEqual(rejectedPayloadDecision.requestDecisionRejection, .privacyBlocked)
        XCTAssertEqual(receipt.state, .blocked)
        XCTAssertFalse(receipt.isDispatchEligible)
        return receipt
    }

    private func preparedRequest(
        traceID: String,
        sourceHost: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) throws -> ServerProviderSearchAPIAdapterRequest {
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
        return try XCTUnwrap(decision.request)
    }

    private func acceptedVendorDecision(
        vendorID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        resultShape: ServerProviderSearchAPIVendorResultShape = .organicLinks
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: providerFamily,
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
                supportedFreshness: [.cachedOK, .livePreferred, .liveRequired],
                supportedResultShapes: [.organicLinks, .answerSummary, .documentSnippets]
            )
        )
        XCTAssertEqual(decision.state, .accepted)
        return decision
    }

    private func rejectedVendorDecision(
        vendorID: String
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        let decision = ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: .searchAPI,
                capability: .webSearch,
                privacyClass: .private,
                costClass: .meteredPremium,
                freshness: .livePreferred,
                citationRequired: true,
                sourceHostRequired: true,
                pageBodyRequirement: .snippetsOnly,
                allowedRetention: .ephemeralOnly,
                resultShape: .organicLinks,
                quotaSnapshot: quotaSnapshot(for: .meteredPremium)
            ),
            vendor: vendorPolicy(id: vendorID, costClass: .meteredPremium)
        )
        XCTAssertEqual(decision.state, .rejected)
        XCTAssertEqual(decision.rejection, .privacyBlocked)
        return decision
    }

    private func vendorPolicy(
        id: String,
        costClass: ProviderCostClass,
        supportedFreshness: Set<ProviderFreshness> = [.cachedOK, .livePreferred, .liveRequired],
        supportedResultShapes: Set<ServerProviderSearchAPIVendorResultShape> = [
            .organicLinks,
            .answerSummary,
            .documentSnippets,
        ]
    ) -> ServerProviderSearchAPIVendorPolicyDescriptor {
        ServerProviderSearchAPIVendorPolicyDescriptor(
            id: id,
            costClass: costClass,
            supportedFreshness: supportedFreshness,
            citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                supportsCitations: true,
                supportsSourceHost: true,
                supportsAttribution: true
            ),
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
                remainingIncludedQuota: [.searchAPI: 2]
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

    private func searchEnvelope(
        traceID: String,
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        privacyClass: ProviderPrivacyClass = .general,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred,
        sourceHost: String
    ) -> ServerProviderEnvelope {
        ServerProviderEnvelope(
            traceID: traceID,
            capability: capability,
            providerFamily: providerFamily,
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
        providerFamily: ProviderFamily = .searchAPI,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass = .meteredPremium,
        freshness: ProviderFreshness = .livePreferred
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "a109-connector-receipt-\(traceID)",
            state: .receiptPrepared,
            statusLine: "A109 connector receipt fixture is metadata only. No provider runtime has run.",
            planningID: "a109-planning-\(traceID)",
            planningState: .requestPrepared,
            planningRejection: nil,
            connectorProviderFamily: providerFamily,
            requestID: "a109-connector-request-\(traceID)",
            resultID: "a109-connector-result-\(traceID)",
            connectorResultState: .metadataPrepared,
            connectorRejection: nil,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: "provider-runtime-adapter-manifest-searchAPI",
            authorizationID: "a109-authorization-\(traceID)",
            boundaryID: "a109-boundary-\(traceID)",
            traceID: traceID,
            invocationRejection: nil
        )
    }

    private func copy(
        _ decision: ServerProviderSearchAPIVendorPolicyDecision,
        providerFamily: ProviderFamily? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil,
        freshness: ProviderFreshness? = nil,
        resultShape: ServerProviderSearchAPIVendorResultShape? = nil
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        ServerProviderSearchAPIVendorPolicyDecision(
            id: "\(decision.id)-copy",
            state: decision.state,
            vendorID: decision.vendorID,
            providerFamily: providerFamily ?? decision.providerFamily,
            capability: capability ?? decision.capability,
            costClass: costClass ?? decision.costClass,
            freshness: freshness ?? decision.freshness,
            resultShape: resultShape ?? decision.resultShape,
            statusLine: decision.statusLine,
            rejection: decision.rejection
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
            "book" + "ing",
            "provider" + " raw",
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
