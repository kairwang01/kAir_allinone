//
//  ServerProviderRuntimePipeline.swift
//  kAir
//
//  Pure A42 orchestration for future server-provider runtimes.
//  This file composes existing metadata gates only and never calls transport.
//

import Foundation

enum ServerProviderRuntimePipeline {
    nonisolated static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision
    ) -> ServerProviderRuntimeReceipt {
        run(
            readinessDecision: readinessDecision,
            runtimeLookup: ServerProviderRuntimeRegistry.lookup(for: readinessDecision)
        )
    }

    static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        adapterSet: ServerProviderRuntimeAdapterSet
    ) -> ServerProviderRuntimeReceipt {
        run(
            readinessDecision: readinessDecision,
            runtimeLookup: ServerProviderRuntimeRegistry.lookup(for: readinessDecision),
            adapterSet: adapterSet
        )
    }

    static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        adapterSet: ServerProviderRuntimeAdapterSet,
        validation: ServerProviderRuntimeAdapterSetReadinessValidation
    ) -> ServerProviderRuntimeReceipt {
        run(
            readinessDecision: readinessDecision,
            runtimeLookup: ServerProviderRuntimeRegistry.lookup(for: readinessDecision),
            adapterSet: adapterSet,
            validation: validation
        )
    }

    static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        adapterSet: ServerProviderRuntimeAdapterSet,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    ) -> ServerProviderRuntimeReceipt {
        run(
            readinessDecision: readinessDecision,
            runtimeLookup: ServerProviderRuntimeRegistry.lookup(for: readinessDecision),
            adapterSet: adapterSet,
            authorization: authorization
        )
    }

    nonisolated static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult
    ) -> ServerProviderRuntimeReceipt {
        run(
            invocationPlan: ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readinessDecision,
                runtimeLookup: runtimeLookup
            )
        )
    }

    static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult,
        adapterSet: ServerProviderRuntimeAdapterSet
    ) -> ServerProviderRuntimeReceipt {
        run(
            invocationPlan: ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readinessDecision,
                runtimeLookup: runtimeLookup
            ),
            adapterSet: adapterSet
        )
    }

    static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult,
        adapterSet: ServerProviderRuntimeAdapterSet,
        validation: ServerProviderRuntimeAdapterSetReadinessValidation
    ) -> ServerProviderRuntimeReceipt {
        run(
            invocationPlan: ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readinessDecision,
                runtimeLookup: runtimeLookup
            ),
            adapterSet: adapterSet,
            validation: validation
        )
    }

    static func run(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult,
        adapterSet: ServerProviderRuntimeAdapterSet,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    ) -> ServerProviderRuntimeReceipt {
        run(
            invocationPlan: ServerProviderRuntimeInvocationPlanner.makePlan(
                readinessDecision: readinessDecision,
                runtimeLookup: runtimeLookup
            ),
            adapterSet: adapterSet,
            authorization: authorization
        )
    }

    nonisolated static func run(
        invocationPlan: ServerProviderRuntimeInvocationPlan
    ) -> ServerProviderRuntimeReceipt {
        let boundary = ServerProviderRuntimeDispatcher.prepare(invocationPlan)
        let adapterResult = ServerProviderRuntimeAdapterRegistry.resolve(boundary)
        return ServerProviderRuntimeReceiptProjector.project(adapterResult)
    }

    static func run(
        invocationPlan: ServerProviderRuntimeInvocationPlan,
        adapterSet: ServerProviderRuntimeAdapterSet
    ) -> ServerProviderRuntimeReceipt {
        let boundary = ServerProviderRuntimeDispatcher.prepare(invocationPlan)
        let adapterResult = adapterSet.resolve(boundary)
        return ServerProviderRuntimeReceiptProjector.project(adapterResult)
    }

    static func run(
        invocationPlan: ServerProviderRuntimeInvocationPlan,
        adapterSet: ServerProviderRuntimeAdapterSet,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    ) -> ServerProviderRuntimeReceipt {
        let boundary = ServerProviderRuntimeDispatcher.prepare(invocationPlan)
        guard let adapterResult = manifestBackedAdapterResult(
            boundary: boundary,
            authorization: authorization
        ) else {
            let adapterResult = adapterSet.resolve(boundary)
            return ServerProviderRuntimeReceiptProjector.project(adapterResult)
        }

        return ServerProviderRuntimeReceiptProjector.project(adapterResult)
    }

    static func run(
        invocationPlan: ServerProviderRuntimeInvocationPlan,
        adapterSet: ServerProviderRuntimeAdapterSet,
        validation: ServerProviderRuntimeAdapterSetReadinessValidation
    ) -> ServerProviderRuntimeReceipt {
        let boundary = ServerProviderRuntimeDispatcher.prepare(invocationPlan)
        let authorization = ServerProviderRuntimeAdapterSetUseGate.authorize(
            requestedProviderFamily: boundary.providerFamily,
            validation: validation
        )
        guard authorization.isAuthorized else {
            return ServerProviderRuntimeReceiptProjector.project(
                unauthorizedAdapterResult(
                    boundary: boundary,
                    authorization: authorization
                )
            )
        }

        let adapterResult = adapterSet.resolve(boundary)
        return ServerProviderRuntimeReceiptProjector.project(adapterResult)
    }

    private static func manifestBackedAdapterResult(
        boundary: ServerProviderRuntimeDispatchBoundary,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    ) -> ServerProviderRuntimeAdapterResult? {
        guard let requestedFamily = boundary.providerFamily else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .missingRequestedProviderFamily,
                authorization: authorization
            )
        }

        guard requestedFamily.isRemote else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .localNoServerAdapter,
                authorization: authorization
            )
        }

        guard authorization.requestedProviderFamily == requestedFamily else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .requestedProviderFamilyMismatch,
                authorization: authorization
            )
        }

        guard authorization.state == .authorized else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .manifestAuthorizationRejected,
                authorization: authorization
            )
        }

        guard let readinessAuthorization = authorization.readinessAuthorization else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .missingReadinessAuthorization,
                authorization: authorization
            )
        }

        guard readinessAuthorization.requestedProviderFamily == requestedFamily else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .requestedProviderFamilyMismatch,
                authorization: authorization
            )
        }

        guard readinessAuthorization.isAuthorized else {
            return unauthorizedManifestAdapterResult(
                boundary: boundary,
                reason: .readinessAuthorizationRejected,
                authorization: authorization
            )
        }

        return nil
    }

    private static func unauthorizedManifestAdapterResult(
        boundary: ServerProviderRuntimeDispatchBoundary,
        reason: ManifestBackedAdapterSetPipelineRejection,
        authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    ) -> ServerProviderRuntimeAdapterResult {
        ServerProviderRuntimeAdapterResult(
            id: "server-provider-manifest-adapter-set-use-\(safeID(boundary.id))",
            state: .notPrepared,
            statusLine: "Manifest-backed injected adapter set use is not authorized: \(reason.rawValue). A76=\(authorization.rejection?.rawValue ?? authorization.state.rawValue); A69=\(authorization.readinessAuthorizationRejection?.rawValue ?? authorization.readinessAuthorizationState?.rawValue ?? "missing").",
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
                adapterRejectionReason: .adapterSetUseNotAuthorized,
                factoryRejectionReason: boundary.audit.factoryRejectionReason,
                validatorDenialReason: boundary.audit.validatorDenialReason
            )
        )
    }

    private static func unauthorizedAdapterResult(
        boundary: ServerProviderRuntimeDispatchBoundary,
        authorization: ServerProviderRuntimeAdapterSetUseAuthorization
    ) -> ServerProviderRuntimeAdapterResult {
        ServerProviderRuntimeAdapterResult(
            id: "server-provider-adapter-set-use-\(safeID(boundary.id))",
            state: .notPrepared,
            statusLine: "Injected adapter set use is not authorized: \(authorization.rejection?.rawValue ?? "unknown").",
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
                adapterRejectionReason: .adapterSetUseNotAuthorized,
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

private enum ManifestBackedAdapterSetPipelineRejection: String {
    case missingRequestedProviderFamily
    case localNoServerAdapter
    case manifestAuthorizationRejected
    case requestedProviderFamilyMismatch
    case missingReadinessAuthorization
    case readinessAuthorizationRejected
}
