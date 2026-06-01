//
//  ServerProviderSearchAPIRoutePolicyCompatibility.swift
//  kAir
//
//  A177 value-only compatibility decision for Search API route policy metadata.
//  It binds cost/membership routing to downstream policy, dispatch,
//  authorization, and lease state before any future runtime can be considered.
//

import Foundation

enum ServerProviderSearchAPIRoutePolicyCompatibilityState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case compatible
    case rejected
}

enum ServerProviderSearchAPIRoutePolicyQuotaPosture:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case includedQuota
    case meteredPremium
}

enum ServerProviderSearchAPIRoutePolicySourceCitationPosture:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case passedCitationRequired
}

enum ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case routingRejected
    case missingSelectedRoute
    case localFallbackRoute
    case meteredEntitlementRejected
    case vendorPolicyRejected
    case payloadDispatchBlocked
    case dispatchAuthorizationRejected
    case leaseRejected
    case providerFamilyMismatch
    case vendorMismatch
    case capabilityMismatch
    case costClassMismatch
    case membershipTierMismatch
    case routeKindCostPostureMismatch
    case quotaPostureMismatch
    case sourceCitationPostureMismatch
    case leaseIDMismatch
    case missingAuditID
    case unsafeStatusSourceMetadata
    case staleOrHiddenSourceMarkers
}

struct ServerProviderSearchAPIRoutePolicyCompatibilityInput:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let renderedRecommendationID: String
    let routingDecision: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy
    let meteredDecision: ServerProviderMeteredUsageDecision
    let vendorPolicyDecision: ServerProviderSearchAPIVendorPolicyDecision
    let payloadDispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    let dispatchAuthorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    let transportLease: ServerProviderSearchAPITransportLease
    let selectedStatusSourceID: String
    let selectedStatusSourceRank: Int
    let isVisible: Bool
    let membershipTier: MembershipTier
    let providerFamily: ProviderFamily
    let vendorID: String
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let routeKind: ServerProviderSearchAPICostMembershipRouteKind
    let quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture
    let sourceCitationPosture: ServerProviderSearchAPIRoutePolicySourceCitationPosture
    let transportLeaseID: String
    let auditTraceID: String
    let hasStaleOrHiddenSourceMarkers: Bool

    init(
        id: String = "search-api-route-policy-compatibility",
        renderedRecommendationID: String,
        routingDecision: ServerProviderSearchAPICostMembershipRoutingDecisionSafeCopy,
        meteredDecision: ServerProviderMeteredUsageDecision,
        vendorPolicyDecision: ServerProviderSearchAPIVendorPolicyDecision,
        payloadDispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt,
        dispatchAuthorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
        transportLease: ServerProviderSearchAPITransportLease,
        selectedStatusSourceID: String,
        selectedStatusSourceRank: Int,
        isVisible: Bool = true,
        membershipTier: MembershipTier,
        providerFamily: ProviderFamily = .searchAPI,
        vendorID: String,
        capability: ProviderCapability = .webSearch,
        costClass: ProviderCostClass,
        routeKind: ServerProviderSearchAPICostMembershipRouteKind,
        quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture,
        sourceCitationPosture: ServerProviderSearchAPIRoutePolicySourceCitationPosture =
            .passedCitationRequired,
        transportLeaseID: String,
        auditTraceID: String,
        hasStaleOrHiddenSourceMarkers: Bool = false
    ) {
        self.id = Self.safeID(id, fallback: "search-api-route-policy-compatibility")
        self.renderedRecommendationID = Self.safeID(
            renderedRecommendationID,
            fallback: "rendered-recommendation"
        )
        self.routingDecision = routingDecision
        self.meteredDecision = meteredDecision
        self.vendorPolicyDecision = vendorPolicyDecision
        self.payloadDispatchReceipt = payloadDispatchReceipt
        self.dispatchAuthorization = dispatchAuthorization
        self.transportLease = transportLease
        self.selectedStatusSourceID = Self.safeID(
            selectedStatusSourceID,
            fallback: "route-policy-status-source"
        )
        self.selectedStatusSourceRank = selectedStatusSourceRank
        self.isVisible = isVisible
        self.membershipTier = membershipTier
        self.providerFamily = providerFamily
        self.vendorID = Self.safeID(vendorID, fallback: "search-api-vendor")
        self.capability = capability
        self.costClass = costClass
        self.routeKind = routeKind
        self.quotaPosture = quotaPosture
        self.sourceCitationPosture = sourceCitationPosture
        self.transportLeaseID = Self.safeID(transportLeaseID, fallback: "transport-lease")
        self.auditTraceID = Self.safeID(auditTraceID, fallback: "")
        self.hasStaleOrHiddenSourceMarkers = hasStaleOrHiddenSourceMarkers
    }

    fileprivate static func safeID(
        _ value: String,
        fallback: String
    ) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? fallback : slug
    }
}

