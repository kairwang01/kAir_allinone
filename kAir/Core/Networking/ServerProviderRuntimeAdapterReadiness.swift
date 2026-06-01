//
//  ServerProviderRuntimeAdapterReadiness.swift
//  kAir
//
//  Value-only readiness matrix for future server-side provider adapters.
//

import Foundation

enum ServerProviderRuntimeAdapterReadinessState: String, Codable, Hashable, Sendable, CaseIterable {
    case localNoServerAdapter
    case missingRequiredGates
    case readyForServerAdapter
}

enum ServerProviderRuntimeAdapterReadinessGate: String, Codable, Hashable, Sendable, CaseIterable {
    case serverMediation
    case paidAccessGate
    case includedQuotaGate
    case regionPolicy
    case privacyAllowance
    case auditTrace
    case responseRedaction
    case iosBundleFree
    case sourceAttribution
    case freshCitation
    case sourceAllowlist
    case robotsAllow
    case rateLimit
    case pageRedaction
    case experimentalEnablement
    case toolResourceAllowlist
    case humanReview
    case oauthIsolation
    case sandbox
    case injectionReview
}

struct ServerProviderRuntimeAdapterReadinessReport: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let providerFamily: ProviderFamily
    let state: ServerProviderRuntimeAdapterReadinessState
    let descriptorID: String?
    let displayName: String
    let supportedCapabilities: Set<ProviderCapability>
    let requiredMembershipTier: MembershipTier
    let costClass: ProviderCostClass
    let requiresServerSideAdapter: Bool
    let requiredGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    let satisfiedGates: Set<ServerProviderRuntimeAdapterReadinessGate>
    let missingGates: Set<ServerProviderRuntimeAdapterReadinessGate>

    var isReadyForServerAdapter: Bool {
        state == .readyForServerAdapter
    }
}

enum ServerProviderRuntimeAdapterReadinessMatrix {
    static func reports(
        satisfiedGatesByProviderFamily: [ProviderFamily: Set<ServerProviderRuntimeAdapterReadinessGate>] = [:]
    ) -> [ServerProviderRuntimeAdapterReadinessReport] {
        ProviderFamily.allCases.map { family in
            report(
                for: family,
                satisfiedGates: satisfiedGatesByProviderFamily[family] ?? []
            )
        }
    }

    static func report(
        for providerFamily: ProviderFamily,
        satisfiedGates: Set<ServerProviderRuntimeAdapterReadinessGate> = []
    ) -> ServerProviderRuntimeAdapterReadinessReport {
        let runtimeDescriptor = runtimeDescriptor(for: providerFamily)
        let mapDescriptor = mapDescriptor(for: providerFamily)
        let requiresServerSideAdapter = providerFamily.isRemote
        let requiredGates = requiredGates(
            for: providerFamily,
            runtimeDescriptor: runtimeDescriptor
        )
        let acceptedSatisfiedGates = satisfiedGates.intersection(requiredGates)
        let missingGates = requiredGates.subtracting(acceptedSatisfiedGates)
        let state: ServerProviderRuntimeAdapterReadinessState
        if requiresServerSideAdapter == false {
            state = .localNoServerAdapter
        } else if missingGates.isEmpty {
            state = .readyForServerAdapter
        } else {
            state = .missingRequiredGates
        }

        return ServerProviderRuntimeAdapterReadinessReport(
            id: "provider-runtime-adapter-readiness-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            state: state,
            descriptorID: runtimeDescriptor?.id,
            displayName: runtimeDescriptor?.displayName
                ?? mapDescriptor?.displayName
                ?? providerFamily.rawValue,
            supportedCapabilities: runtimeDescriptor?.supportedCapabilities
                ?? mapDescriptor?.supportedCapabilities
                ?? [],
            requiredMembershipTier: runtimeDescriptor?.requiredMembershipTier
                ?? mapDescriptor?.minimumMembership
                ?? .free,
            costClass: runtimeDescriptor?.costClass
                ?? mapDescriptor?.costClass
                ?? .freeLocal,
            requiresServerSideAdapter: requiresServerSideAdapter,
            requiredGates: requiredGates,
            satisfiedGates: acceptedSatisfiedGates,
            missingGates: missingGates
        )
    }

    private static func requiredGates(
        for providerFamily: ProviderFamily,
        runtimeDescriptor: ServerProviderRuntimeDescriptor?
    ) -> Set<ServerProviderRuntimeAdapterReadinessGate> {
        guard providerFamily.isRemote else {
            return []
        }

        var gates = baseRemoteGates()
        if runtimeDescriptor?.requiresSourcePolicy == true {
            gates.insert(.sourceAttribution)
        }
        if runtimeDescriptor?.requiresRobotsAllow == true {
            gates.insert(.robotsAllow)
        }
        if runtimeDescriptor?.requiresConfirmation == true {
            gates.insert(.humanReview)
        }
        if runtimeDescriptor?.requiresExperimentalEnablement == true {
            gates.insert(.experimentalEnablement)
        }

        switch providerFamily {
        case .googleMaps:
            gates.formUnion([.paidAccessGate, .regionPolicy])
        case .gaode:
            gates.formUnion([.includedQuotaGate, .regionPolicy])
        case .searchAPI:
            gates.formUnion([.paidAccessGate, .freshCitation])
        case .crawler:
            gates.formUnion([.paidAccessGate, .sourceAllowlist, .rateLimit, .pageRedaction])
        case .mcp:
            gates.formUnion([
                .includedQuotaGate,
                .toolResourceAllowlist,
                .oauthIsolation,
                .sandbox,
                .injectionReview,
            ])
        case .appleLocal, .cache:
            break
        }

        return gates
    }

    private static func baseRemoteGates() -> Set<ServerProviderRuntimeAdapterReadinessGate> {
        [
            .serverMediation,
            .privacyAllowance,
            .auditTrace,
            .responseRedaction,
            .iosBundleFree,
        ]
    }

    private static func runtimeDescriptor(
        for providerFamily: ProviderFamily
    ) -> ServerProviderRuntimeDescriptor? {
        ServerProviderRuntimeRegistry.descriptors.first {
            $0.providerFamily == providerFamily
        }
    }

    private static func mapDescriptor(
        for providerFamily: ProviderFamily
    ) -> MapProviderDescriptor? {
        MapProviderDescriptor.defaultRegistry.first {
            $0.family == providerFamily
        }
    }
}
