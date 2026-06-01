//
//  ServerProviderRuntimeAdapterSetReadinessValidation.swift
//  kAir
//
//  Value-only validation for already-created provider adapter sets.
//

import Foundation

enum ServerProviderRuntimeAdapterSetReadinessValidationState: String, Codable, Hashable, Sendable, CaseIterable {
    case accepted
    case rejected
}

enum ServerProviderRuntimeAdapterSetReadinessRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case missingInstallationDecision
    case installationDecisionRejected
    case localNoServerAdapter
    case installationDecisionFamilyMismatch
}

struct ServerProviderRuntimeAdapterSetReadinessRejection: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let providerFamily: ProviderFamily
    let reason: ServerProviderRuntimeAdapterSetReadinessRejectionReason
    let decisionID: String?
    let decisionProviderFamily: ProviderFamily?
    let decisionState: ServerProviderRuntimeAdapterInstallationState?
    let decisionRejection: ServerProviderRuntimeAdapterInstallationRejection?
}

struct ServerProviderRuntimeAdapterSetReadinessValidation: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeAdapterSetReadinessValidationState
    let registeredProviderFamilies: [ProviderFamily]
    let acceptedProviderFamilies: [ProviderFamily]
    let rejectedProviderFamilies: [ServerProviderRuntimeAdapterSetReadinessRejection]

    var isAccepted: Bool {
        state == .accepted
    }
}

enum ServerProviderRuntimeAdapterSetReadinessValidator {
    static func validate(
        _ adapterSet: ServerProviderRuntimeAdapterSet,
        decisionsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterInstallationDecision]
    ) -> ServerProviderRuntimeAdapterSetReadinessValidation {
        let registeredFamilies = orderedFamilies(adapterSet.registeredProviderFamilies)
        var acceptedFamilies: [ProviderFamily] = []
        var rejectedFamilies: [ServerProviderRuntimeAdapterSetReadinessRejection] = []

        for family in registeredFamilies {
            if family.isRemote == false {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .localNoServerAdapter,
                        decision: decisionsByProviderFamily[family]
                    )
                )
                continue
            }

            guard let decision = decisionsByProviderFamily[family] else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .missingInstallationDecision,
                        decision: nil
                    )
                )
                continue
            }

            guard decision.providerFamily == family else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .installationDecisionFamilyMismatch,
                        decision: decision
                    )
                )
                continue
            }

            guard decision.isInstallable else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .installationDecisionRejected,
                        decision: decision
                    )
                )
                continue
            }

            acceptedFamilies.append(family)
        }

        return ServerProviderRuntimeAdapterSetReadinessValidation(
            id: "provider-runtime-adapter-set-readiness-validation",
            state: rejectedFamilies.isEmpty ? .accepted : .rejected,
            registeredProviderFamilies: registeredFamilies,
            acceptedProviderFamilies: acceptedFamilies,
            rejectedProviderFamilies: rejectedFamilies
        )
    }

    private static func orderedFamilies(_ families: Set<ProviderFamily>) -> [ProviderFamily] {
        ProviderFamily.allCases.filter { families.contains($0) }
    }

    private static func rejection(
        providerFamily: ProviderFamily,
        reason: ServerProviderRuntimeAdapterSetReadinessRejectionReason,
        decision: ServerProviderRuntimeAdapterInstallationDecision?
    ) -> ServerProviderRuntimeAdapterSetReadinessRejection {
        ServerProviderRuntimeAdapterSetReadinessRejection(
            id: "provider-runtime-adapter-set-readiness-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            reason: reason,
            decisionID: decision?.id,
            decisionProviderFamily: decision?.providerFamily,
            decisionState: decision?.state,
            decisionRejection: decision?.rejection
        )
    }
}
