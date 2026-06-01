//
//  ServerProviderSearchAPITransportResponse.swift
//  kAir
//
//  Value-only Search API transport response contract. This file binds a
//  normalized adapter result receipt back to the prepared transport request
//  before any future transport/provider runtime can be introduced.
//

import Foundation

enum ServerProviderSearchAPITransportResponseState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case responseAccepted
    case rejected
}

enum ServerProviderSearchAPITransportResponseRejectionReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case missingTransportRequestDecision
    case transportRequestDecisionRejected
    case missingTransportRequest
    case missingAdapterResultReceipt
    case adapterResultRejected
    case missingResult
    case requestIDMismatch
    case providerFamilyMismatch
    case capabilityMismatch
    case costClassMismatch
    case freshnessMismatch
    case resultLimitOverflow
    case sourceCitationPolicyMismatch
    case citationMissing
    case vendorMissing
    case leaseMetadataMissing
    case budgetMetadataMissing
    case meteredMetadataMissing
    case normalizedContentMissing
}

struct ServerProviderSearchAPITransportResponse:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let transportRequestID: String
    let adapterResultReceiptID: String
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
    let requestedResultLimit: Int
    let returnedResultCount: Int
    let citationCount: Int
    let sourceCitationSummary: ServerProviderSearchAPITransportSourceCitationSummary

    var statusLine: String {
        "Search API transport response is accepted from request-bound cited metadata only. No transport or provider runtime has run."
    }

    var description: String {
        "ServerProviderSearchAPITransportResponse(id: \(id), providerFamily: \(providerFamily.rawValue), vendorID: \(vendorID), returnedResultCount: \(returnedResultCount), citationCount: \(citationCount))"
    }
}

