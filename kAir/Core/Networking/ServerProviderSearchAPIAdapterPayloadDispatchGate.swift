//
//  ServerProviderSearchAPIAdapterPayloadDispatchGate.swift
//  kAir
//
//  Value-only dispatch eligibility gate for Search API adapter payloads. This
//  file verifies metadata alignment before any future transport is allowed to
//  exist; it never sends provider work.
//

import Foundation

enum ServerProviderSearchAPIAdapterPayloadDispatchState: String, Codable, Hashable, Sendable, CaseIterable {
    case dispatchEligible
    case blocked
}

enum ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case payloadDecisionRejected
    case missingPayload
    case requestIDMismatch
    case traceIDMismatch
    case providerFamilyMismatch
    case capabilityMismatch
    case freshnessMismatch
    case costClassMismatch
    case resultLimitMismatch
    case queryMismatch
    case sourcePolicyMismatch
    case emptyQuery
    case providerFamilyNotSearchAPI
    case unsupportedCapability
    case privacyBlocked
    case quotaBlocked
    case invalidResultLimit
    case sourcePolicyInsufficient
    case citationPolicyMissing
}

struct ServerProviderSearchAPIAdapterPayloadDispatchReceipt:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIAdapterPayloadDispatchState
    let statusLine: String
    let payloadDecisionID: String
    let payloadID: String?
    let requestID: String
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let freshness: ProviderFreshness?
    let costClass: ProviderCostClass?
    let resultLimit: Int?
    let sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot?
    let rejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?
    let payloadDecisionRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason?
    let requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason?

    var isDispatchEligible: Bool {
        state == .dispatchEligible
            && payloadID != nil
            && traceID != nil
            && providerFamily == .searchAPI
            && capability != nil
            && freshness != nil
            && costClass != nil
            && resultLimit != nil
            && sourcePolicy != nil
    }

    var description: String {
        "ServerProviderSearchAPIAdapterPayloadDispatchReceipt(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPIAdapterPayloadDispatchGate {
    static func evaluate(
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        request: ServerProviderSearchAPIAdapterRequest
    ) -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        guard payloadDecision.state == .payloadPrepared else {
            return blocked(
                payloadDecision: payloadDecision,
                request: request,
                reason: .payloadDecisionRejected
            )
        }
        guard let payload = payloadDecision.payload else {
            return blocked(
                payloadDecision: payloadDecision,
                request: request,
                reason: .missingPayload
            )
        }
        guard payloadDecision.requestID == request.id,
              payload.requestID == request.id else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .requestIDMismatch)
        }
        guard payload.traceID == request.traceID else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .traceIDMismatch)
        }
        guard payload.providerFamily == request.providerFamily else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .providerFamilyMismatch)
        }
        guard payload.capability == request.capability else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .capabilityMismatch)
        }
        guard payload.freshness == request.freshness else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .freshnessMismatch)
        }
        guard payload.costClass == request.costClass else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .costClassMismatch)
        }
        guard payload.resultLimit == request.resultLimit else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .resultLimitMismatch)
        }
        guard payload.query == ServerProviderSearchAPIAdapterPayloadQuery(requestQuery: request.query) else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .queryMismatch)
        }
        guard payload.sourcePolicy == request.sourcePolicy else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .sourcePolicyMismatch)
        }

        guard request.query.isValid else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .emptyQuery)
        }
        guard request.providerFamily == .searchAPI else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .providerFamilyNotSearchAPI)
        }
        guard request.capability == .webSearch || request.capability == .localServiceSearch else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .unsupportedCapability)
        }
        guard request.privacyClass == .general else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .privacyBlocked)
        }
        guard request.quotaSummary.isAllowed else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .quotaBlocked)
        }
        guard (1...ServerProviderSearchAPIAdapterContract.maximumResultLimit).contains(request.resultLimit) else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .invalidResultLimit)
        }
        guard request.sourcePolicy.hasApprovedSourcePolicy else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .sourcePolicyInsufficient)
        }
        guard request.sourcePolicy.hasCitationPolicy else {
            return blocked(payloadDecision: payloadDecision, request: request, reason: .citationPolicyMissing)
        }

        return ServerProviderSearchAPIAdapterPayloadDispatchReceipt(
            id: "search-api-adapter-payload-dispatch-\(safeID(payload.id))",
            state: .dispatchEligible,
            statusLine: "Search API adapter payload dispatch is eligible from verified metadata only. No transport or provider runtime has run.",
            payloadDecisionID: payloadDecision.id,
            payloadID: payload.id,
            requestID: request.id,
            traceID: payload.traceID,
            providerFamily: payload.providerFamily,
            capability: payload.capability,
            freshness: payload.freshness,
            costClass: payload.costClass,
            resultLimit: payload.resultLimit,
            sourcePolicy: payload.sourcePolicy,
            rejection: nil,
            payloadDecisionRejection: nil,
            requestDecisionRejection: nil
        )
    }

    private static func blocked(
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        request: ServerProviderSearchAPIAdapterRequest,
        reason: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason
    ) -> ServerProviderSearchAPIAdapterPayloadDispatchReceipt {
        ServerProviderSearchAPIAdapterPayloadDispatchReceipt(
            id: "search-api-adapter-payload-dispatch-\(safeID(payloadDecision.id))-\(reason.rawValue)",
            state: .blocked,
            statusLine: "Search API adapter payload dispatch is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            payloadDecisionID: payloadDecision.id,
            payloadID: nil,
            requestID: request.id,
            traceID: nil,
            providerFamily: nil,
            capability: nil,
            freshness: nil,
            costClass: nil,
            resultLimit: nil,
            sourcePolicy: nil,
            rejection: reason,
            payloadDecisionRejection: payloadDecision.rejection,
            requestDecisionRejection: payloadDecision.requestDecisionRejection
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
        return slug.isEmpty ? "missing-search-api-dispatch-id" : slug
    }
}
