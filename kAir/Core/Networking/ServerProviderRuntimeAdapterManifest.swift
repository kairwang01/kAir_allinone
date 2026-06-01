//
//  ServerProviderRuntimeAdapterManifest.swift
//  kAir
//
//  Value-only manifest catalog for future server-side provider adapters.
//

import Foundation

struct ServerProviderRuntimeAdapterManifest: Codable, Hashable, Identifiable, Sendable, CustomStringConvertible {
    let id: String
    let providerFamily: ProviderFamily
    let displayName: String
    let supportedCapabilities: Set<ProviderCapability>
    let requiredMembershipTier: MembershipTier
    let costClass: ProviderCostClass
    let requiredReadinessGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    let requiresRegionPolicy: Bool
    let requiresSourcePolicy: Bool
    let requiresRobotsAllow: Bool
    let requiresMCPToolResourceAllowlist: Bool
    let requiresHumanReview: Bool
    let requiresExperimentalEnablement: Bool

    var statusLine: String {
        "\(displayName) adapter manifest requires \(requiredReadinessGates.count) readiness gates before adapter installation. Metadata only; no provider runtime has run."
    }

    var description: String {
        "ServerProviderRuntimeAdapterManifest(id: \(id), providerFamily: \(providerFamily.rawValue), gateCount: \(requiredReadinessGates.count))"
    }
}

@MainActor
enum ServerProviderRuntimeAdapterManifestCatalog {
    static var manifests: [ServerProviderRuntimeAdapterManifest] {
        ProviderFamily.allCases
            .filter(\.isRemote)
            .map(manifest)
    }

    static func manifest(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeAdapterManifest? {
        manifests.first { $0.providerFamily == providerFamily }
    }

    static func manifests(
        for providerFamilies: [ProviderFamily]
    ) -> [ServerProviderRuntimeAdapterManifest] {
        var seenFamilies: Set<ProviderFamily> = []
        var selectedManifests: [ServerProviderRuntimeAdapterManifest] = []

        for providerFamily in providerFamilies {
            guard seenFamilies.insert(providerFamily).inserted,
                  let manifest = manifest(for: providerFamily)
            else {
                continue
            }
            selectedManifests.append(manifest)
        }

        return selectedManifests
    }

    private static func manifest(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeAdapterManifest {
        let report = ServerProviderRuntimeAdapterReadinessMatrix.report(for: providerFamily)
        let gates = report.requiredGates
        return ServerProviderRuntimeAdapterManifest(
            id: "provider-runtime-adapter-manifest-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            displayName: report.displayName,
            supportedCapabilities: report.supportedCapabilities,
            requiredMembershipTier: report.requiredMembershipTier,
            costClass: report.costClass,
            requiredReadinessGates: gates,
            requiresRegionPolicy: gates.contains(.regionPolicy),
            requiresSourcePolicy: gates.contains(.sourceAttribution),
            requiresRobotsAllow: gates.contains(.robotsAllow),
            requiresMCPToolResourceAllowlist: gates.contains(.toolResourceAllowlist),
            requiresHumanReview: gates.contains(.humanReview),
            requiresExperimentalEnablement: gates.contains(.experimentalEnablement)
        )
    }
}
