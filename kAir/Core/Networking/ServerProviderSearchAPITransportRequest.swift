//
//  ServerProviderSearchAPITransportRequest.swift
//  kAir
//
//  Value-only Search API transport request contract. This file binds an
//  issued transport lease back to the verified request, payload, dispatch,
//  vendor, authorization, and budget metadata before any future transport can
//  be considered.
//

import Foundation

enum ServerProviderSearchAPITransportRequestState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case requestPrepared
    case rejected
}

enum ServerProviderSearchAPITransportRequestRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case missingLease
    case leaseNotIssued
    case missingBudgetContext
    case budgetContextMismatch
    case missingMeteredDecisionID
    case missingRequestDecision
    case requestDecisionRejected
    case missingRequest
    case missingPayloadDecision
    case payloadNotPrepared
    case missingPayload
    case missingDispatchReceipt
    case dispatchNotEligible
    case missingVendorPolicyDecision
    case vendorPolicyNotAccepted
    case missingAuthorization
    case authorizationNotAccepted
    case requestPayloadMismatch
    case requestDispatchMismatch
    case dispatchAuthorizationMismatch
    case vendorAuthorizationMismatch
    case leasePayloadMismatch
    case leaseDispatchMismatch
    case leaseAuthorizationMismatch
    case providerFamilyMismatch
    case vendorMismatch
    case capabilityMismatch
    case costClassMismatch
    case freshnessMismatch
    case resultShapeMismatch
    case resultLimitMismatch
    case sourcePolicyMismatch
    case citationPolicyMissing
}

struct ServerProviderSearchAPITransportSourceCitationSummary:
    Codable,
    Hashable,
    Sendable
{
    let sourceState: ServerSourcePolicyState
    let robotsState: SearchRobotsState
    let attributionRequired: Bool
    let citationRequired: Bool
    let sourceHostRequired: Bool

    init(
        sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot
    ) {
        self.sourceState = sourcePolicy.sourceState
        self.robotsState = sourcePolicy.robotsState
        self.attributionRequired = sourcePolicy.attributionRequired
        self.citationRequired = sourcePolicy.citationRequired
        self.sourceHostRequired = sourcePolicy.sourceHost?.isEmpty == false
    }
}

struct ServerProviderSearchAPITransportRequest:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let requestID: String
    let payloadDecisionID: String
    let payloadID: String
    let dispatchReceiptID: String
    let vendorDecisionID: String
    let authorizationID: String
    let leaseID: String
    let budgetID: String
    let meteredDecisionID: String
    let providerFamily: ProviderFamily
    let vendorID: String
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let resultShape: ServerProviderSearchAPIVendorResultShape
    let resultLimit: Int
    let sourceCitationSummary: ServerProviderSearchAPITransportSourceCitationSummary

    var statusLine: String {
        "Search API transport request is prepared from lease-bound metadata only. No transport or provider runtime has run."
    }

    var description: String {
        "ServerProviderSearchAPITransportRequest(id: \(id), providerFamily: \(providerFamily.rawValue), vendorID: \(vendorID))"
    }
}

struct ServerProviderSearchAPITransportRequestDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPITransportRequestState
    let statusLine: String
    let request: ServerProviderSearchAPITransportRequest?
    let rejection: ServerProviderSearchAPITransportRequestRejectionReason?
    let requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason?
    let payloadDecisionRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason?
    let dispatchReceiptRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
    let vendorPolicyRejection: ServerProviderSearchAPIVendorPolicyRejectionReason?
    let authorizationRejection: ServerProviderSearchAPIVendorPolicyDispatchAuthorizationRejectionReason?
    let leaseRejection: ServerProviderSearchAPITransportLeaseRejectionReason?

    var isPrepared: Bool {
        state == .requestPrepared && request != nil
    }

    var description: String {
        "ServerProviderSearchAPITransportRequestDecision(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPITransportRequestBuilder {
    static func prepare(
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision?,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision?,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt?,
        vendorDecision: ServerProviderSearchAPIVendorPolicyDecision?,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization?,
        lease: ServerProviderSearchAPITransportLease?,
        budgetContext: ServerProviderSearchAPITransportBudgetContext?
    ) -> ServerProviderSearchAPITransportRequestDecision {
        guard let lease else {
            return rejected(reason: .missingLease)
        }
        guard lease.isIssued else {
            return rejected(reason: .leaseNotIssued, lease: lease)
        }
        guard let budgetContext else {
            return rejected(reason: .missingBudgetContext, lease: lease)
        }
        guard lease.budgetID == budgetContext.id else {
            return rejected(reason: .budgetContextMismatch, lease: lease)
        }
        guard let meteredDecisionID = budgetContext.meteredDecisionID,
              meteredDecisionID.isEmpty == false else {
            return rejected(reason: .missingMeteredDecisionID, lease: lease)
        }
        guard let requestDecision else {
            return rejected(reason: .missingRequestDecision, lease: lease)
        }
        guard requestDecision.state == .requestPrepared else {
            return rejected(
                reason: .requestDecisionRejected,
                requestDecision: requestDecision,
                lease: lease
            )
        }
        guard let adapterRequest = requestDecision.request else {
            return rejected(
                reason: .missingRequest,
                requestDecision: requestDecision,
                lease: lease
            )
        }
        guard let payloadDecision else {
            return rejected(
                reason: .missingPayloadDecision,
                requestDecision: requestDecision,
                lease: lease
            )
        }
        guard payloadDecision.state == .payloadPrepared else {
            return rejected(
                reason: .payloadNotPrepared,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                lease: lease
            )
        }
        guard let payload = payloadDecision.payload else {
            return rejected(
                reason: .missingPayload,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                lease: lease
            )
        }
        guard let dispatchReceipt else {
            return rejected(
                reason: .missingDispatchReceipt,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                lease: lease
            )
        }
        guard dispatchReceipt.isDispatchEligible else {
            return rejected(
                reason: .dispatchNotEligible,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                lease: lease
            )
        }
        guard let vendorDecision else {
            return rejected(
                reason: .missingVendorPolicyDecision,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                lease: lease
            )
        }
        guard vendorDecision.isAccepted else {
            return rejected(
                reason: .vendorPolicyNotAccepted,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision,
                lease: lease
            )
        }
        guard let authorization else {
            return rejected(
                reason: .missingAuthorization,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision,
                lease: lease
            )
        }
        guard authorization.isAuthorized else {
            return rejected(
                reason: .authorizationNotAccepted,
                requestDecision: requestDecision,
                payloadDecision: payloadDecision,
                dispatchReceipt: dispatchReceipt,
                vendorDecision: vendorDecision,
                authorization: authorization,
                lease: lease
            )
        }

        guard payloadDecision.requestID == adapterRequest.id,
              payload.requestID == adapterRequest.id else {
            return rejected(reason: .requestPayloadMismatch, lease: lease)
        }
        guard dispatchReceipt.requestID == adapterRequest.id,
              dispatchReceipt.payloadDecisionID == payloadDecision.id,
              dispatchReceipt.payloadID == payload.id else {
            return rejected(reason: .requestDispatchMismatch, lease: lease)
        }
        guard authorization.dispatchReceiptID == dispatchReceipt.id else {
            return rejected(reason: .dispatchAuthorizationMismatch, lease: lease)
        }
        guard authorization.vendorDecisionID == vendorDecision.id else {
            return rejected(reason: .vendorAuthorizationMismatch, lease: lease)
        }
        guard lease.payloadDecisionID == payloadDecision.id,
              lease.payloadID == payload.id else {
            return rejected(reason: .leasePayloadMismatch, lease: lease)
        }
        guard lease.dispatchReceiptID == dispatchReceipt.id else {
            return rejected(reason: .leaseDispatchMismatch, lease: lease)
        }
        guard lease.authorizationID == authorization.id else {
            return rejected(reason: .leaseAuthorizationMismatch, lease: lease)
        }

        guard let dispatchProviderFamily = dispatchReceipt.providerFamily,
              let vendorProviderFamily = vendorDecision.providerFamily,
              let authorizationProviderFamily = authorization.providerFamily,
              let leaseProviderFamily = lease.providerFamily,
              let budgetProviderFamily = budgetContext.providerFamily,
              adapterRequest.providerFamily == payload.providerFamily,
              adapterRequest.providerFamily == dispatchProviderFamily,
              adapterRequest.providerFamily == vendorProviderFamily,
              adapterRequest.providerFamily == authorizationProviderFamily,
              adapterRequest.providerFamily == leaseProviderFamily,
              adapterRequest.providerFamily == budgetProviderFamily else {
            return rejected(reason: .providerFamilyMismatch, lease: lease)
        }
        guard let authorizationVendorID = authorization.vendorID,
              let leaseVendorID = lease.vendorID,
              let budgetVendorID = budgetContext.vendorID,
              vendorDecision.vendorID == authorizationVendorID,
              vendorDecision.vendorID == leaseVendorID,
              vendorDecision.vendorID == budgetVendorID else {
            return rejected(reason: .vendorMismatch, lease: lease)
        }
        guard let dispatchCapability = dispatchReceipt.capability,
              let vendorCapability = vendorDecision.capability,
              let authorizationCapability = authorization.capability,
              let leaseCapability = lease.capability,
              let budgetCapability = budgetContext.capability,
              adapterRequest.capability == payload.capability,
              adapterRequest.capability == dispatchCapability,
              adapterRequest.capability == vendorCapability,
              adapterRequest.capability == authorizationCapability,
              adapterRequest.capability == leaseCapability,
              adapterRequest.capability == budgetCapability else {
            return rejected(reason: .capabilityMismatch, lease: lease)
        }
        guard let dispatchCostClass = dispatchReceipt.costClass,
              let vendorCostClass = vendorDecision.costClass,
              let authorizationCostClass = authorization.costClass,
              let leaseCostClass = lease.costClass,
              let budgetCostClass = budgetContext.costClass,
              adapterRequest.costClass == payload.costClass,
              adapterRequest.costClass == dispatchCostClass,
              adapterRequest.costClass == vendorCostClass,
              adapterRequest.costClass == authorizationCostClass,
              adapterRequest.costClass == leaseCostClass,
              adapterRequest.costClass == budgetCostClass else {
            return rejected(reason: .costClassMismatch, lease: lease)
        }
        guard let dispatchFreshness = dispatchReceipt.freshness,
              let vendorFreshness = vendorDecision.freshness,
              let authorizationFreshness = authorization.freshness,
              let leaseFreshness = lease.freshness,
              let budgetFreshness = budgetContext.freshness,
              adapterRequest.freshness == payload.freshness,
              adapterRequest.freshness == dispatchFreshness,
              adapterRequest.freshness == vendorFreshness,
              adapterRequest.freshness == authorizationFreshness,
              adapterRequest.freshness == leaseFreshness,
              adapterRequest.freshness == budgetFreshness else {
            return rejected(reason: .freshnessMismatch, lease: lease)
        }
        guard let authorizationResultShape = authorization.resultShape,
              let vendorResultShape = vendorDecision.resultShape,
              let leaseResultShape = lease.resultShape,
              authorizationResultShape == vendorResultShape,
              authorizationResultShape == leaseResultShape else {
            return rejected(reason: .resultShapeMismatch, lease: lease)
        }
        guard let dispatchResultLimit = dispatchReceipt.resultLimit,
              let leaseResultLimit = lease.resultLimit,
              adapterRequest.resultLimit == payload.resultLimit,
              adapterRequest.resultLimit == dispatchResultLimit,
              adapterRequest.resultLimit == leaseResultLimit else {
            return rejected(reason: .resultLimitMismatch, lease: lease)
        }
        guard let dispatchSourcePolicy = dispatchReceipt.sourcePolicy,
              adapterRequest.sourcePolicy.hasApprovedSourcePolicy,
              payload.sourcePolicy.hasApprovedSourcePolicy,
              dispatchSourcePolicy.hasApprovedSourcePolicy,
              lease.sourceState == adapterRequest.sourcePolicy.sourceState,
              adapterRequest.sourcePolicy == payload.sourcePolicy,
              adapterRequest.sourcePolicy == dispatchSourcePolicy else {
            return rejected(reason: .sourcePolicyMismatch, lease: lease)
        }
        guard adapterRequest.sourcePolicy.hasCitationPolicy,
              payload.sourcePolicy.hasCitationPolicy,
              dispatchSourcePolicy.hasCitationPolicy,
              lease.citationRequired == true else {
            return rejected(reason: .citationPolicyMissing, lease: lease)
        }

        let request = ServerProviderSearchAPITransportRequest(
            id: "search-api-transport-request-\(safeID(lease.id))-\(safeID(meteredDecisionID))",
            requestID: adapterRequest.id,
            payloadDecisionID: payloadDecision.id,
            payloadID: payload.id,
            dispatchReceiptID: dispatchReceipt.id,
            vendorDecisionID: vendorDecision.id,
            authorizationID: authorization.id,
            leaseID: lease.id,
            budgetID: budgetContext.id,
            meteredDecisionID: meteredDecisionID,
            providerFamily: adapterRequest.providerFamily,
            vendorID: vendorDecision.vendorID,
            capability: adapterRequest.capability,
            costClass: adapterRequest.costClass,
            freshness: adapterRequest.freshness,
            resultShape: authorizationResultShape,
            resultLimit: adapterRequest.resultLimit,
            sourceCitationSummary: ServerProviderSearchAPITransportSourceCitationSummary(
                sourcePolicy: adapterRequest.sourcePolicy
            )
        )

        return ServerProviderSearchAPITransportRequestDecision(
            id: "search-api-transport-request-decision-\(safeID(request.id))",
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

    private static func rejected(
        reason: ServerProviderSearchAPITransportRequestRejectionReason,
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision? = nil,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision? = nil,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt? = nil,
        vendorDecision: ServerProviderSearchAPIVendorPolicyDecision? = nil,
        authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization? = nil,
        lease: ServerProviderSearchAPITransportLease? = nil
    ) -> ServerProviderSearchAPITransportRequestDecision {
        ServerProviderSearchAPITransportRequestDecision(
            id: "search-api-transport-request-decision-\(safeID(lease?.id ?? "missing-lease"))-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Search API transport request is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            request: nil,
            rejection: reason,
            requestDecisionRejection: requestDecision?.rejection,
            payloadDecisionRejection: payloadDecision?.rejection,
            dispatchReceiptRejection: dispatchReceipt?.rejection,
            vendorPolicyRejection: vendorDecision?.rejection,
            authorizationRejection: authorization?.rejection,
            leaseRejection: lease?.rejection
        )
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
        return slug.isEmpty ? "search-api-transport-request" : slug
    }
}
