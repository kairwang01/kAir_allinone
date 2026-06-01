//
//  ServerProviderRuntimeAdapterManifestSetValidation.swift
//  kAir
//
//  Value-only manifest-backed validation for already-created adapter sets.
//

import Foundation

enum ServerProviderRuntimeAdapterManifestSetValidationState: String, Codable, Hashable, Sendable, CaseIterable {
    case accepted
    case rejected
}

enum ServerProviderRuntimeAdapterManifestSetValidationRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case missingManifestInstallationDecision
    case localNoServerAdapter
    case manifestInstallationRejected
    case manifestInstallationFamilyMismatch
    case missingInstallationDecision
    case readinessValidationRejected
}

struct ServerProviderRuntimeAdapterManifestSetValidationRejection:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let id: String
    let providerFamily: ProviderFamily
    let reason: ServerProviderRuntimeAdapterManifestSetValidationRejectionReason
    let manifestDecisionID: String?
    let manifestDecisionProviderFamily: ProviderFamily?
    let manifestDecisionState: ServerProviderRuntimeAdapterManifestInstallationState?
    let manifestDecisionRejection: ServerProviderRuntimeAdapterManifestInstallationRejection?
    let installationDecisionID: String?
    let installationDecisionProviderFamily: ProviderFamily?
    let installationDecisionState: ServerProviderRuntimeAdapterInstallationState?
    let installationDecisionRejection: ServerProviderRuntimeAdapterInstallationRejection?
}

struct ServerProviderRuntimeAdapterManifestSetValidation:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderRuntimeAdapterManifestSetValidationState
    let registeredProviderFamilies: [ProviderFamily]
    let acceptedProviderFamilies: [ProviderFamily]
    let rejectedProviderFamilies: [ServerProviderRuntimeAdapterManifestSetValidationRejection]
    let readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?

    var isAccepted: Bool {
        state == .accepted
    }

    var statusLine: String {
        switch state {
        case .accepted:
            return "Manifest-backed adapter set validation is accepted. Metadata only; no provider runtime has run."
        case .rejected:
            return "Manifest-backed adapter set validation is rejected. Metadata only; no provider runtime has run."
        }
    }

    var description: String {
        "ServerProviderRuntimeAdapterManifestSetValidation(id: \(id), state: \(state.rawValue), registered: \(registeredProviderFamilies.map(\.rawValue)))"
    }
}

enum ServerProviderRuntimeAdapterManifestSetValidator {
    static func validate(
        _ adapterSet: ServerProviderRuntimeAdapterSet,
        decisionsByProviderFamily: [ProviderFamily: ServerProviderRuntimeAdapterManifestInstallationDecision]
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        let registeredFamilies = orderedFamilies(adapterSet.registeredProviderFamilies)
        var acceptedFamilies: [ProviderFamily] = []
        var rejectedFamilies: [ServerProviderRuntimeAdapterManifestSetValidationRejection] = []
        var installationDecisions: [ProviderFamily: ServerProviderRuntimeAdapterInstallationDecision] = [:]

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
                        reason: .missingManifestInstallationDecision,
                        decision: nil
                    )
                )
                continue
            }

            guard decision.providerFamily == family else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .manifestInstallationFamilyMismatch,
                        decision: decision
                    )
                )
                continue
            }

            guard decision.state == .installable else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .manifestInstallationRejected,
                        decision: decision
                    )
                )
                continue
            }

            guard let installationDecision = decision.installationDecision else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .missingInstallationDecision,
                        decision: decision
                    )
                )
                continue
            }

            guard installationDecision.isInstallable else {
                rejectedFamilies.append(
                    rejection(
                        providerFamily: family,
                        reason: .manifestInstallationRejected,
                        decision: decision
                    )
                )
                continue
            }

            acceptedFamilies.append(family)
            installationDecisions[family] = installationDecision
        }

        guard rejectedFamilies.isEmpty else {
            return validation(
                state: .rejected,
                registeredFamilies: registeredFamilies,
                acceptedFamilies: acceptedFamilies,
                rejectedFamilies: rejectedFamilies,
                readinessValidation: nil
            )
        }

        let readinessValidation = ServerProviderRuntimeAdapterSetReadinessValidator.validate(
            adapterSet,
            decisionsByProviderFamily: installationDecisions
        )

        guard readinessValidation.isAccepted else {
            return validation(
                state: .rejected,
                registeredFamilies: readinessValidation.registeredProviderFamilies,
                acceptedFamilies: readinessValidation.acceptedProviderFamilies,
                rejectedFamilies: readinessValidation.rejectedProviderFamilies.map { rejection in
                    ServerProviderRuntimeAdapterManifestSetValidationRejection(
                        id: "provider-runtime-adapter-manifest-set-\(rejection.providerFamily.rawValue)",
                        providerFamily: rejection.providerFamily,
                        reason: .readinessValidationRejected,
                        manifestDecisionID: decisionsByProviderFamily[rejection.providerFamily]?.id,
                        manifestDecisionProviderFamily: decisionsByProviderFamily[rejection.providerFamily]?.providerFamily,
                        manifestDecisionState: decisionsByProviderFamily[rejection.providerFamily]?.state,
                        manifestDecisionRejection: decisionsByProviderFamily[rejection.providerFamily]?.rejection,
                        installationDecisionID: rejection.decisionID,
                        installationDecisionProviderFamily: rejection.decisionProviderFamily,
                        installationDecisionState: rejection.decisionState,
                        installationDecisionRejection: rejection.decisionRejection
                    )
                },
                readinessValidation: readinessValidation
            )
        }

        return validation(
            state: .accepted,
            registeredFamilies: readinessValidation.registeredProviderFamilies,
            acceptedFamilies: readinessValidation.acceptedProviderFamilies,
            rejectedFamilies: [],
            readinessValidation: readinessValidation
        )
    }

    private static func orderedFamilies(_ families: Set<ProviderFamily>) -> [ProviderFamily] {
        ProviderFamily.allCases.filter { families.contains($0) }
    }

    private static func validation(
        state: ServerProviderRuntimeAdapterManifestSetValidationState,
        registeredFamilies: [ProviderFamily],
        acceptedFamilies: [ProviderFamily],
        rejectedFamilies: [ServerProviderRuntimeAdapterManifestSetValidationRejection],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "provider-runtime-adapter-manifest-set-validation",
            state: state,
            registeredProviderFamilies: registeredFamilies,
            acceptedProviderFamilies: acceptedFamilies,
            rejectedProviderFamilies: rejectedFamilies,
            readinessValidation: readinessValidation
        )
    }

    private static func rejection(
        providerFamily: ProviderFamily,
        reason: ServerProviderRuntimeAdapterManifestSetValidationRejectionReason,
        decision: ServerProviderRuntimeAdapterManifestInstallationDecision?
    ) -> ServerProviderRuntimeAdapterManifestSetValidationRejection {
        ServerProviderRuntimeAdapterManifestSetValidationRejection(
            id: "provider-runtime-adapter-manifest-set-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            reason: reason,
            manifestDecisionID: decision?.id,
            manifestDecisionProviderFamily: decision?.providerFamily,
            manifestDecisionState: decision?.state,
            manifestDecisionRejection: decision?.rejection,
            installationDecisionID: decision?.installationDecision?.id,
            installationDecisionProviderFamily: decision?.installationDecision?.providerFamily,
            installationDecisionState: decision?.installationDecision?.state,
            installationDecisionRejection: decision?.installationDecision?.rejection
        )
    }
}
