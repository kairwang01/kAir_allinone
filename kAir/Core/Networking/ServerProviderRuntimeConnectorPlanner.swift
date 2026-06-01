//
//  ServerProviderRuntimeConnectorPlanner.swift
//  kAir
//
//  Value-only request planner for future remote provider connectors.
//

import Foundation

enum ServerProviderRuntimeConnectorPlanningState: String, Codable, Hashable, Sendable, CaseIterable {
    case requestPrepared
    case rejected
}

enum ServerProviderRuntimeConnectorPlanningRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case nonPreparedBoundary
    case missingRequestedProviderFamily
    case localNoConnector
    case providerFamilyNotEligible
    case manifestProviderFamilyMismatch
    case authorizationProviderFamilyMismatch
    case authorizationRejected
    case missingBoundaryMetadata
    case connectorRequestRejected
}

struct ServerProviderRuntimeConnectorPlanningResult:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderRuntimeConnectorPlanningState
    let statusLine: String
    let boundaryID: String
    let planID: String
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let manifestID: String?
    let authorizationID: String?
    let traceID: String?
    let requestID: String?
    let request: ServerProviderRuntimeConnectorRequest?
    let rejection: ServerProviderRuntimeConnectorPlanningRejectionReason?

    var isRequestPrepared: Bool {
        state == .requestPrepared && request != nil
    }

    var description: String {
        "ServerProviderRuntimeConnectorPlanningResult(id: \(id), state: \(state.rawValue), providerFamily: \(providerFamily?.rawValue ?? "missing"), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderRuntimeConnectorPlanner {
    static func plan(
        boundary: ServerProviderRuntimeDispatchBoundary,
        manifest: ServerProviderRuntimeAdapterManifest,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    ) -> ServerProviderRuntimeConnectorPlanningResult {
        guard boundary.state == .prepared else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .nonPreparedBoundary
            )
        }

        guard let providerFamily = boundary.providerFamily else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .missingRequestedProviderFamily
            )
        }

        guard providerFamily.isRemote else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .localNoConnector
            )
        }

        guard ServerProviderRuntimeConnectorCatalog.isEligible(providerFamily) else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .providerFamilyNotEligible
            )
        }

        guard manifest.providerFamily == providerFamily else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .manifestProviderFamilyMismatch
            )
        }

        guard authorization.requestedProviderFamily == providerFamily else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .authorizationProviderFamilyMismatch
            )
        }

        guard authorization.isAuthorized else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .authorizationRejected
            )
        }

        guard let traceID = nonEmpty(boundary.traceID),
              let capability = boundary.capability,
              let costClass = boundary.costClass,
              let freshness = boundary.freshness else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .missingBoundaryMetadata
            )
        }

        guard let request = ServerProviderRuntimeConnectorRequest(
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifest: manifest,
            authorization: authorization,
            boundaryID: boundary.id,
            traceID: traceID
        ) else {
            return rejected(
                boundary: boundary,
                manifest: manifest,
                authorization: authorization,
                reason: .connectorRequestRejected
            )
        }

        return ServerProviderRuntimeConnectorPlanningResult(
            id: planningID(for: boundary),
            state: .requestPrepared,
            statusLine: "Connector request planning is prepared as metadata only. No provider runtime has run.",
            boundaryID: boundary.id,
            planID: boundary.planID,
            providerFamily: providerFamily,
            capability: capability,
            costClass: costClass,
            freshness: freshness,
            manifestID: manifest.id,
            authorizationID: authorization.id,
            traceID: traceID,
            requestID: request.id,
            request: request,
            rejection: nil
        )
    }

    private static func rejected(
        boundary: ServerProviderRuntimeDispatchBoundary,
        manifest: ServerProviderRuntimeAdapterManifest,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization,
        reason: ServerProviderRuntimeConnectorPlanningRejectionReason
    ) -> ServerProviderRuntimeConnectorPlanningResult {
        ServerProviderRuntimeConnectorPlanningResult(
            id: "\(planningID(for: boundary))-\(reason.rawValue)",
            state: .rejected,
            statusLine: "Connector request planning is rejected as metadata only: \(reason.rawValue). No provider runtime has run.",
            boundaryID: boundary.id,
            planID: boundary.planID,
            providerFamily: boundary.providerFamily,
            capability: boundary.capability,
            costClass: boundary.costClass,
            freshness: boundary.freshness,
            manifestID: manifest.id,
            authorizationID: authorization.id,
            traceID: nil,
            requestID: nil,
            request: nil,
            rejection: reason
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value,
              value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return value
    }

    private static func planningID(
        for boundary: ServerProviderRuntimeDispatchBoundary
    ) -> String {
        "provider-runtime-connector-planning-\(safeID(boundary.id))"
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
        return slug.isEmpty ? "missing-boundary-id" : slug
    }
}
