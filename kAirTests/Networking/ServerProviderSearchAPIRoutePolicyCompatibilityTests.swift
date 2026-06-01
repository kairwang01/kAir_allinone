//
//  ServerProviderSearchAPIRoutePolicyCompatibilityTests.swift
//  kAirTests
//
//  A177 Search API route-policy compatibility contract tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIRoutePolicyCompatibilityTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_compatibleIncludedQuotaMetadataIsValueOnlyAndNonExecutable() throws {
        let input = try compatibleInput(
            id: "a177-included",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota,
            membershipTier: .plus,
            vendorID: "a177-included-vendor"
        )
        let decision = ServerProviderSearchAPIRoutePolicyCompatibility.evaluate(input: input)
        let repeated = ServerProviderSearchAPIRoutePolicyCompatibility.evaluate(input: input)

        XCTAssertEqual(decision, repeated)
        XCTAssertEqual(decision.state, .compatible)
        XCTAssertTrue(decision.isCompatible)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
        XCTAssertNil(decision.rejectionReason)
        XCTAssertEqual(decision.safeCopy.state, .compatible)
        XCTAssertNil(decision.safeCopy.rejectionReason)
        XCTAssertEqual(decision.safeCopy.routeKind, .includedQuotaPreferred)
        XCTAssertEqual(decision.safeCopy.quotaPosture, .includedQuota)
        XCTAssertEqual(decision.safeCopy.costClass, .includedQuota)
        XCTAssertEqual(decision.safeCopy.membershipTier, .plus)
        XCTAssertEqual(decision.safeCopy.vendorID, "a177-included-vendor")
        XCTAssertEqual(decision.safeCopy.transportLeaseID, input.transportLease.id)
        XCTAssertEqual(decision.safeCopy.dispatchAuthorizationID, input.dispatchAuthorization.id)
        XCTAssertEqual(decision.safeCopy.payloadDispatchReceiptID, input.payloadDispatchReceipt.id)
        XCTAssertFalse(decision.safeCopy.isRuntimeCallable)
        XCTAssertFalse(decision.safeCopy.isExecutable)
        XCTAssertTrue(decision.statusLine.contains("value-only metadata"))
        XCTAssertTrue(decision.statusLine.contains("Runtime callable false"))
        XCTAssertTrue(decision.statusLine.contains("Executable false"))
    }

    func test_compatibleMeteredMetadataRequiresMeteredEntitlementAndLeaseAgreement() throws {
        let input = try compatibleInput(
            id: "a177-metered",
            costClass: .meteredPremium,
            routeKind: .meteredAllowed,
            quotaPosture: .meteredPremium,
            membershipTier: .pro,
            vendorID: "a177-metered-vendor"
        )

        let decision = ServerProviderSearchAPIRoutePolicyCompatibility.evaluate(input: input)

        XCTAssertEqual(decision.state, .compatible)
        XCTAssertEqual(decision.safeCopy.routeKind, .meteredAllowed)
        XCTAssertEqual(decision.safeCopy.quotaPosture, .meteredPremium)
        XCTAssertEqual(decision.safeCopy.costClass, .meteredPremium)
        XCTAssertEqual(decision.safeCopy.membershipTier, .pro)
        XCTAssertEqual(input.meteredDecision.costClass, .meteredPremium)
        XCTAssertEqual(input.transportLease.costClass, .meteredPremium)
        XCTAssertNil(input.meteredDecision.denialReason)
        XCTAssertNil(input.transportLease.rejection)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
    }

    func test_rejectionMatrixBlocksRoutingAndDownstreamPolicyFailures() throws {
        let base = try compatibleInput(
            id: "a177-rejection-base",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota,
            membershipTier: .plus,
            vendorID: "a177-rejection-vendor"
        )
        let blockedDispatch = dispatchReceipt(
            traceID: "a177-rejection-dispatch-blocked",
            costClass: .includedQuota,
            state: .blocked,
            rejection: .privacyBlocked
        )
        let rejectedAuthorization = authorization(
            id: "a177-rejection-authorization",
            dispatchReceipt: base.payloadDispatchReceipt,
            vendorDecision: base.vendorPolicyDecision,
            state: .rejected,
            rejection: .costClassMismatch
        )
        let rejectedLease = lease(
            id: "a177-rejection-lease",
            vendorID: "a177-rejection-vendor",
            costClass: .includedQuota,
            dispatchReceipt: base.payloadDispatchReceipt,
            authorization: base.dispatchAuthorization,
            state: .rejected,
            rejection: .explicitBudgetDenied
        )
        let cases: [
            (
                String,
                ServerProviderSearchAPIRoutePolicyCompatibilityInput,
                ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason
            )
        ] = [
            (
                "routing rejected privacy",
                try copy(
                    base,
                    routingDecision: routingDecision(
                        id: "a177-routing-privacy",
                        costClass: .includedQuota,
                        membershipTier: .plus,
                        privacyClass: .private
                    ).safeCopy
                ),
                .routingRejected
            ),
            (
                "local route",
                try copy(
                    base,
                    routingDecision: routingDecision(
                        id: "a177-routing-local",
                        costClass: .freeLocal,
                        membershipTier: .free
                    ).safeCopy,
                    costClass: .freeLocal,
                    routeKind: .localFallback
                ),
                .localFallbackRoute
            ),
            (
                "metered rejected",
                try copy(
                    base,
                    meteredDecision: meteredDecision(
                        id: "a177-metered-overquota",
                        vendorID: "a177-rejection-vendor",
                        costClass: .includedQuota,
                        membershipTier: .plus,
                        estimatedUnits: 6,
                        remainingUnits: 5
                    )
                ),
                .meteredEntitlementRejected
            ),
            (
                "vendor rejected",
                try copy(
                    base,
                    vendorPolicyDecision: vendorPolicyDecision(
                        vendorID: "a177-rejection-vendor",
                        costClass: .includedQuota,
                        membershipTier: .plus,
                        isAccepted: false
                    )
                ),
                .vendorPolicyRejected
            ),
            (
                "dispatch blocked",
                try copy(base, payloadDispatchReceipt: blockedDispatch),
                .payloadDispatchBlocked
            ),
            (
                "authorization rejected",
                try copy(base, dispatchAuthorization: rejectedAuthorization),
                .dispatchAuthorizationRejected
            ),
            (
                "lease rejected",
                try copy(
                    base,
                    transportLease: rejectedLease,
                    transportLeaseID: rejectedLease.id
                ),
                .leaseRejected
            ),
        ]

        for (name, input, reason) in cases {
            let decision = ServerProviderSearchAPIRoutePolicyCompatibility.evaluate(input: input)

            XCTAssertEqual(decision.state, .rejected, name)
            XCTAssertFalse(decision.isCompatible, name)
            XCTAssertEqual(decision.rejectionReason, reason, name)
            XCTAssertEqual(decision.safeCopy.rejectionReason, reason, name)
            XCTAssertFalse(decision.isRuntimeCallable, name)
            XCTAssertFalse(decision.isExecutable, name)
            XCTAssertTrue(decision.statusLine.contains(reason.rawValue), name)
        }
    }

    func test_mismatchesRejectWithDeterministicReasons() throws {
        let base = try compatibleInput(
            id: "a177-mismatch-base",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota,
            membershipTier: .plus,
            vendorID: "a177-mismatch-vendor"
        )
        let costMismatchVendor = vendorPolicyDecision(
            vendorID: "a177-mismatch-vendor",
            costClass: .meteredPremium,
            membershipTier: .plus
        )
        let sourceMismatchDispatch = dispatchReceipt(
            traceID: "a177-source-mismatch",
            costClass: .includedQuota,
            citationRequired: false
        )

        let cases: [
            (
                String,
                ServerProviderSearchAPIRoutePolicyCompatibilityInput,
                ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason
            )
        ] = [
            (
                "provider",
                try copy(base, providerFamily: .googleMaps),
                .providerFamilyMismatch
            ),
            (
                "vendor",
                try copy(base, vendorID: "a177-other-vendor"),
                .vendorMismatch
            ),
            (
                "capability",
                try copy(base, capability: .localServiceSearch),
                .capabilityMismatch
            ),
            (
                "cost",
                try copy(base, vendorPolicyDecision: costMismatchVendor),
                .costClassMismatch
            ),
            (
                "membership",
                try copy(base, membershipTier: .pro),
                .membershipTierMismatch
            ),
            (
                "route cost posture",
                try copy(base, routeKind: .meteredAllowed),
                .routeKindCostPostureMismatch
            ),
            (
                "source citation",
                try copy(base, payloadDispatchReceipt: sourceMismatchDispatch),
                .sourceCitationPostureMismatch
            ),
            (
                "lease id",
                try copy(base, transportLeaseID: "a177-wrong-lease"),
                .leaseIDMismatch
            ),
            (
                "missing audit",
                try copy(base, auditTraceID: ""),
                .missingAuditID
            ),
            (
                "hidden source markers",
                try copy(base, hasStaleOrHiddenSourceMarkers: true),
                .staleOrHiddenSourceMarkers
            ),
            (
                "hidden source visibility",
                try copy(base, isVisible: false),
                .unsafeStatusSourceMetadata
            ),
        ]

        for (name, input, reason) in cases {
            let decision = ServerProviderSearchAPIRoutePolicyCompatibility.evaluate(input: input)

            XCTAssertEqual(decision.state, .rejected, name)
            XCTAssertEqual(decision.rejectionReason, reason, name)
            XCTAssertEqual(decision.safeCopy.rejectionReason, reason, name)
            XCTAssertFalse(decision.isRuntimeCallable, name)
            XCTAssertFalse(decision.isExecutable, name)
        }
    }

    func test_encodedDebugAndStatusSafeCopyDoNotLeakRuntimeMaterial() throws {
        let input = try compatibleInput(
            id: "a177-safe-copy",
            costClass: .includedQuota,
            routeKind: .includedQuotaPreferred,
            quotaPosture: .includedQuota,
            membershipTier: .plus,
            vendorID: "a177-safe-vendor"
        )
        let decision = ServerProviderSearchAPIRoutePolicyCompatibility.evaluate(input: input)
        let encodedInput = try XCTUnwrap(
            String(data: JSONEncoder().encode(input), encoding: .utf8)
        )
        let encodedDecision = try XCTUnwrap(
            String(data: JSONEncoder().encode(decision), encoding: .utf8)
        )
        let encodedSafeCopy = try XCTUnwrap(
            String(data: JSONEncoder().encode(decision.safeCopy), encoding: .utf8)
        )
        let joined = [
            encodedInput,
            encodedDecision,
            encodedSafeCopy,
            decision.description,
            decision.safeCopy.description,
            decision.statusLine,
        ]
        .joined(separator: "\n")
        .lowercased()

        XCTAssertTrue(joined.contains("isruntimecallable"))
        XCTAssertTrue(joined.contains("isexecutable"))
        for fragment in forbiddenRoutePolicyFragments() {
            XCTAssertFalse(
                joined.contains(fragment),
                "Route-policy compatibility leaked runtime fragment: \(fragment)"
            )
        }
    }

    private func compatibleInput(
        id: String,
        costClass: ProviderCostClass,
        routeKind: ServerProviderSearchAPICostMembershipRouteKind,
        quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture,
        membershipTier: MembershipTier,
        vendorID: String
    ) throws -> ServerProviderSearchAPIRoutePolicyCompatibilityInput {
        let routeDecision = routingDecision(
            id: "\(id)-routing",
            costClass: costClass,
            membershipTier: membershipTier
        )
        let metered = meteredDecision(
            id: "\(id)-metered",
            vendorID: vendorID,
            costClass: costClass,
            membershipTier: membershipTier
        )
        let vendor = vendorPolicyDecision(
            vendorID: vendorID,
            costClass: costClass,
            membershipTier: membershipTier
        )
        let dispatch = dispatchReceipt(traceID: "\(id)-dispatch", costClass: costClass)
        let auth = authorization(
            id: "\(id)-authorization",
            dispatchReceipt: dispatch,
            vendorDecision: vendor
        )
        let issuedLease = lease(
            id: "\(id)-lease",
            vendorID: vendorID,
            costClass: costClass,
            dispatchReceipt: dispatch,
            authorization: auth
        )

        XCTAssertEqual(routeDecision.selectedRouteKind, routeKind)
        XCTAssertTrue(metered.isAccepted)
        XCTAssertTrue(vendor.isAccepted)
        XCTAssertTrue(dispatch.isDispatchEligible)
        XCTAssertTrue(auth.isAuthorized)
        XCTAssertTrue(issuedLease.isIssued)

        return ServerProviderSearchAPIRoutePolicyCompatibilityInput(
            id: id,
            renderedRecommendationID: "\(id)-rendered",
            routingDecision: routeDecision.safeCopy,
            meteredDecision: metered,
            vendorPolicyDecision: vendor,
            payloadDispatchReceipt: dispatch,
            dispatchAuthorization: auth,
            transportLease: issuedLease,
            selectedStatusSourceID: "\(id)-status-source",
            selectedStatusSourceRank: 1,
            membershipTier: membershipTier,
            vendorID: vendorID,
            costClass: costClass,
            routeKind: routeKind,
            quotaPosture: quotaPosture,
            transportLeaseID: issuedLease.id,
            auditTraceID: "\(id)-audit"
        )
    }

    private func copy(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput,
        routingDecision: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy? = nil,
        meteredDecision: ServerProviderMeteredUsageDecision? = nil,
        vendorPolicyDecision: ServerProviderSearchAPIVendorPolicyDecision? = nil,
        payloadDispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt? = nil,
        dispatchAuthorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization? = nil,
        transportLease: ServerProviderSearchAPITransportLease? = nil,
        selectedStatusSourceID: String? = nil,
        selectedStatusSourceRank: Int? = nil,
        isVisible: Bool? = nil,
        membershipTier: MembershipTier? = nil,
        providerFamily: ProviderFamily? = nil,
        vendorID: String? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil,
        routeKind: ServerProviderSearchAPICostMembershipRouteKind? = nil,
        quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture? = nil,
        sourceCitationPosture: ServerProviderSearchAPIRoutePolicySourceCitationPosture? = nil,
        transportLeaseID: String? = nil,
        auditTraceID: String? = nil,
        hasStaleOrHiddenSourceMarkers: Bool? = nil
    ) throws -> ServerProviderSearchAPIRoutePolicyCompatibilityInput {
        ServerProviderSearchAPIRoutePolicyCompatibilityInput(
            id: input.id,
            renderedRecommendationID: input.renderedRecommendationID,
            routingDecision: routingDecision ?? input.routingDecision,
            meteredDecision: meteredDecision ?? input.meteredDecision,
            vendorPolicyDecision: vendorPolicyDecision ?? input.vendorPolicyDecision,
            payloadDispatchReceipt: payloadDispatchReceipt ?? input.payloadDispatchReceipt,
            dispatchAuthorization: dispatchAuthorization ?? input.dispatchAuthorization,
            transportLease: transportLease ?? input.transportLease,
            selectedStatusSourceID: selectedStatusSourceID ?? input.selectedStatusSourceID,
            selectedStatusSourceRank: selectedStatusSourceRank ?? input.selectedStatusSourceRank,
            isVisible: isVisible ?? input.isVisible,
            membershipTier: membershipTier ?? input.membershipTier,
            providerFamily: providerFamily ?? input.providerFamily,
            vendorID: vendorID ?? input.vendorID,
            capability: capability ?? input.capability,
            costClass: costClass ?? input.costClass,
            routeKind: routeKind ?? input.routeKind,
            quotaPosture: quotaPosture ?? input.quotaPosture,
            sourceCitationPosture: sourceCitationPosture ?? input.sourceCitationPosture,
            transportLeaseID: transportLeaseID ?? input.transportLeaseID,
            auditTraceID: auditTraceID ?? input.auditTraceID,
            hasStaleOrHiddenSourceMarkers:
                hasStaleOrHiddenSourceMarkers ?? input.hasStaleOrHiddenSourceMarkers
        )
    }

    private func routingDecision(
        id: String,
        costClass: ProviderCostClass,
        membershipTier: MembershipTier,
        privacyClass: ProviderPrivacyClass = .general
    ) -> ServerProviderSearchAPICostMembershipRoutingDecision {
        ServerProviderSearchAPICostMembershipRoutingDecider.decide(
            input: ServerProviderSearchAPICostMembershipRoutingDecisionInput(
                id: id,
                membershipTier: membershipTier,
                requestedCostClass: costClass,
                region: .northAmerica,
                privacyClass: privacyClass,
                quotaSnapshot: quotaSnapshot(for: costClass)
            )
        )
    }

    private func quotaSnapshot(for costClass: ProviderCostClass) -> ServerProviderQuotaSnapshot {
        switch costClass {
        case .includedQuota:
            return ServerProviderQuotaSnapshot(
                allowedProviderFamilies: [.searchAPI],
                entitledProviderFamilies: [.searchAPI],
                remainingIncludedQuota: [.searchAPI: 12]
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

    private func meteredDecision(
        id: String,
        vendorID: String,
        costClass: ProviderCostClass,
        membershipTier: MembershipTier,
        estimatedUnits: Int = 3,
        remainingUnits: Int = 30
    ) -> ServerProviderMeteredUsageDecision {
        ServerProviderMeteredEntitlementLedger.evaluate(
            request: ServerProviderMeteredUsageRequest(
                id: id,
                traceID: "\(id)-trace",
                providerFamily: .searchAPI,
                vendorID: vendorID,
                capability: .webSearch,
                estimatedUnits: estimatedUnits,
                costClass: costClass,
                privacyClass: .general,
                freshness: .livePreferred,
                membershipTier: membershipTier,
                currencyCode: "usd",
                unitLabel: "search-unit",
                userFacingReason: "public lookup"
            ),
            snapshot: ServerProviderMeteredEntitlementSnapshot(
                id: "\(id)-snapshot",
                providerFamily: .searchAPI,
                vendorID: vendorID,
                capability: .webSearch,
                costClass: costClass,
                membershipTier: membershipTier,
                minimumMembershipTier: membershipTier,
                quotaPeriodID: "\(id)-quota",
                includedUnits: 40,
                usedUnits: 4,
                reservedUnits: max(0, estimatedUnits),
                remainingUnits: max(0, remainingUnits),
                currencyCode: "usd",
                unitLabel: "search-unit",
                sourceTimestamp: now,
                staleAfter: 600
            ),
            now: now
        )
    }

    private func vendorPolicyDecision(
        vendorID: String,
        costClass: ProviderCostClass,
        membershipTier: MembershipTier,
        isAccepted: Bool = true
    ) -> ServerProviderSearchAPIVendorPolicyDecision {
        ServerProviderSearchAPIVendorPolicy.evaluate(
            context: ServerProviderSearchAPIVendorPolicyContext(
                providerFamily: .searchAPI,
                capability: .webSearch,
                privacyClass: isAccepted ? .general : .private,
                costClass: costClass,
                freshness: .livePreferred,
                citationRequired: true,
                sourceHostRequired: true,
                quotaSnapshot: quotaSnapshot(for: costClass)
            ),
            vendor: ServerProviderSearchAPIVendorPolicyDescriptor(
                id: vendorID,
                costClass: costClass,
                supportedFreshness: [.cachedOK, .livePreferred, .liveRequired],
                citationSupport: ServerProviderSearchAPIVendorCitationSupport(
                    supportsCitations: true,
                    supportsSourceHost: true,
                    supportsAttribution: true
                ),
                pageBodyMode: .optional,
                requiredRetention: .ephemeralOnly,
                supportedResultShapes: [.organicLinks, .answerSummary]
            )
        )
    }

    private func dispatchReceipt(
        traceID: String,
        costClass: ProviderCostClass,
        state: ServerProviderSearchAPIAdapterPayloadDispatchState = .dispatchEligible,
        rejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason? = nil,
        citationRequired: Bool = true
    ) -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        ServerProviderSearchAPIAdapterPayloadDispatchReceipt(
            id: "\(traceID)-dispatch",
            state: state,
            statusLine: "Search API adapter payload dispatch is metadata only.",
            payloadDecisionID: "\(traceID)-payload-decision",
            payloadID: state == .dispatchEligible ? "\(traceID)-payload" : nil,
            requestID: "\(traceID)-request",
            traceID: state == .dispatchEligible ? traceID : nil,
            providerFamily: state == .dispatchEligible ? .searchAPI : nil,
            capability: state == .dispatchEligible ? .webSearch : nil,
            freshness: state == .dispatchEligible ? .livePreferred : nil,
            costClass: state == .dispatchEligible ? costClass : nil,
            resultLimit: state == .dispatchEligible ? 4 : nil,
            sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot(
                sourcePolicy: ServerSourcePolicy(
                    sourceState: .passed,
                    robotsState: .notApplicable,
                    attributionRequired: true
                ),
                citationRequired: citationRequired
            ),
            rejection: rejection,
            payloadDecisionRejection: nil,
            requestDecisionRejection: nil
        )
    }

    private func authorization(
        id: String,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        vendorDecision: ServerProviderSearchAPIVendorPolicyDecision,
        state: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationState = .authorized,
        rejection: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason? = nil
    ) -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        if state == .authorized {
            let authorization = ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate.authorize(
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision,
                requestedResultShape: .organicLinks
            )
            XCTAssertEqual(authorization.state, .authorized)
            return authorization
        }

        return ServerProviderSearchAPIVendorPolicyDispatchAuthorization(
            id: "\(id)-rejected",
            state: .rejected,
            statusLine: "Search API dispatch authorization is rejected metadata only.",
            dispatchReceiptID: dispatchReceipt.id,
            dispatchState: dispatchReceipt.state,
            dispatchRejection: dispatchReceipt.rejection,
            vendorDecisionID: vendorDecision.id,
            vendorDecisionState: vendorDecision.state,
            vendorPolicyRejection: vendorDecision.rejection,
            vendorID: vendorDecision.vendorID,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            resultShape: nil,
            rejection: rejection
        )
    }

    private func lease(
        id: String,
        vendorID: String,
        costClass: ProviderCostClass,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
        state: ServerProviderSearchAPITransportLeaseState = .issued,
        rejection: ServerProviderSearchAPITransportLeaseRejectionReason? = nil
    ) -> ServerProviderSearchAPITransportLease {
        ServerProviderSearchAPITransportLease(
            id: id,
            state: state,
            statusLine: "Search API transport lease is metadata only.",
            payloadDecisionID: dispatchReceipt.payloadDecisionID,
            payloadID: dispatchReceipt.payloadID,
            dispatchReceiptID: dispatchReceipt.id,
            authorizationID: authorization.id,
            budgetID: "\(id)-budget",
            vendorID: vendorID,
            providerFamily: state == .issued ? .searchAPI : nil,
            capability: state == .issued ? .webSearch : nil,
            costClass: state == .issued ? costClass : nil,
            freshness: state == .issued ? .livePreferred : nil,
            resultShape: state == .issued ? .organicLinks : nil,
            resultLimit: state == .issued ? 4 : nil,
            sourceState: state == .issued ? .passed : nil,
            citationRequired: state == .issued ? true : nil,
            rejection: rejection,
            payloadRejection: nil,
            dispatchRejection: nil,
            authorizationRejection: authorization.rejection
        )
    }

    private func forbiddenRoutePolicyFragments() -> [String] {
        [
            "http://",
            "https://",
            "endpoint",
            "api" + "key",
            "api" + "_" + "key",
            "oa" + "uth",
            "bear" + "er",
            "cred" + "ential",
            "urlsession",
            "urlrequest",
            "sdk/client",
            "raw query",
            "raw page",
            "raw provider",
            "crawler runtime",
            "mcp runtime",
            "maps sdk",
            "store" + "kit",
            "payment",
            "booking",
            "provider call",
            "execution claim",
            "completion claim",
        ]
    }
}
