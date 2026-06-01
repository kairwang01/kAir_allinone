//
//  ServerProviderRuntimeConnector.swift
//  kAir
//
//  Value-only connector boundary for future remote provider adapters.
//

import Foundation

enum ServerProviderRuntimeConnectorResultState: String, Codable, Hashable, Sendable, CaseIterable {
    case metadataPrepared
    case rejected
}

enum ServerProviderRuntimeConnectorRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case providerFamilyNotEligible
    case manifestProviderFamilyMismatch
    case authorizationProviderFamilyMismatch
    case authorizationRejected
    case connectorProviderFamilyMismatch
}

struct ServerProviderRuntimeConnectorRequest:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let providerFamily: ProviderFamily
    let capability: ProviderCapability
    let costClass: ProviderCostClass
    let freshness: ProviderFreshness
    let manifestID: String
    let authorizationID: String
    let boundaryID: String
    let traceID: String

    init?(
        providerFamily: ProviderFamily,
        capability: ProviderCapability,
        costClass: ProviderCostClass,
        freshness: ProviderFreshness,
        manifest: ServerProviderRuntimeAdapterManifest,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization,
        boundaryID: String,
        traceID: String
    ) {
        guard ServerProviderRuntimeConnectorCatalog.isEligible(providerFamily) else {
            return nil
        }
        guard manifest.providerFamily == providerFamily else {
            return nil
        }
        guard authorization.requestedProviderFamily == providerFamily else {
            return nil
        }
        guard authorization.isAuthorized else {
            return nil
        }

        self.id = "provider-runtime-connector-request-\(providerFamily.rawValue)-\(Self.safeID(boundaryID))"
        self.providerFamily = providerFamily
        self.capability = capability
        self.costClass = costClass
        self.freshness = freshness
        self.manifestID = manifest.id
        self.authorizationID = authorization.id
        self.boundaryID = boundaryID
        self.traceID = traceID
    }

    var statusLine: String {
        "Connector request is prepared from approved metadata only. No provider runtime has run."
    }

    var description: String {
        "ServerProviderRuntimeConnectorRequest(id: \(id), providerFamily: \(providerFamily.rawValue), capability: \(capability.rawValue))"
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

struct ServerProviderRuntimeConnectorResult:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderRuntimeConnectorResultState
    let statusLine: String
    let requestID: String
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let manifestID: String?
    let authorizationID: String?
    let boundaryID: String
    let traceID: String?
    let rejection: ServerProviderRuntimeConnectorRejectionReason?

    var description: String {
        "ServerProviderRuntimeConnectorResult(id: \(id), state: \(state.rawValue), providerFamily: \(providerFamily?.rawValue ?? "none"), rejection: \(rejection?.rawValue ?? "none"))"
    }

    nonisolated static func metadataPrepared(
        request: ServerProviderRuntimeConnectorRequest
    ) -> ServerProviderRuntimeConnectorResult {
        ServerProviderRuntimeConnectorResult(
            id: "provider-runtime-connector-result-\(request.id)",
            state: .metadataPrepared,
            statusLine: "Connector boundary accepted metadata only. No provider runtime has run.",
            requestID: request.id,
            providerFamily: request.providerFamily,
            capability: request.capability,
            costClass: request.costClass,
            freshness: request.freshness,
            manifestID: request.manifestID,
            authorizationID: request.authorizationID,
            boundaryID: request.boundaryID,
            traceID: request.traceID,
            rejection: nil
        )
    }

    nonisolated static func rejected(
        request: ServerProviderRuntimeConnectorRequest,
        rejection: ServerProviderRuntimeConnectorRejectionReason
    ) -> ServerProviderRuntimeConnectorResult {
        ServerProviderRuntimeConnectorResult(
            id: "provider-runtime-connector-result-\(request.id)-\(rejection.rawValue)",
            state: .rejected,
            statusLine: "Connector boundary rejected metadata only: \(rejection.rawValue). No provider runtime has run.",
            requestID: request.id,
            providerFamily: nil,
            capability: nil,
            costClass: nil,
            freshness: nil,
            manifestID: nil,
            authorizationID: nil,
            boundaryID: request.boundaryID,
            traceID: nil,
            rejection: rejection
        )
    }
}

protocol ServerProviderRuntimeConnector: Sendable {
    var providerFamily: ProviderFamily { get }

    nonisolated func prepare(
        _ request: ServerProviderRuntimeConnectorRequest
    ) -> ServerProviderRuntimeConnectorResult
}

struct MetadataOnlyServerProviderRuntimeConnector: ServerProviderRuntimeConnector {
    let providerFamily: ProviderFamily

    nonisolated init(providerFamily: ProviderFamily) {
        self.providerFamily = providerFamily
    }

    nonisolated func prepare(
        _ request: ServerProviderRuntimeConnectorRequest
    ) -> ServerProviderRuntimeConnectorResult {
        guard request.providerFamily == providerFamily else {
            return .rejected(
                request: request,
                rejection: .connectorProviderFamilyMismatch
            )
        }

        return .metadataPrepared(request: request)
    }
}

enum ServerProviderRuntimeConnectorCatalog {
    nonisolated static let eligibleProviderFamilies: [ProviderFamily] = [
        .gaode,
        .googleMaps,
        .searchAPI,
        .crawler,
        .mcp,
    ]

    nonisolated static func isEligible(
        _ providerFamily: ProviderFamily
    ) -> Bool {
        eligibleProviderFamilies.contains(providerFamily)
    }
}
