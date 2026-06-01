//
//  ServerProviderSearchAPITransportLease.swift
//  kAir
//
//  Value-only Search API transport lease gate. This file verifies payload,
//  dispatch, vendor authorization, and cost budget metadata before any future
//  transport can be considered.
//

import Foundation

enum ServerProviderSearchAPITransportLeaseState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case issued
    case rejected
}

enum ServerProviderSearchAPITransportLeaseRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case missingPayloadDecision
    case payloadNotPrepared
    case missingPayload
    case missingDispatchReceipt
    case dispatchNotEligible
    case missingAuthorization
    case authorizationNotAccepted
    case payloadDispatchMismatch
    case dispatchAuthorizationMismatch
    case providerFamilyMismatch
    case vendorMismatch
    case capabilityMismatch
    case costClassMismatch
    case freshnessMismatch
    case resultShapeMismatch
    case providerNotAllowed
    case providerDisabled
    case entitlementMissing
    case meteredEntitlementMissing
    case includedQuotaExhausted
    case meteredEligibilityMissing
    case explicitBudgetDenied
    case sourcePolicyInsufficient
    case citationPolicyMissing
}

struct ServerProviderSearchAPITransportBudgetContext:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let quotaSnapshot: ServerProviderQuotaSnapshot
    let allowedCostClasses: Set<ProviderCostClass>
    let meteredDecisionID: String?
    let providerFamily: ProviderFamily?
    let vendorID: String?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?

    nonisolated init(
        id: String,
        quotaSnapshot: ServerProviderQuotaSnapshot,
        allowedCostClasses: Set<ProviderCostClass>,
        meteredDecisionID: String? = nil,
        providerFamily: ProviderFamily? = nil,
        vendorID: String? = nil,
        capability: ProviderCapability? = nil,
        costClass: ProviderCostClass? = nil,
        freshness: ProviderFreshness? = nil
    ) {
        self.id = id
        self.quotaSnapshot = quotaSnapshot
        self.allowedCostClasses = allowedCostClasses
        self.meteredDecisionID = meteredDecisionID
        self.providerFamily = providerFamily
        self.vendorID = vendorID
        self.capability = capability
        self.costClass = costClass
        self.freshness = freshness
    }
}

