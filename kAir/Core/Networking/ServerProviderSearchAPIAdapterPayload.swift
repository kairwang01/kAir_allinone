//
//  ServerProviderSearchAPIAdapterPayload.swift
//  kAir
//
//  Value-only Search API adapter transport payload boundary. This file derives
//  outbound-safe metadata from the prepared adapter request without contacting
//  a provider or transport.
//

import Foundation

enum ServerProviderSearchAPIAdapterPayloadState: String, Codable, Hashable, Sendable, CaseIterable {
    case payloadPrepared
    case rejected
}

enum ServerProviderSearchAPIAdapterPayloadRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case requestDecisionRejected
    case missingPreparedRequest
    case emptyQuery
    case providerFamilyNotSearchAPI
    case unsupportedCapability
    case privacyBlocked
    case quotaBlocked
    case sourcePolicyInsufficient
    case citationPolicyMissing
    case invalidResultLimit
}

struct ServerProviderSearchAPIAdapterPayloadQuery: Codable, Hashable, Sendable {
    let text: String
    let localeHint: String?

    init(requestQuery: ServerProviderSearchAPIAdapterQuery) {
        self.text = requestQuery.text
        self.localeHint = requestQuery.localeHint
    }
}

struct ServerProviderSearchAPIAdapterTransportPayload:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let requestID: String
    let traceID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let resultLimit: Int
    let query: ServerProviderSearchAPIAdapterPayloadQuery
    let sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot

    var statusLine: String {
        "Search API adapter payload is prepared from approved request metadata only. No transport or provider runtime has run."
    }

    var description: String {
        "ServerProviderSearchAPIAdapterTransportPayload(id: \(id), requestID: \(requestID), providerFamily: \(providerFamily.rawValue), capability: \(capability.rawValue))"
    }
}

struct ServerProviderSearchAPIAdapterPayloadDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIAdapterPayloadState
    let statusLine: String
    let requestID: String?
    let payload: ServerProviderSearchAPIAdapterTransportPayload?
    let rejection: ServerProviderSearchAPIAdapterPayloadRejectionReason?
    let requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason?

    var description: String {
        "ServerProviderSearchAPIAdapterPayloadDecision(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPIAdapterPayloadBuilder {
    static func build(
        from decision: ServerProviderSearchAPIAdapterRequestDecision
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        guard decision.state == .requestPrepared else {
            return rejected(
                idSeed: decision.id,
                requestID: nil,
                reason: .requestDecisionRejected,
                requestDecisionRejection: decision.rejection,
                statusLine: "Search API adapter payload is blocked because the request decision is not prepared: \(decision.rejection?.rawValue ?? "missingReason"). No transport or provider runtime has run."
            )
        }
        guard let request = decision.request else {
            return rejected(
                idSeed: decision.id,
                requestID: nil,
                reason: .missingPreparedRequest,
                requestDecisionRejection: decision.rejection,
                statusLine: "Search API adapter payload is blocked because the prepared request metadata is missing. No transport or provider runtime has run."
            )
        }
        return build(from: request)
    }

    static func build(
        from request: ServerProviderSearchAPIAdapterRequest
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        guard request.query.isValid else {
            return rejected(request: request, reason: .emptyQuery)
        }
        guard request.providerFamily == .searchAPI else {
            return rejected(request: request, reason: .providerFamilyNotSearchAPI)
        }
        guard request.capability == .webSearch || request.capability == .localServiceSearch else {
            return rejected(request: request, reason: .unsupportedCapability)
        }
        guard request.privacyClass == .general else {
            return rejected(request: request, reason: .privacyBlocked)
        }
        guard request.quotaSummary.isAllowed else {
            return rejected(request: request, reason: .quotaBlocked)
        }
        guard (1...ServerProviderSearchAPIAdapterContract.maximumResultLimit).contains(request.resultLimit) else {
            return rejected(request: request, reason: .invalidResultLimit)
        }
        guard request.sourcePolicy.hasApprovedSourcePolicy else {
            return rejected(request: request, reason: .sourcePolicyInsufficient)
        }
        guard request.sourcePolicy.hasCitationPolicy else {
            return rejected(request: request, reason: .citationPolicyMissing)
        }

        let payload = ServerProviderSearchAPIAdapterTransportPayload(
            id: "search-api-adapter-payload-\(safeID(request.id))",
            requestID: request.id,
            traceID: request.traceID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            costClass: request.costClass,
            freshness: request.freshness,
            resultLimit: request.resultLimit,
            query: ServerProviderSearchAPIAdapterPayloadQuery(requestQuery: request.query),
            sourcePolicy: request.sourcePolicy
        )

        return ServerProviderSearchAPIAdapterPayloadDecision(
            id: "search-api-adapter-payload-decision-\(safeID(payload.id))",
            state: .payloadPrepared,
            statusLine: payload.statusLine,
            requestID: request.id,
            payload: payload,
            rejection: nil,
            requestDecisionRejection: nil
        )
    }

    private static func rejected(
        request: ServerProviderSearchAPIAdapterRequest,
        reason: ServerProviderSearchAPIAdapterPayloadRejectionReason
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        rejected(
            idSeed: "\(request.id)-\(reason.rawValue)",
            requestID: request.id,
            reason: reason,
            requestDecisionRejection: nil,
            statusLine: "Search API adapter payload is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run."
        )
    }

    private static func rejected(
        idSeed: String,
        requestID: String?,
        reason: ServerProviderSearchAPIAdapterPayloadRejectionReason,
        requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason?,
        statusLine: String
    ) -> ServerProviderSearchAPIAdapterPayloadDecision {
        ServerProviderSearchAPIAdapterPayloadDecision(
            id: "search-api-adapter-payload-decision-\(safeID(idSeed))-\(reason.rawValue)",
            state: .rejected,
            statusLine: statusLine,
            requestID: requestID,
            payload: nil,
            rejection: reason,
            requestDecisionRejection: requestDecisionRejection
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
        return slug.isEmpty ? "missing-search-api-payload-id" : slug
    }
}
