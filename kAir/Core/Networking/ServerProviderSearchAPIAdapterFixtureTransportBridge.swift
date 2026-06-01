//
//  ServerProviderSearchAPIAdapterFixtureTransportBridge.swift
//  kAir
//
//  Value-only fixture bridge for verified Search API adapter dispatch metadata.
//  It produces audit metadata only and never calls a provider or external runtime.
//

import Foundation

enum ServerProviderSearchAPIAdapterFixtureTransportBridgeState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case fixtureReady
    case rejected
}

enum ServerProviderSearchAPIAdapterFixtureTransportBridgeRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case requestDecisionRejected
    case missingPreparedRequest
    case payloadDecisionRejected
    case missingPayload
    case dispatchReceiptBlocked
    case payloadDecisionIDMismatch
    case payloadIDMismatch
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

struct ServerProviderSearchAPIAdapterFixtureTransportBridgeInput:
    Codable,
    Hashable,
    Sendable
{
    let requestDecision: ServerProviderSearchAPIAdapterRequestDecision
    let payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision
    let dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
}

struct ServerProviderSearchAPIAdapterFixtureTransportAudit:
    Codable,
    Hashable,
    Sendable
{
    let traceID: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let resultLimit: Int
    let sourceHost: String?
    let requestID: String
    let payloadDecisionID: String
    let payloadID: String
    let dispatchReceiptID: String
}

