//
//  ServerProviderRuntimeAdapterRegistry.swift
//  kAir
//
//  Pure A21 adapter registry contract for future provider adapters.
//  This file selects fixture adapters only and never invokes providers.
//

import Foundation

struct ServerProviderRuntimeAdapterSet: Sendable {
    private let adaptersByProviderFamily: [ProviderFamily: any ServerProviderRuntimeAdapter]
    let registeredProviderFamilies: Set<ProviderFamily>

    init(adapters: [any ServerProviderRuntimeAdapter]) {
        var resolvedAdapters: [ProviderFamily: any ServerProviderRuntimeAdapter] = [:]
        for adapter in adapters where resolvedAdapters[adapter.providerFamily] == nil {
            resolvedAdapters[adapter.providerFamily] = adapter
        }
        self.adaptersByProviderFamily = resolvedAdapters
        self.registeredProviderFamilies = Set(resolvedAdapters.keys)
    }

    func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        guard boundary.state == .prepared else {
            return FixtureServerProviderRuntimeAdapter(
                providerFamily: boundary.providerFamily ?? .googleMaps
            )
            .resolve(boundary)
        }

        guard let family = boundary.providerFamily else {
            return Self.rejectedResult(
                boundary,
                reason: .missingProviderFamily,
                statusLine: "Injected adapter set result is unavailable because provider family is missing."
            )
        }

        guard let adapter = adaptersByProviderFamily[family] else {
            return Self.rejectedResult(
                boundary,
                reason: .unregisteredProvider,
                statusLine: "Injected adapter set result is unavailable because provider family is not registered."
            )
        }

        return adapter.resolve(boundary)
    }

    private static func rejectedResult(
        _ boundary: ServerProviderRuntimeDispatchBoundary,
        reason: ServerProviderRuntimeAdapterRejectionReason,
        statusLine: String
    ) -> ServerProviderRuntimeAdapterResult {
        ServerProviderRuntimeAdapterResult(
            id: "server-provider-adapter-set-\(safeID(boundary.id))",
            state: .notPrepared,
            statusLine: statusLine,
            boundaryID: boundary.id,
            planID: boundary.planID,
            traceID: nil,
            providerFamily: nil,
            capability: nil,
            descriptorID: nil,
            costClass: nil,
            freshness: nil,
            sourcePolicy: nil,
            confirmationState: nil,
            audit: ServerProviderRuntimeAdapterAudit(
                boundaryID: boundary.id,
                boundaryState: boundary.state,
                planID: boundary.planID,
                planState: boundary.audit.planState,
                readinessID: boundary.audit.readinessID,
                lookupID: boundary.audit.lookupID,
                readinessState: boundary.audit.readinessState,
                lookupState: boundary.audit.lookupState,
                dispatchRejectionReason: boundary.audit.rejectionReason,
                adapterRejectionReason: reason,
                factoryRejectionReason: boundary.audit.factoryRejectionReason,
                validatorDenialReason: boundary.audit.validatorDenialReason
            )
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
        return slug.isEmpty ? "missing-boundary-id" : slug
    }
}

enum ServerProviderRuntimeAdapterRegistry {
    nonisolated static let registeredProviderFamilies: Set<ProviderFamily> = [
        .googleMaps,
        .gaode,
        .searchAPI,
        .crawler,
        .mcp,
    ]

    nonisolated static func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        guard boundary.state == .prepared else {
            return FixtureServerProviderRuntimeAdapter(
                providerFamily: boundary.providerFamily ?? .googleMaps
            )
            .resolve(boundary)
        }

        guard let family = boundary.providerFamily else {
            return rejectedResult(
                boundary,
                reason: .missingProviderFamily,
                statusLine: "Adapter registry result is unavailable because provider family is missing."
            )
        }

        guard registeredProviderFamilies.contains(family) else {
            return rejectedResult(
                boundary,
                reason: .unregisteredProvider,
                statusLine: "Adapter registry result is unavailable because provider family is not registered."
            )
        }

        return FixtureServerProviderRuntimeAdapter(providerFamily: family)
            .resolve(boundary)
    }

    nonisolated private static func rejectedResult(
        _ boundary: ServerProviderRuntimeDispatchBoundary,
        reason: ServerProviderRuntimeAdapterRejectionReason,
        statusLine: String
    ) -> ServerProviderRuntimeAdapterResult {
        ServerProviderRuntimeAdapterResult(
            id: "server-provider-adapter-registry-\(safeID(boundary.id))",
            state: .notPrepared,
            statusLine: statusLine,
            boundaryID: boundary.id,
            planID: boundary.planID,
            traceID: nil,
            providerFamily: nil,
            capability: nil,
            descriptorID: nil,
            costClass: nil,
            freshness: nil,
            sourcePolicy: nil,
            confirmationState: nil,
            audit: ServerProviderRuntimeAdapterAudit(
                boundaryID: boundary.id,
                boundaryState: boundary.state,
                planID: boundary.planID,
                planState: boundary.audit.planState,
                readinessID: boundary.audit.readinessID,
                lookupID: boundary.audit.lookupID,
                readinessState: boundary.audit.readinessState,
                lookupState: boundary.audit.lookupState,
                dispatchRejectionReason: boundary.audit.rejectionReason,
                adapterRejectionReason: reason,
                factoryRejectionReason: boundary.audit.factoryRejectionReason,
                validatorDenialReason: boundary.audit.validatorDenialReason
            )
        )
    }

    nonisolated private static func safeID(_ value: String) -> String {
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