struct ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let inputID: String
    let renderedRecommendationID: String
    let routingDecisionID: String
    let meteredDecisionID: String
    let vendorPolicyDecisionID: String
    let payloadDispatchReceiptID: String
    let dispatchAuthorizationID: String
    let transportLeaseID: String
    let selectedStatusSourceID: String
    let selectedStatusSourceRank: Int
    let membershipTier: MembershipTier
    let providerFamily: ProviderFamily
    let vendorID: String
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let routeKind: ServerProviderSearchAPICostMembershipRouteKind
    let quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture
    let sourceCitationPosture: ServerProviderSearchAPIRoutePolicySourceCitationPosture
    let state: ServerProviderSearchAPIRoutePolicyCompatibilityState
    let rejectionReason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason?
    let isRuntimeCallable: Bool
    let isExecutable: Bool

    nonisolated var description: String {
        [
            "ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy(",
            "id: \(id), ",
            "state: \(state.rawValue), ",
            "route: \(routeKind.rawValue), ",
            "callable: \(isRuntimeCallable), ",
            "executable: \(isExecutable)",
            ")",
        ].joined()
    }
}

struct ServerProviderSearchAPIRoutePolicyCompatibilityDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let inputID: String
    let state: ServerProviderSearchAPIRoutePolicyCompatibilityState
    let statusLine: String
    let rejectionReason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason?
    let safeCopy: ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy

    nonisolated var isCompatible: Bool {
        state == .compatible
    }

    nonisolated var isRuntimeCallable: Bool {
        false
    }

    nonisolated var isExecutable: Bool {
        false
    }

    nonisolated var description: String {
        [
            "ServerProviderSearchAPIRoutePolicyCompatibilityDecision(",
            "id: \(id), ",
            "state: \(state.rawValue), ",
            "reason: \(rejectionReason?.rawValue ?? "none"), ",
            "callable: \(isRuntimeCallable), ",
            "executable: \(isExecutable)",
            ")",
        ].joined()
    }
}