struct ServerProviderSearchAPITransportResponseDecision:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderSearchAPITransportResponseState
    let statusLine: String
    let response: ServerProviderSearchAPITransportResponse?
    let rejection: ServerProviderSearchAPITransportResponseRejectionReason?
    let transportRequestRejection: ServerProviderSearchAPITransportRequestRejectionReason?
    let adapterResultRejection: ServerProviderSearchAPIAdapterRejectionReason?

    var isAccepted: Bool {
        state == .responseAccepted && response != nil
    }

    var description: String {
        "ServerProviderSearchAPITransportResponseDecision(id: \(id), state: \(state.rawValue), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderSearchAPITransportResponseBuilder {
    static func accept(
        transportRequestDecision: ServerProviderSearchAPITransportRequestDecision?,
        adapterResultReceipt: ServerProviderSearchAPIAdapterResultReceipt?,
        returnedResultCount: Int = 1
    ) -> ServerProviderSearchAPITransportResponseDecision {
        guard let transportRequestDecision else {
            return rejected(reason: .missingTransportRequestDecision)
        }
        guard transportRequestDecision.state == .requestPrepared else {
            return rejected(
                reason: .transportRequestDecisionRejected,
                transportRequestDecision: transportRequestDecision
            )
        }
        guard let transportRequest = transportRequestDecision.request else {
            return rejected(
                reason: .missingTransportRequest,
                transportRequestDecision: transportRequestDecision
            )
        }
        guard let adapterResultReceipt else {
            return rejected(
                reason: .missingAdapterResultReceipt,
                transportRequestDecision: transportRequestDecision
            )
        }
        guard adapterResultReceipt.state == .resultNormalized else {
            return rejected(
                reason: .adapterResultRejected,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard let result = adapterResultReceipt.result else {
            return rejected(
                reason: .missingResult,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }

        guard transportRequest.vendorID.isEmpty == false else {
            return rejected(
                reason: .vendorMissing,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard transportRequest.leaseID.isEmpty == false else {
            return rejected(
                reason: .leaseMetadataMissing,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard transportRequest.budgetID.isEmpty == false else {
            return rejected(
                reason: .budgetMetadataMissing,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard transportRequest.meteredDecisionID.isEmpty == false else {
            return rejected(
                reason: .meteredMetadataMissing,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }

        guard adapterResultReceipt.requestID == transportRequest.requestID,
              result.requestID == transportRequest.requestID else {
            return rejected(
                reason: .requestIDMismatch,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard adapterResultReceipt.providerFamily == transportRequest.providerFamily,
              result.providerFamily == transportRequest.providerFamily else {
            return rejected(
                reason: .providerFamilyMismatch,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard adapterResultReceipt.capability == transportRequest.capability,
              result.capability == transportRequest.capability else {
            return rejected(
                reason: .capabilityMismatch,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard adapterResultReceipt.costClass == transportRequest.costClass,
              result.costClass == transportRequest.costClass else {
            return rejected(
                reason: .costClassMismatch,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard result.freshness == transportRequest.freshness else {
            return rejected(
                reason: .freshnessMismatch,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard returnedResultCount > 0,
              result.title.isEmpty == false,
              result.snippet.isEmpty == false else {
            return rejected(
                reason: .normalizedContentMissing,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard returnedResultCount <= transportRequest.resultLimit else {
            return rejected(
                reason: .resultLimitOverflow,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard transportRequest.sourceCitationSummary.sourceState == .passed,
              transportRequest.sourceCitationSummary.attributionRequired,
              transportRequest.sourceCitationSummary.citationRequired else {
            return rejected(
                reason: .sourceCitationPolicyMismatch,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }
        guard result.citations.isEmpty == false,
              result.citations.allSatisfy(\.isValid) else {
            return rejected(
                reason: .citationMissing,
                transportRequestDecision: transportRequestDecision,
                adapterResultReceipt: adapterResultReceipt
            )
        }

        let response = ServerProviderSearchAPITransportResponse(
            id: "search-api-transport-response-\(safeID(transportRequest.id))-\(safeID(adapterResultReceipt.id))",
            transportRequestID: transportRequest.id,
            adapterResultReceiptID: adapterResultReceipt.id,
            requestID: transportRequest.requestID,
            payloadDecisionID: transportRequest.payloadDecisionID,
            payloadID: transportRequest.payloadID,
            dispatchReceiptID: transportRequest.dispatchReceiptID,
            vendorDecisionID: transportRequest.vendorDecisionID,
            authorizationID: transportRequest.authorizationID,
            leaseID: transportRequest.leaseID,
            budgetID: transportRequest.budgetID,
            meteredDecisionID: transportRequest.meteredDecisionID,
            providerFamily: transportRequest.providerFamily,
            vendorID: transportRequest.vendorID,
            capability: transportRequest.capability,
            costClass: transportRequest.costClass,
            freshness: transportRequest.freshness,
            resultShape: transportRequest.resultShape,
            requestedResultLimit: transportRequest.resultLimit,
            returnedResultCount: returnedResultCount,
            citationCount: result.citations.count,
            sourceCitationSummary: transportRequest.sourceCitationSummary
        )

        return ServerProviderSearchAPITransportResponseDecision(
            id: "search-api-transport-response-decision-\(safeID(response.id))",
            state: .responseAccepted,
            statusLine: response.statusLine,
            response: response,
            rejection: nil,
            transportRequestRejection: nil,
            adapterResultRejection: nil
        )
    }

    private static func rejected(
        reason: ServerProviderSearchAPITransportResponseRejectionReason,
        transportRequestDecision: ServerProviderSearchAPITransportRequestDecision? = nil,
        adapterResultReceipt: ServerProviderSearchAPIAdapterResultReceipt? = nil
    ) -> ServerProviderSearchAPITransportResponseDecision {
        ServerProviderSearchAPITransportResponseDecision(
            id: "search-api-transport-response-decision-\(safeID(transportRequestDecision?.request?.id ?? "missing-transport-request"))-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Search API transport response is blocked by metadata policy: \(reason.rawValue). No transport or provider runtime has run.",
            response: nil,
            rejection: reason,
            transportRequestRejection: transportRequestDecision?.rejection,
            adapterResultRejection: adapterResultReceipt?.rejection
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
        return slug.isEmpty ? "search-api-transport-response" : slug
    }
}
