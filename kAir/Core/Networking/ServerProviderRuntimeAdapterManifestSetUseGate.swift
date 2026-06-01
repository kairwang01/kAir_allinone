//
//  ServerProviderRuntimeAdapterManifestSetUseGate.swift
//  kAir
//
//  Value-only manifest-backed authorization for future adapter-set use.
//

import Foundation

enum ServerProviderRuntimeAdapterManifestSetUseAuthorizationState: String, Codable, Hashable, Sendable, CaseIterable {
    case authorized
    case rejected
}

enum ServerProviderRuntimeAdapterManifestSetUseRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case missingRequestedProviderFamily
    case localNoServerAdapter
    case manifestValidationRejected
    case providerFamilyNotAccepted
    case missingReadinessValidation
    case readinessAuthorizationRejected
}

struct ServerProviderRuntimeAdapterManifestSetUseAuthorization:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let state: ServerProviderRuntimeAdapterManifestSetUseAuthorizationState
    let requestedProviderFamily: ProviderFamily?
    let rejection: ServerProviderRuntimeAdapterManifestSetUseRejectionReason?
    let manifestValidationID: String
    let manifestValidationState: ServerProviderRuntimeAdapterManifestSetValidationState
    let manifestAcceptedProviderFamilies: [ProviderFamily]
    let readinessValidationID: String?
    let readinessValidationState: ServerProviderRuntimeAdapterSetReadinessValidationState?
    let readinessAuthorization: ServerProviderRuntimeAdapterSetUseAuthorization?
    let readinessAuthorizationState: ServerProviderRuntimeAdapterSetUseAuthorizationState?
    let readinessAuthorizationRejection: ServerProviderRuntimeAdapterSetUseRejectionReason?

    var isAuthorized: Bool {
        state == .authorized
            && readinessAuthorization?.isAuthorized == true
    }

    var statusLine: String {
        switch state {
        case .authorized:
            return "Manifest-backed adapter set use is authorized for \(requestedProviderFamily?.rawValue ?? "missing"). Metadata only; no provider runtime has run."
        case .rejected:
            return "Manifest-backed adapter set use is rejected for \(requestedProviderFamily?.rawValue ?? "missing"): \(rejection?.rawValue ?? "unknown"). Metadata only; no provider runtime has run."
        }
    }

    var description: String {
        "ServerProviderRuntimeAdapterManifestSetUseAuthorization(id: \(id), state: \(state.rawValue), requestedProviderFamily: \(requestedProviderFamily?.rawValue ?? "missing"), rejection: \(rejection?.rawValue ?? "none"))"
    }
}

enum ServerProviderRuntimeAdapterManifestSetUseGate {
    static func authorize(
        requestedProviderFamily: ProviderFamily?,
        validation: ServerProviderRuntimeAdapterManifestSetValidation
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        guard let family = requestedProviderFamily else {
            return rejected(
                requestedProviderFamily: nil,
                validation: validation,
                readinessAuthorization: nil,
                rejection: .missingRequestedProviderFamily
            )
        }

        guard family.isRemote else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                readinessAuthorization: nil,
                rejection: .localNoServerAdapter
            )
        }

        guard validation.isAccepted else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                readinessAuthorization: nil,
                rejection: .manifestValidationRejected
            )
        }

        guard validation.acceptedProviderFamilies.contains(family) else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                readinessAuthorization: nil,
                rejection: .providerFamilyNotAccepted
            )
        }

        guard let readinessValidation = validation.readinessValidation else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                readinessAuthorization: nil,
                rejection: .missingReadinessValidation
            )
        }

        let readinessAuthorization = ServerProviderRuntimeAdapterSetUseGate.authorize(
            requestedProviderFamily: family,
            validation: readinessValidation
        )

        guard readinessAuthorization.isAuthorized else {
            return rejected(
                requestedProviderFamily: family,
                validation: validation,
                readinessAuthorization: readinessAuthorization,
                rejection: .readinessAuthorizationRejected
            )
        }

        return ServerProviderRuntimeAdapterManifestSetUseAuthorization(
            id: authorizationID(for: family),
            state: .authorized,
            requestedProviderFamily: family,
            rejection: nil,
            manifestValidationID: validation.id,
            manifestValidationState: validation.state,
            manifestAcceptedProviderFamilies: validation.acceptedProviderFamilies,
            readinessValidationID: readinessValidation.id,
            readinessValidationState: readinessValidation.state,
            readinessAuthorization: readinessAuthorization,
            readinessAuthorizationState: readinessAuthorization.state,
            readinessAuthorizationRejection: readinessAuthorization.rejection
        )
    }

    private static func rejected(
        requestedProviderFamily: ProviderFamily?,
        validation: ServerProviderRuntimeAdapterManifestSetValidation,
        readinessAuthorization: ServerProviderRuntimeAdapterSetUseAuthorization?,
        rejection: ServerProviderRuntimeAdapterManifestSetUseRejectionReason
    ) -> ServerProviderRuntimeAdapterManifestSetUseAuthorization {
        ServerProviderRuntimeAdapterManifestSetUseAuthorization(
            id: authorizationID(for: requestedProviderFamily),
            state: .rejected,
            requestedProviderFamily: requestedProviderFamily,
            rejection: rejection,
            manifestValidationID: validation.id,
            manifestValidationState: validation.state,
            manifestAcceptedProviderFamilies: validation.acceptedProviderFamilies,
            readinessValidationID: validation.readinessValidation?.id,
            readinessValidationState: validation.readinessValidation?.state,
            readinessAuthorization: readinessAuthorization,
            readinessAuthorizationState: readinessAuthorization?.state,
            readinessAuthorizationRejection: readinessAuthorization?.rejection
        )
    }

    private static func authorizationID(for providerFamily: ProviderFamily?) -> String {
        guard let providerFamily else {
            return "provider-runtime-adapter-manifest-set-use-missing-family"
        }
        return "provider-runtime-adapter-manifest-set-use-\(providerFamily.rawValue)"
    }
}