enum ServerProviderSearchAPIRoutePolicyCompatibility {
    static func evaluate(
        input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> ServerProviderSearchAPIRoutePolicyCompatibilityDecision {
        if input.hasStaleOrHiddenSourceMarkers {
            return rejected(input: input, reason: .staleOrHiddenSourceMarkers)
        }
        guard input.isVisible,
              input.selectedStatusSourceRank >= 0,
              input.selectedStatusSourceID.isEmpty == false,
              input.renderedRecommendationID.isEmpty == false else {
            return rejected(input: input, reason: .unsafeStatusSourceMetadata)
        }
        guard input.auditTraceID.isEmpty == false else {
            return rejected(input: input, reason: .missingAuditID)
        }
        guard input.routingDecision.state == .accepted else {
            return rejected(input: input, reason: .routingRejected)
        }
        guard let selectedRouteKind = input.routingDecision.selectedRouteKind else {
            return rejected(input: input, reason: .missingSelectedRoute)
        }
        guard selectedRouteKind != .localFallback else {
            return rejected(input: input, reason: .localFallbackRoute)
        }
        guard selectedRouteKind == input.routeKind,
              routeMatchesCostPosture(input.routeKind, input.costClass, input.quotaPosture) else {
            return rejected(input: input, reason: .routeKindCostPostureMismatch)
        }
        guard input.routingDecision.membershipTier == input.membershipTier,
              input.meteredDecision.audit.membershipTier == input.membershipTier else {
            return rejected(input: input, reason: .membershipTierMismatch)
        }
        guard input.routingDecision.requestedCostClass == input.costClass else {
            return rejected(input: input, reason: .costClassMismatch)
        }
        guard input.meteredDecision.isAccepted else {
            return rejected(input: input, reason: .meteredEntitlementRejected)
        }
        guard input.vendorPolicyDecision.isAccepted else {
            return rejected(input: input, reason: .vendorPolicyRejected)
        }
        guard input.payloadDispatchReceipt.isDispatchEligible else {
            return rejected(input: input, reason: .payloadDispatchBlocked)
        }
        guard input.dispatchAuthorization.isAuthorized else {
            return rejected(input: input, reason: .dispatchAuthorizationRejected)
        }
        guard input.transportLease.isIssued else {
            return rejected(input: input, reason: .leaseRejected)
        }
        guard providerFamiliesMatch(input) else {
            return rejected(input: input, reason: .providerFamilyMismatch)
        }
        guard vendorsMatch(input) else {
            return rejected(input: input, reason: .vendorMismatch)
        }
        guard capabilitiesMatch(input) else {
            return rejected(input: input, reason: .capabilityMismatch)
        }
        guard costClassesMatch(input) else {
            return rejected(input: input, reason: .costClassMismatch)
        }
        guard quotaPostureMatches(input) else {
            return rejected(input: input, reason: .quotaPostureMismatch)
        }
        guard sourceCitationPostureMatches(input) else {
            return rejected(input: input, reason: .sourceCitationPostureMismatch)
        }
        guard leaseIDsMatch(input) else {
            return rejected(input: input, reason: .leaseIDMismatch)
        }

        return decision(input: input, reason: nil)
    }

    private static func routeMatchesCostPosture(
        _ routeKind: ServerProviderSearchAPICostMembershipRouteKind,
        _ costClass: ProviderCostClass,
        _ quotaPosture: ServerProviderSearchAPIRoutePolicyQuotaPosture
    ) -> Bool {
        switch routeKind {
        case .includedQuotaPreferred:
            return costClass == .includedQuota && quotaPosture == .includedQuota
        case .meteredAllowed:
            return costClass == .meteredPremium && quotaPosture == .meteredPremium
        case .localFallback, .regionReview, .costBlocked, .unsupportedRoute:
            return false
        }
    }

    private static func providerFamiliesMatch(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        input.providerFamily == .searchAPI
            && input.meteredDecision.providerFamily == input.providerFamily
            && input.vendorPolicyDecision.providerFamily == input.providerFamily
            && input.payloadDispatchReceipt.providerFamily == input.providerFamily
            && input.dispatchAuthorization.providerFamily == input.providerFamily
            && input.transportLease.providerFamily == input.providerFamily
    }

    private static func vendorsMatch(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        input.meteredDecision.vendorID == input.vendorID
            && input.vendorPolicyDecision.vendorID == input.vendorID
            && input.dispatchAuthorization.vendorID == input.vendorID
            && input.transportLease.vendorID == input.vendorID
    }

    private static func capabilitiesMatch(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        input.meteredDecision.capability == input.capability
            && input.vendorPolicyDecision.capability == input.capability
            && input.payloadDispatchReceipt.capability == input.capability
            && input.dispatchAuthorization.capability == input.capability
            && input.transportLease.capability == input.capability
    }

    private static func costClassesMatch(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        input.meteredDecision.costClass == input.costClass
            && input.vendorPolicyDecision.costClass == input.costClass
            && input.payloadDispatchReceipt.costClass == input.costClass
            && input.dispatchAuthorization.costClass == input.costClass
            && input.transportLease.costClass == input.costClass
    }

    private static func quotaPostureMatches(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        switch input.quotaPosture {
        case .includedQuota:
            return input.costClass == .includedQuota
                && input.routeKind == .includedQuotaPreferred
                && (input.meteredDecision.remainingUnitsAfter ?? 0) > 0
        case .meteredPremium:
            return input.costClass == .meteredPremium
                && input.routeKind == .meteredAllowed
                && input.meteredDecision.denialReason == nil
        }
    }

    private static func sourceCitationPostureMatches(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        switch input.sourceCitationPosture {
        case .passedCitationRequired:
            return input.payloadDispatchReceipt.sourcePolicy?.sourceState == .passed
                && input.payloadDispatchReceipt.sourcePolicy?.citationRequired == true
                && input.transportLease.sourceState == .passed
                && input.transportLease.citationRequired == true
        }
    }

    private static func leaseIDsMatch(
        _ input: ServerProviderSearchAPIRoutePolicyCompatibilityInput
    ) -> Bool {
        input.transportLease.id == input.transportLeaseID
            && input.transportLease.dispatchReceiptID == input.payloadDispatchReceipt.id
            && input.transportLease.authorizationID == input.dispatchAuthorization.id
            && input.transportLease.payloadID == input.payloadDispatchReceipt.payloadID
    }

    private static func rejected(
        input: ServerProviderSearchAPIRoutePolicyCompatibilityInput,
        reason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason
    ) -> ServerProviderSearchAPIRoutePolicyCompatibilityDecision {
        decision(input: input, reason: reason)
    }

    private static func decision(
        input: ServerProviderSearchAPIRoutePolicyCompatibilityInput,
        reason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason?
    ) -> ServerProviderSearchAPIRoutePolicyCompatibilityDecision {
        let state: ServerProviderSearchAPIRoutePolicyCompatibilityState =
            reason == nil ? .compatible : .rejected
        let decisionID = [
            input.id,
            state.rawValue,
            reason?.rawValue,
        ]
        .compactMap { $0 }
        .joined(separator: "-")
        let safeCopy = ServerProviderSearchAPIRoutePolicyCompatibilitySafeCopy(
            id: "\(decisionID)-safe-copy",
            inputID: input.id,
            renderedRecommendationID: input.renderedRecommendationID,
            routingDecisionID: input.routingDecision.id,
            meteredDecisionID: input.meteredDecision.id,
            vendorPolicyDecisionID: input.vendorPolicyDecision.id,
            payloadDispatchReceiptID: input.payloadDispatchReceipt.id,
            dispatchAuthorizationID: input.dispatchAuthorization.id,
            transportLeaseID: input.transportLease.id,
            selectedStatusSourceID: input.selectedStatusSourceID,
            selectedStatusSourceRank: input.selectedStatusSourceRank,
            membershipTier: input.membershipTier,
            providerFamily: input.providerFamily,
            vendorID: input.vendorID,
            capability: input.capability,
            costClass: input.costClass,
            routeKind: input.routeKind,
            quotaPosture: input.quotaPosture,
            sourceCitationPosture: input.sourceCitationPosture,
            state: state,
            rejectionReason: reason,
            isRuntimeCallable: false,
            isExecutable: false
        )
        return ServerProviderSearchAPIRoutePolicyCompatibilityDecision(
            id: decisionID,
            inputID: input.id,
            state: state,
            statusLine: statusLine(input: input, state: state, reason: reason),
            rejectionReason: reason,
            safeCopy: safeCopy
        )
    }

    private static func statusLine(
        input: ServerProviderSearchAPIRoutePolicyCompatibilityInput,
        state: ServerProviderSearchAPIRoutePolicyCompatibilityState,
        reason: ServerProviderSearchAPIRoutePolicyCompatibilityRejectionReason?
    ) -> String {
        let base = [
            "Search API route policy compatibility is \(state.rawValue) from value-only metadata.",
            "Route: \(input.routeKind.rawValue).",
            "Vendor: \(input.vendorID).",
            "Cost: \(input.costClass.rawValue).",
            "Runtime callable false.",
            "Executable false.",
            "No transport has run.",
        ]
        if let reason {
            return (base + ["Reason: \(reason.rawValue)."]).joined(separator: " ")
        }
        return base.joined(separator: " ")
    }
}
