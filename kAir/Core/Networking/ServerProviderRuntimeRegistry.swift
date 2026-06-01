//
//  ServerProviderRuntimeRegistry.swift
//  kAir
//
//  Pure A17 registry contract for future server-provider runtime adapters.
//  This file stores metadata only and never invokes providers.
//

import Foundation

enum ServerProviderRuntimeLookupState: String, Codable, Hashable, Sendable, CaseIterable {
    case descriptorAvailable
    case localOnly
    case confirmationRequired
    case blocked
    case unsupportedProvider
}

struct ServerProviderRuntimeDescriptor: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let providerFamily: ProviderFamily
    let displayName: String
    let supportedCapabilities: Set<ProviderCapability>
    let requiredMembershipTier: MembershipTier
    let costClass: ProviderCostClass
    let requiresSourcePolicy: Bool
    let requiresRobotsAllow: Bool
    let requiresConfirmation: Bool
    let requiresExperimentalEnablement: Bool
}

struct ServerProviderRuntimeLookupResult: Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeLookupState
    let descriptor: ServerProviderRuntimeDescriptor?
    let readinessDecision: ServerProviderExecutionReadinessDecision
    let statusLine: String

    var hasDescriptor: Bool {
        descriptor != nil
    }
}

enum ServerProviderRuntimeRegistry {
    nonisolated static let descriptors: [ServerProviderRuntimeDescriptor] = [
        ServerProviderRuntimeDescriptor(
            id: "runtime-google-maps",
            providerFamily: .googleMaps,
            displayName: "Google Maps",
            supportedCapabilities: [.placeSearch, .routePlanning, .localServiceSearch],
            requiredMembershipTier: .plus,
            costClass: .meteredPremium,
            requiresSourcePolicy: false,
            requiresRobotsAllow: false,
            requiresConfirmation: false,
            requiresExperimentalEnablement: false
        ),
        ServerProviderRuntimeDescriptor(
            id: "runtime-gaode",
            providerFamily: .gaode,
            displayName: "Gaode",
            supportedCapabilities: [.placeSearch, .routePlanning, .localServiceSearch],
            requiredMembershipTier: .plus,
            costClass: .includedQuota,
            requiresSourcePolicy: false,
            requiresRobotsAllow: false,
            requiresConfirmation: false,
            requiresExperimentalEnablement: false
        ),
        ServerProviderRuntimeDescriptor(
            id: "runtime-search-api",
            providerFamily: .searchAPI,
            displayName: "Search API",
            supportedCapabilities: [.webSearch, .localServiceSearch],
            requiredMembershipTier: .plus,
            costClass: .meteredPremium,
            requiresSourcePolicy: true,
            requiresRobotsAllow: false,
            requiresConfirmation: false,
            requiresExperimentalEnablement: false
        ),
        ServerProviderRuntimeDescriptor(
            id: "runtime-crawler",
            providerFamily: .crawler,
            displayName: "Crawler",
            supportedCapabilities: [.crawlerFetch, .localServiceSearch],
            requiredMembershipTier: .pro,
            costClass: .meteredPremium,
            requiresSourcePolicy: true,
            requiresRobotsAllow: true,
            requiresConfirmation: false,
            requiresExperimentalEnablement: true
        ),
        ServerProviderRuntimeDescriptor(
            id: "runtime-mcp",
            providerFamily: .mcp,
            displayName: "MCP",
            supportedCapabilities: [.mcpTool],
            requiredMembershipTier: .pro,
            costClass: .includedQuota,
            requiresSourcePolicy: false,
            requiresRobotsAllow: false,
            requiresConfirmation: true,
            requiresExperimentalEnablement: true
        ),
    ]

    nonisolated static func lookup(
        for readinessDecision: ServerProviderExecutionReadinessDecision
    ) -> ServerProviderRuntimeLookupResult {
        let state = lookupState(for: readinessDecision)
        let descriptor = state == .descriptorAvailable
            ? descriptor(for: readinessDecision.providerFamily)
            : nil
        let resolvedState = hasDescriptor(descriptor) == false && state == .descriptorAvailable
            ? ServerProviderRuntimeLookupState.unsupportedProvider
            : state
        return ServerProviderRuntimeLookupResult(
            id: "server-provider-runtime-\(readinessDecision.id)",
            state: resolvedState,
            descriptor: descriptor,
            readinessDecision: readinessDecision,
            statusLine: statusLine(
                state: resolvedState,
                descriptor: descriptor,
                readinessDecision: readinessDecision
            )
        )
    }

    nonisolated private static func lookupState(
        for readinessDecision: ServerProviderExecutionReadinessDecision
    ) -> ServerProviderRuntimeLookupState {
        switch readinessDecision.state {
        case .serverReady:
            return .descriptorAvailable
        case .localOnly:
            return .localOnly
        case .confirmationRequired:
            return .confirmationRequired
        case .blocked:
            return .blocked
        }
    }

    nonisolated private static func descriptor(
        for providerFamily: ProviderFamily?
    ) -> ServerProviderRuntimeDescriptor? {
        guard let providerFamily else { return nil }
        return descriptors.first { $0.providerFamily == providerFamily }
    }

    nonisolated private static func hasDescriptor(
        _ descriptor: ServerProviderRuntimeDescriptor?
    ) -> Bool {
        guard case .some = descriptor else {
            return false
        }
        return true
    }

    nonisolated private static func statusLine(
        state: ServerProviderRuntimeLookupState,
        descriptor: ServerProviderRuntimeDescriptor?,
        readinessDecision: ServerProviderExecutionReadinessDecision
    ) -> String {
        switch state {
        case .descriptorAvailable:
            return "\(descriptor?.displayName ?? "Provider") runtime descriptor is available as metadata only. No provider runtime has run."
        case .localOnly:
            return "Local-only readiness does not use the server runtime registry. \(readinessDecision.statusLine)"
        case .confirmationRequired:
            return "Runtime descriptor is withheld until confirmation is satisfied. \(readinessDecision.statusLine)"
        case .blocked:
            return "Runtime descriptor is unavailable because readiness is blocked. \(readinessDecision.statusLine)"
        case .unsupportedProvider:
            return "Runtime descriptor is unavailable for this provider family. \(readinessDecision.statusLine)"
        }
    }
}
