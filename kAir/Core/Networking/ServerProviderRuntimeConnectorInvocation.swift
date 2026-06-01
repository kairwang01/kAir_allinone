//
//  ServerProviderRuntimeConnectorInvocation.swift
//  kAir
//
//  Value-only receipt projection for future remote provider connectors.
//

import Foundation

enum ServerProviderRuntimeConnectorInvocationState: String, Codable, Hashable, Sendable, CaseIterable {
    case receiptPrepared
    case rejected
}

enum ServerProviderRuntimeConnectorInvocationRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case planningRejected
    case missingConnectorRequest
    case connectorRejected
}

struct ServerProviderRuntimeConnectorInvocationReceipt:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderRuntimeConnectorInvocationState
    let statusLine: String
    let planningID: String
    let planningState: ServerProviderRuntimeConnectorPlanningState
    let planningRejection: ServerProviderRuntimeConnectorPlanningRejectionReason?
    let connectorProviderFamily: ProviderFamily?
    let requestID: String?
    let resultID: String?
    let connectorResultState: ServerProviderRuntimeConnectorResultState?
    let connectorRejection: ServerProviderRuntimeConnectorRejectionReason?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let manifestID: String?
    let authorizationID: String?
    let boundaryID: String
    let traceID: String?
    let invocationRejection: ServerProviderRuntimeConnectorInvocationRejectionReason?

    var description: String {
        "ServerProviderRuntimeConnectorInvocationReceipt(id: \(id), state: \(state.rawValue), providerFamily: \(providerFamily?.rawValue ?? "none"), rejection: \(invocationRejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderRuntimeConnectorInvoker {
    static func invoke(
        planningResult: ServerProviderRuntimeConnectorPlanningResult,
        connector: ServerProviderRuntimeConnector
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        guard planningResult.state == .requestPrepared else {
            return rejected(
                planningResult: planningResult,
                connectorProviderFamily: connector.providerFamily,
                request: nil,
                result: nil,
                rejection: .planningRejected
            )
        }

        guard let request = planningResult.request else {
            return rejected(
                planningResult: planningResult,
                connectorProviderFamily: connector.providerFamily,
                request: nil,
                result: nil,
                rejection: .missingConnectorRequest
            )
        }

        let result = connector.prepare(request)
        switch result.state {
        case .metadataPrepared:
            return prepared(
                planningResult: planningResult,
                connectorProviderFamily: connector.providerFamily,
                result: result
            )
        case .rejected:
            return rejected(
                planningResult: planningResult,
                connectorProviderFamily: connector.providerFamily,
                request: request,
                result: result,
                rejection: .connectorRejected
            )
        }
    }

    private static func prepared(
        planningResult: ServerProviderRuntimeConnectorPlanningResult,
        connectorProviderFamily: ProviderFamily,
        result: ServerProviderRuntimeConnectorResult
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: receiptID(for: planningResult),
            state: .receiptPrepared,
            statusLine: "Connector receipt captured metadata-only connector output. No provider runtime has run.",
            planningID: planningResult.id,
            planningState: planningResult.state,
            planningRejection: planningResult.rejection,
            connectorProviderFamily: connectorProviderFamily,
            requestID: result.requestID,
            resultID: result.id,
            connectorResultState: result.state,
            connectorRejection: result.rejection,
            providerFamily: result.providerFamily,
            capability: result.capability,
            costClass: result.costClass,
            freshness: result.freshness,
            manifestID: result.manifestID,
            authorizationID: result.authorizationID,
            boundaryID: result.boundaryID,
            traceID: result.traceID,
            invocationRejection: nil
        )
    }

    private static func rejected(
        planningResult: ServerProviderRuntimeConnectorPlanningResult,
        connectorProviderFamily: ProviderFamily,
        request: ServerProviderRuntimeConnectorRequest?,
        result: ServerProviderRuntimeConnectorResult?,
        rejection: ServerProviderRuntimeConnectorInvocationRejectionReason
    ) -> ServerProviderRuntimeConnectorInvocationReceipt {
        ServerProviderRuntimeConnectorInvocationReceipt(
            id: "\(receiptID(for: planningResult))-\(rejection.rawValue)",
            state: .rejected,
            statusLine: "Connector receipt is rejected as metadata only: \(rejection.rawValue). No provider runtime has run.",
            planningID: planningResult.id,
            planningState: planningResult.state,
            planningRejection: planningResult.rejection,
            connectorProviderFamily: connectorProviderFamily,
            requestID: result?.requestID ?? request?.id,
            resultID: result?.id,
            connectorResultState: result?.state,
            connectorRejection: result?.rejection,
            providerFamily: result?.providerFamily,
            capability: result?.capability,
            costClass: result?.costClass,
            freshness: result?.freshness,
            manifestID: result?.manifestID,
            authorizationID: result?.authorizationID,
            boundaryID: result?.boundaryID ?? planningResult.boundaryID,
            traceID: result?.traceID,
            invocationRejection: rejection
        )
    }

    private static func receiptID(
        for planningResult: ServerProviderRuntimeConnectorPlanningResult
    ) -> String {
        "provider-runtime-connector-invocation-\(safeID(planningResult.id))"
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
        return slug.isEmpty ? "missing-planning-id" : slug
    }
}
