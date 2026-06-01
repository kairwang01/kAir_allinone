//
//  ServerProviderRuntimeAdapterSetUseGate.swift
//  kAir
//
//  Value-only authorization for future provider adapter-set use.
//

import Foundation

enum ServerProviderRuntimeAdapterSetUseAuthorizationState: String, Codable, Hashable, Sendable, CaseIterable {
    case authorized
    case rejected
}

enum ServerProviderRuntimeAdapterSetUseRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case missingRequestedProviderFamily
    case localNoServerAdapter
    case unregisteredProviderFamily
    case validationRejected
    case providerFamilyNotAccepted
}

struct ServerProviderRuntimeAdapterSetUseAuthorization: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeAdapterSetUseAuthorizationState
    let requestedProviderFamily: ProviderFamily?
    let rejection: ServerProviderRuntimeAdapterSetUseRejectionReason?
    let validationID: String
    let validationState: ServerProviderRuntimeAdapterSetReadinessValidationState
    let registeredProviderFamilies: [ProviderFamily]
    let acceptedProviderFamilies: [ProviderFamily]

    var isAuthorized: Bool {
        state == .authorized
    }
}

enum ServerProviderRuntimeAdapterSetUseGate {
    static func authorize(
        requestedProviderFamily: ProviderFamily?,
        validation: ServerProviderRuntimeAdapterSetReadinessValidation
    ) -> ServerProviderRuntimeAdapterSetUseAuthorization {
        guard let family = requestedProviderFamily else {
            return rejected(
                requestedProviderFamily: nil,
                validation: validation,
                rejection: .missingRequestedProviderFamily
            )
        }

        guard family.isRemote else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                rejection: .localNoServerAdapter
            )
        }

        guard validation.registeredProviderFamilies.contains(family) else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                rejection: .unregisteredProviderFamily
            )
        }

        guard validation.isAccepted else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                rejection: .validationRejected
            )
        }

        guard validation.acceptedProviderFamilies.contains(family) else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                rejection: .providerFamilyNotAccepted
            )
        }

        return ServerProviderRuntimeAdapterSetUseAuthorization(
            id: authorizationID(for: family),
            state: .authorized,
            requestedProviderFamily: family,
            rejection: nil,
            validationID: validation.id,
            validationState: validation.state,
            registeredProviderFamilies: validation.registeredProviderFamilies,
            acceptedProviderFamilies: validation.acceptedProviderFamilies
        )
    }

    private static func rejected(
        requestedProviderFamily: ProviderFamily?,
        validation: ServerProviderRuntimeAdapterSetReadinessValidation,
        rejection: ServerProviderRuntimeAdapterSetUseRejectionReason
    ) -> ServerProviderRuntimeAdapterSetUseAuthorization {
        ServerProviderRuntimeAdapterSetUseAuthorization(
            id: authorizationID(for: requestedProviderFamily),
            state: .rejected,
            requestedProviderFamily: requestedProviderFamily,
            rejection: rejection,
            validationID: validation.id,
            validationState: validation.state,
            registeredProviderFamilies: validation.registeredProviderFamilies,
            acceptedProviderFamilies: validation.acceptedProviderFamilies
        )
    }

    private static func authorizationID(for providerFamily: ProviderFamily?) -> String {
        guard let providerFamily else {
            return "provider-runtime-adapter-set-use-missing-family"
        }
        return "provider-runtime-adapter-set-use-\(providerFamily.rawValue)"
    }
}
