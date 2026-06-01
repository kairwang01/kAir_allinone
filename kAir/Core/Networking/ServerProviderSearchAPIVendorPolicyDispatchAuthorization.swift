//
//  ServerProviderSearchAPIVendorPolicyDispatchAuthorization.swift
//  kAir
//
//  Value-only Search API dispatch authorization. This file combines verified
//  dispatch metadata with vendor policy metadata before any future transport
//  call can be considered.
//

import Foundation

enum ServerProviderSearchAPIVendorPolicyDispatchAuthorizationState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case authorized
    case rejected
}

enum ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case missingDispatchReceipt
    case dispatchNotEligible
    case missingVendorPolicyDecision
    case vendorPolicyNotAccepted
    case providerFamilyMismatch
    case capabilityMismatch
    case costClassMismatch
    case freshnessMismatch
    case resultShapeMismatch
}

struct ServerProviderSearchAPIVendorPolicyDispatchAuthorization:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationState
    let statusLine: String
    let dispatchReceiptID: String?
    let dispatchState: ServerProviderSearchAPIAdapterPayloadDispatchState?
    let dispatchRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
    let vendorDecisionID: String?
    let vendorDecisionState: ServerProviderSearchAPIVendorPolicyDecisionState?
    let vendorPolicyRejection: ServerProviderSearchAPIVendorPolicyRejectionReason?
    let vendorID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let resultShape: ServerProviderSearchAPIVendorResultShape?
    let rejection: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason?

    var isAuthorized: Bool {
        state == .authorized
    }

    var description: String {
        "ServerProviderSearchAPIVendorPolicyDispatchAuthorization(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPIVendorPolicyDispatchAuthorizationGate {
    static func authorize(
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        vendorDecision: ServerProviderSearchAPIVendorPolicyDecision?,
        requestedResultShape: ServerProviderSearchAPIVendorResultShape
    ) -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        guard let dispatchReceipt else {
            return rejected(
                reason: .missingDispatchReceipt,
                dispatchReceipt: nil,
                vendorDecision: vendorDecision
            )
        }
        guard dispatchReceipt.isDispatchEligible else {
            return rejected(
                reason: .dispatchNotEligible,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }
        guard let vendorDecision else {
            return rejected(
                reason: .missingVendorPolicyDecision,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: nil
            )
        }
        guard vendorDecision.isAccepted else {
            return rejected(
                reason: .vendorPolicyNotAccepted,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }
        guard dispatchReceipt.providerFamily == vendorDecision.providerFamily else {
            return rejected(
                reason: .providerFamilyMismatch,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }
        guard dispatchReceipt.capability == vendorDecision.capability else {
            return rejected(
                reason: .capabilityMismatch,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }
        guard dispatchReceipt.costClass == vendorDecision.costClass else {
            return rejected(
                reason: .costClassMismatch,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }
        guard dispatchReceipt.freshness == vendorDecision.freshness else {
            return rejected(
                reason: .freshnessMismatch,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }
        guard vendorDecision.resultShape == requestedResultShape else {
            return rejected(
                reason: .resultShapeMismatch,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision
            )
        }

        return ServerProviderSearchAPIVendorPolicyDispatchAuthorization(
            id: "search-api-vendor-dispatch-authorization-\(safeID(dispatchReceipt.id))-\(safeID(vendorDecision.vendorID))",
            state: .authorized,
            statusLine: "Search API vendor dispatch is authorized from verified metadata only. No transport or provider runtime has run.",
            dispatchReceiptID: dispatchReceipt.id,
            dispatchState: dispatchReceipt.state,
            dispatchRejection: nil,
            vendorDecisionID: vendorDecision.id,
            vendorDecisionState: vendorDecision.state,
            vendorPolicyRejection: nil,
            vendorID: vendorDecision.vendorID,
            providerFamily: dispatchReceipt.providerFamily,
            capability: dispatchReceipt.capability,
            costClass: dispatchReceipt.costClass,
            freshness: dispatchReceipt.freshness,
            resultShape: requestedResultShape,
            rejection: nil
        )
    }

    private static func rejected(
        reason: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        vendorDecision: ServerProviderSearchAPIVendorPolicyDecision?
    ) -> ServerProviderSearchAPIVendorPolicyDispatchAuthorization {
        ServerProviderSearchAPIVendorPolicyDispatchAuthorization(
            id: rejectedID(reason: reason, dispatchReceipt: dispatchReceipt, vendorDecision: vendorDecision),
            state: .rejected,
            statusLine: "Search API vendor dispatch is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            dispatchReceiptID: dispatchReceipt?.id,
            dispatchState: dispatchReceipt?.state,
            dispatchRejection: dispatchReceipt?.rejection,
            vendorDecisionID: vendorDecision?.id,
            vendorDecisionState: vendorDecision?.state,
            vendorPolicyRejection: vendorDecision?.rejection,
            vendorID: vendorDecision?.vendorID,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            resultShape: nil,
            rejection: reason
        )
    }

    private static func rejectedID(
        reason: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        vendorDecision: ServerProviderSearchAPIVendorPolicyDecision?
    ) -> String {
        [
            "search-api-vendor-dispatch-authorization",
            dispatchReceipt.map { safeID($0.id) } ?? "missing-dispatch",
            vendorDecision.map { safeID($0.vendorID) } ?? "missing-vendor-policy",
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
        return slug.isEmpty ? "search-api-vendor-dispatch" : slug
    }
}