struct ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPIAdapterFixtureTransportBridgeState
    let statusLine: String
    let requestID: String?
    let payloadDecisionID: String?
    let payloadID: String?
    let dispatchReceiptID: String?
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let freshness: ProviderFreshness?
    let costClass: ProviderCostClass?
    let resultLimit: Int?
    let sourcePolicy: ServerProviderSearchAPIAdapterSourcePolicySnapshot?
    let audit: ServerProviderSearchAPIAdapterFixtureTransportAudit?
    let rejection: ServerProviderSearchAPIAdapterFixtureTransportBridgeRejectionReason?
    let requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason?
    let payloadDecisionRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason?
    let dispatchReceiptRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason?

    var isFixtureReady: Bool {
        state == .fixtureReady
            && audit != nil
            && rejection == nil
    }

    var description: String {
        "SearchAPIAdapterFixtureBridgeResponse(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPIAdapterFixtureTransportBridge {
    static func evaluate(
        input: ServerProviderSearchAPIAdapterFixtureTransportBridgeInput
    ) -> ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse {
        evaluate(
            requestDecision: input.requestDecision,
            payloadDecision: input.payloadDecision,
            dispatchReceipt: input.dispatchReceipt
        )
    }

    static func evaluate(
        requestDecision: ServerProviderSearchAPIAdapterRequestDecision,
        payloadDecision: ServerProviderSearchAPIAdapterPayloadDecision,
        dispatchReceipt: ServerProviderSearchAPIAdapterPayloadDispatchReceipt
    ) -> ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse {
        let input = ServerProviderSearchAPIAdapterFixtureTransportBridgeInput(
            requestDecision: requestDecision,
            payloadDecision: payloadDecision,
            dispatchReceipt: dispatchReceipt
        )

        guard requestDecision.state == .requestPrepared else {
            return rejected(
                input: input,
                reason: .requestDecisionRejected,
                requestDecisionRejection: requestDecision.rejection
            )
        }
        guard let request = requestDecision.request else {
            return rejected(input: input, reason: .missingPreparedRequest)
        }
        guard payloadDecision.state == .payloadPrepared else {
            return rejected(
                input: input,
                requestID: request.id,
                reason: .payloadDecisionRejected,
                payloadDecisionRejection: payloadDecision.rejection,
                requestDecisionRejection: payloadDecision.requestDecisionRejection
            )
        }
        guard let payload = payloadDecision.payload else {
            return rejected(input: input, requestID: request.id, reason: .missingPayload)
        }
        guard payloadDecision.requestID == request.id,
              payload.requestID == request.id else {
            return rejected(input: input, requestID: request.id, reason: .requestIDMismatch)
        }
        guard payload.traceID == request.traceID else {
            return rejected(input: input, requestID: request.id, reason: .traceIDMismatch)
        }
        guard payload.providerFamily == request.providerFamily else {
            return rejected(input: input, requestID: request.id, reason: .providerFamilyMismatch)
        }
        guard payload.capability == request.capability else {
            return rejected(input: input, requestID: request.id, reason: .capabilityMismatch)
        }
        guard payload.freshness == request.freshness else {
            return rejected(input: input, requestID: request.id, reason: .freshnessMismatch)
        }
        guard payload.costClass == request.costClass else {
            return rejected(input: input, requestID: request.id, reason: .costClassMismatch)
        }
        guard payload.resultLimit == request.resultLimit else {
            return rejected(input: input, requestID: request.id, reason: .resultLimitMismatch)
        }
        guard payload.query == ServerProviderSearchAPIAdapterPayloadQuery(
            requestQuery: request.query
        ) else {
            return rejected(input: input, requestID: request.id, reason: .queryMismatch)
        }
        guard payload.sourcePolicy == request.sourcePolicy else {
            return rejected(input: input, requestID: request.id, reason: .sourcePolicyMismatch)
        }
        guard request.query.isValid else {
            return rejected(input: input, requestID: request.id, reason: .emptyQuery)
        }
        guard request.providerFamily == .searchAPI else {
            return rejected(input: input, requestID: request.id, reason: .providerFamilyNotSearchAPI)
        }
        guard request.capability == .webSearch || request.capability == .localServiceSearch else {
            return rejected(input: input, requestID: request.id, reason: .unsupportedCapability)
        }
        guard request.privacyClass == .general else {
            return rejected(input: input, requestID: request.id, reason: .privacyBlocked)
        }
        guard request.quotaSummary.isAllowed else {
            return rejected(input: input, requestID: request.id, reason: .quotaBlocked)
        }
        guard (1...ServerProviderSearchAPIAdapterContract.maximumResultLimit)
            .contains(request.resultLimit) else {
            return rejected(input: input, requestID: request.id, reason: .invalidResultLimit)
        }
        guard request.sourcePolicy.hasApprovedSourcePolicy else {
            return rejected(input: input, requestID: request.id, reason: .sourcePolicyInsufficient)
        }
        guard request.sourcePolicy.hasCitationPolicy else {
            return rejected(input: input, requestID: request.id, reason: .citationPolicyMissing)
        }
        guard dispatchReceipt.state == .dispatchEligible,
              dispatchReceipt.isDispatchEligible else {
            return rejected(
                input: input,
                requestID: request.id,
                reason: .dispatchReceiptBlocked,
                dispatchReceiptRejection: dispatchReceipt.rejection,
                payloadDecisionRejection: dispatchReceipt.payloadDecisionRejection,
                requestDecisionRejection: dispatchReceipt.requestDecisionRejection
            )
        }
        guard dispatchReceipt.requestID == request.id else {
            return rejected(input: input, requestID: request.id, reason: .requestIDMismatch)
        }
        guard dispatchReceipt.traceID == request.traceID else {
            return rejected(input: input, requestID: request.id, reason: .traceIDMismatch)
        }
        guard dispatchReceipt.providerFamily == request.providerFamily else {
            return rejected(input: input, requestID: request.id, reason: .providerFamilyMismatch)
        }
        guard dispatchReceipt.capability == request.capability else {
            return rejected(input: input, requestID: request.id, reason: .capabilityMismatch)
        }
        guard dispatchReceipt.freshness == request.freshness else {
            return rejected(input: input, requestID: request.id, reason: .freshnessMismatch)
        }
        guard dispatchReceipt.costClass == request.costClass else {
            return rejected(input: input, requestID: request.id, reason: .costClassMismatch)
        }
        guard dispatchReceipt.resultLimit == request.resultLimit else {
            return rejected(input: input, requestID: request.id, reason: .resultLimitMismatch)
        }
        guard dispatchReceipt.sourcePolicy == request.sourcePolicy else {
            return rejected(input: input, requestID: request.id, reason: .sourcePolicyMismatch)
        }
        guard payloadDecision.id == dispatchReceipt.payloadDecisionID else {
            return rejected(input: input, requestID: request.id, reason: .payloadDecisionIDMismatch)
        }
        guard payload.id == dispatchReceipt.payloadID else {
            return rejected(input: input, requestID: request.id, reason: .payloadIDMismatch)
        }

        return ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse(
            id: "search-api-adapter-fixture-bridge-\(safeID(dispatchReceipt.id))",
            state: .fixtureReady,
            statusLine: "Search API adapter fixture bridge is ready from fixture audit metadata only. No provider runtime has run.",
            requestID: request.id,
            payloadDecisionID: payloadDecision.id,
            payloadID: payload.id,
            dispatchReceiptID: dispatchReceipt.id,
            traceID: request.traceID,
            providerFamily: request.providerFamily,
            capability: request.capability,
            freshness: request.freshness,
            costClass: request.costClass,
            resultLimit: request.resultLimit,
            sourcePolicy: request.sourcePolicy,
            audit: ServerProviderSearchAPIAdapterFixtureTransportAudit(
                traceID: request.traceID,
                providerFamily: request.providerFamily,
                capability: request.capability,
                costClass: request.costClass,
                freshness: request.freshness,
                resultLimit: request.resultLimit,
                sourceHost: request.sourcePolicy.sourceHost,
                requestID: request.id,
                payloadDecisionID: payloadDecision.id,
                payloadID: payload.id,
                dispatchReceiptID: dispatchReceipt.id
            ),
            rejection: nil,
            requestDecisionRejection: nil,
            payloadDecisionRejection: nil,
            dispatchReceiptRejection: nil
        )
    }

    private static func rejected(
        input: ServerProviderSearchAPIAdapterFixtureTransportBridgeInput,
        requestID: String? = nil,
        reason: ServerProviderSearchAPIAdapterFixtureTransportBridgeRejectionReason,
        dispatchReceiptRejection: ServerProviderSearchAPIAdapterPayloadDispatchRejectionReason? = nil,
        payloadDecisionRejection: ServerProviderSearchAPIAdapterPayloadRejectionReason? = nil,
        requestDecisionRejection: ServerProviderSearchAPIAdapterRejectionReason? = nil
    ) -> ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse {
        let resolvedRequestID = requestID
            ?? input.requestDecision.request?.id
            ?? input.payloadDecision.requestID
            ?? input.dispatchReceipt.requestID
        return ServerProviderSearchAPIAdapterFixtureTransportBridgeResponse(
            id: "search-api-adapter-fixture-bridge-\(safeID(idSeed(input: input)))-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Search API adapter fixture bridge is blocked by metadata policy: \(reason.rawValue). No provider runtime has run.",
            requestID: resolvedRequestID,
            payloadDecisionID: input.payloadDecision.id,
            payloadID: input.payloadDecision.payload?.id ?? input.dispatchReceipt.payloadID,
            dispatchReceiptID: input.dispatchReceipt.id,
            traceID: input.requestDecision.request?.traceID
                ?? input.payloadDecision.payload?.traceID
                ?? input.dispatchReceipt.traceID,
            providerFamily: input.requestDecision.request?.providerFamily
                ?? input.payloadDecision.payload?.providerFamily
                ?? input.dispatchReceipt.providerFamily,
            capability: input.requestDecision.request?.capability
                ?? input.payloadDecision.payload?.capability
                ?? input.dispatchReceipt.capability,
            freshness: input.requestDecision.request?.freshness
                ?? input.payloadDecision.payload?.freshness
                ?? input.dispatchReceipt.freshness,
            costClass: input.requestDecision.request?.costClass
                ?? input.payloadDecision.payload?.costClass
                ?? input.dispatchReceipt.costClass,
            resultLimit: input.requestDecision.request?.resultLimit
                ?? input.payloadDecision.payload?.resultLimit
                ?? input.dispatchReceipt.resultLimit,
            sourcePolicy: input.requestDecision.request?.sourcePolicy
                ?? input.payloadDecision.payload?.sourcePolicy
                ?? input.dispatchReceipt.sourcePolicy,
            audit: nil,
            rejection: reason,
            requestDecisionRejection: requestDecisionRejection,
            payloadDecisionRejection: payloadDecisionRejection,
            dispatchReceiptRejection: dispatchReceiptRejection
        )
    }

    private static func idSeed(
        input: ServerProviderSearchAPIAdapterFixtureTransportBridgeInput
    ) -> String {
        [
            input.requestDecision.id,
            input.payloadDecision.id,
            input.dispatchReceipt.id,
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
        return slug.isEmpty ? "missing-search-api-fixture-bridge-id" : slug
    }
}