struct ServerProviderSearchAPITransportLease:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPITransportLeaseState
    let statusLine: String
    let payloadDecisionID: String?
    let payloadID: String?
    let dispatchReceiptID: String?
    let authorizationID: String?
    let budgetID: String
    let vendorID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let resultShape: ServerProviderSearchAPIVendorResultShape?
    let resultLimit: Int?
    let sourceState: ServerSourcePolicyState?
    let citationRequired: Bool?
    let rejection: ServerProviderSearchAPITransportLeaseRejectionReason?
    let payloadRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason?
    let dispatchRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
    let authorizationRejection: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason?

    var isIssued: Bool {
        state == .issued
    }

    var description: String {
        "ServerProviderSearchAPITransportLease(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPITransportLeaseGate {
    static func evaluate(
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision?,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization?,
        requestedResultShape: ServerProviderSearchAPIVendorResultShape,
        budgetContext: ServerProviderSearchAPITransportBudgetContext
    ) -> ServerProviderSearchAPITransportLease {
        guard let payloadDecision else {
            return rejected(
                reason: .missingPayloadDecision,
                payloadDecision: nil,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payloadDecision.state == .payloadPrepared else {
            return rejected(
                reason: .payloadNotPrepared,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard let payload = payloadDecision.payload else {
            return rejected(
                reason: .missingPayload,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard let dispatchReceipt else {
            return rejected(
                reason: .missingDispatchReceipt,
                payloadDecision: payloadDecision,
                dispatchReceipt: nil,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard dispatchReceipt.isDispatchEligible else {
            return rejected(
                reason: .dispatchNotEligible,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard let authorization else {
            return rejected(
                reason: .missingAuthorization,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: nil,
                budgetContext: budgetContext
            )
        }
        guard authorization.isAuthorized else {
            return rejected(
                reason: .authorizationNotAccepted,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard dispatchReceipt.payloadDecisionID == payloadDecision.id,
              dispatchReceipt.payloadID == payload.id else {
            return rejected(
                reason: .payloadDispatchMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard authorization.dispatchReceiptID == dispatchReceipt.id else {
            return rejected(
                reason: .dispatchAuthorizationMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payload.providerFamily == dispatchReceipt.providerFamily,
              payload.providerFamily == authorization.providerFamily else {
            return rejected(
                reason: .providerFamilyMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payload.capability == dispatchReceipt.capability,
              payload.capability == authorization.capability else {
            return rejected(
                reason: .capabilityMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payload.costClass == dispatchReceipt.costClass,
              payload.costClass == authorization.costClass else {
            return rejected(
                reason: .costClassMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payload.freshness == dispatchReceipt.freshness,
              payload.freshness == authorization.freshness else {
            return rejected(
                reason: .freshnessMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard authorization.resultShape == requestedResultShape else {
            return rejected(
                reason: .resultShapeMismatch,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payload.sourcePolicy.hasApprovedSourcePolicy else {
            return rejected(
                reason: .sourcePolicyInsufficient,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        guard payload.sourcePolicy.hasCitationPolicy else {
            return rejected(
                reason: .citationPolicyMissing,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        if let metadataRejection = budgetMetadataRejection(
            payload: payload,
            authorization: authorization,
            budgetContext: budgetContext
        ) {
            return rejected(
                reason: metadataRejection,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }
        if let budgetRejection = budgetRejection(
            providerFamily: payload.providerFamily,
            costClass: payload.costClass,
            budgetContext: budgetContext
        ) {
            return rejected(
                reason: budgetRejection,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization,
                budgetContext: budgetContext
            )
        }

        return ServerProviderSearchAPITransportLease(
            id: "search-api-transport-lease-\(safeID(payload.id))-\(safeID(authorization.id))",
            state: .issued,
            statusLine: "Search API transport lease is issued from verified metadata only. No transport or provider runtime has run.",
            payloadDecisionID: payloadDecision.id,
            payloadID: payload.id,
            dispatchReceiptID: dispatchReceipt.id,
            authorizationID: authorization.id,
            budgetID: budgetContext.id,
            vendorID: authorization.vendorID,
            providerFamily: payload.providerFamily,
            capability: payload.capability,
            costClass: payload.costClass,
            freshness: payload.freshness,
            resultShape: requestedResultShape,
            resultLimit: payload.resultLimit,
            sourceState: payload.sourcePolicy.sourceState,
            citationRequired: payload.sourcePolicy.citationRequired,
            rejection: nil,
            payloadRejection: nil,
            dispatchRejection: nil,
            authorizationRejection: nil
        )
    }

    private static func budgetMetadataRejection(
        payload: ServerProviderSearchAPIAdapterTransportPayload,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization,
        budgetContext: ServerProviderSearchAPITransportBudgetContext
    ) -> ServerProviderSearchAPITransportLeaseRejectionReason? {
        guard budgetContext.meteredDecisionID != nil,
              let budgetProviderFamily = budgetContext.providerFamily,
              let budgetVendorID = budgetContext.vendorID,
              let budgetCapability = budgetContext.capability,
              let budgetCostClass = budgetContext.costClass,
              let budgetFreshness = budgetContext.freshness else {
            return .meteredEntitlementMissing
        }
        guard budgetProviderFamily == payload.providerFamily else {
            return .providerFamilyMismatch
        }
        guard budgetVendorID == authorization.vendorID else {
            return .vendorMismatch
        }
        guard budgetCapability == payload.capability else {
            return .capabilityMismatch
        }
        guard budgetCostClass == payload.costClass else {
            return .costClassMismatch
        }
        guard budgetFreshness == payload.freshness else {
            return .freshnessMismatch
        }
        return nil
    }

    private static func budgetRejection(
        providerFamily: ProviderFamily,
        costClass: ProviderCostClass,
        budgetContext: ServerProviderSearchAPITransportBudgetContext
    ) -> ServerProviderSearchAPITransportLeaseRejectionReason? {
        let snapshot = budgetContext.quotaSnapshot
        if snapshot.disabledProviderFamilies.contains(providerFamily) {
            return .providerDisabled
        }
        guard snapshot.allowedProviderFamilies.contains(providerFamily) else {
            return .providerNotAllowed
        }
        guard snapshot.entitledProviderFamilies.contains(providerFamily) else {
            return .entitlementMissing
        }
        guard budgetContext.allowedCostClasses.contains(costClass) else {
            return .explicitBudgetDenied
        }

        switch costClass {
        case .includedQuota:
            return snapshot.remainingIncludedQuota[providerFamily, default: 0] > 0
                ? nil
                : .includedQuotaExhausted
        case .meteredPremium:
            return snapshot.meteredEligibleProviderFamilies.contains(providerFamily)
                ? nil
                : .meteredEligibilityMissing
        case .freeLocal, .blockedByCost, .blockedByPrivacy, .blockedByTerms:
            return .explicitBudgetDenied
        }
    }

    private static func rejected(
        reason: ServerProviderSearchAPITransportLeaseRejectionReason,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision?,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization?,
        budgetContext: ServerProviderSearchAPITransportBudgetContext
    ) -> ServerProviderSearchAPITransportLease {
        ServerProviderSearchAPITransportLease(
            id: rejectedID(
                reason: reason,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                authorization: authorization
            ),
            state: .rejected,
            statusLine: "Search API transport lease is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            payloadDecisionID: payloadDecision?.id,
            payloadID: payloadDecision?.payload?.id,
            dispatchReceiptID: dispatchReceipt?.id,
            authorizationID: authorization?.id,
            budgetID: budgetContext.id,
            vendorID: authorization?.vendorID,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            resultShape: nil,
            resultLimit: nil,
            sourceState: nil,
            citationRequired: nil,
            rejection: reason,
            payloadRejection: payloadDecision?.rejection,
            dispatchRejection: dispatchReceipt?.rejection,
            authorizationRejection: authorization?.rejection
        )
    }

    private static func rejectedID(
        reason: ServerProviderSearchAPITransportLeaseRejectionReason,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision?,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization?
    ) -> String {
        [
            "search-api-transport-lease",
            payloadDecision.map { safeID($0.id) } ?? "missing-payload",
            dispatchReceipt.map { safeID($0.id) } ?? "missing-dispatch",
            authorization.map { safeID($0.id) } ?? "missing-authorization",
            reason.rawValue,
        ]
            .joined(separator: "-")
    }

    private static func safeID(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? "search-api-transport-lease" : slug
    }
}
