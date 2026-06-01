//
//  ServerProviderRuntimeInvocationPlan.swift
//  kAir
//
//  Pure A18 invocation-plan contract for future server-provider runtimes.
//  This file stores plan metadata only and never invokes providers.
//

import Foundation

enum ServerProviderRuntimeInvocationPlanState: String, Codable, Hashable, Sendable, CaseIterable {
    case planned
    case localOnly
    case confirmationRequired
    case blocked
    case descriptorUnavailable
}

struct ServerProviderRuntimeInvocationAudit: Codable, Hashable, Sendable {
    let readinessID: String
    let lookupID: String
    let readinessState: ServerProviderExecutionReadinessState
    let lookupState: ServerProviderRuntimeLookupState
    let factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    let validatorDenialReason: ServerProviderDenialReason?
}

struct ServerProviderRuntimeInvocationPlan: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeInvocationPlanState
    let statusLine: String
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let sourcePolicy: ServerSourcePolicy?
    let confirmationState: ServerConfirmationState?
    let descriptorID: String?
    let audit: ServerProviderRuntimeInvocationAudit

    var isPlanned: Bool {
        state == .planned && descriptorID != nil
    }
}

enum ServerProviderRuntimeInvocationPlanner {
    nonisolated static func makePlan(
        readinessDecision: ServerProviderExecutionReadinessDecision
    ) -> ServerProviderRuntimeInvocationPlan {
        makePlan(
            readinessDecision: readinessDecision,
            runtimeLookup: ServerProviderRuntimeRegistry.lookup(for: readinessDecision)
        )
    }

    nonisolated static func makePlan(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult
    ) -> ServerProviderRuntimeInvocationPlan {
        let state = planState(
            readinessDecision: readinessDecision,
            runtimeLookup: runtimeLookup
        )
        let descriptor = state == .planned ? runtimeLookup.descriptor : nil

        return ServerProviderRuntimeInvocationPlan(
            id: "server-provider-invocation-\(readinessDecision.id)",
            state: state,
            statusLine: statusLine(
                state: state,
                descriptor: descriptor,
                readinessDecision: readinessDecision,
                runtimeLookup: runtimeLookup
            ),
            traceID: traceID(from: readinessDecision),
            providerFamily: readinessDecision.providerFamily,
            capability: readinessDecision.capability,
            costClass: readinessDecision.costClass,
            freshness: readinessDecision.freshness,
            sourcePolicy: readinessDecision.sourcePolicy,
            confirmationState: readinessDecision.confirmationState,
            descriptorID: descriptor?.id,
            audit: ServerProviderRuntimeInvocationAudit(
                readinessID: readinessDecision.id,
                lookupID: runtimeLookup.id,
                readinessState: readinessDecision.state,
                lookupState: runtimeLookup.state,
                factoryRejectionReason: readinessDecision.factoryRejectionReason,
                validatorDenialReason: readinessDecision.validatorDenialReason
            )
        )
    }

    nonisolated private static func planState(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult
    ) -> ServerProviderRuntimeInvocationPlanState {
        switch readinessDecision.state {
        case .localOnly:
            return .localOnly
        case .confirmationRequired:
            return .confirmationRequired
        case .blocked:
            return .blocked
        case .serverReady:
            return descriptorMatchesReadiness(
                readinessDecision: readinessDecision,
                runtimeLookup: runtimeLookup
            ) ? .planned : .descriptorUnavailable
        }
    }

    nonisolated private static func descriptorMatchesReadiness(
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult
    ) -> Bool {
        guard runtimeLookup.readinessDecision.id == readinessDecision.id,
              runtimeLookup.state == .descriptorAvailable,
              let descriptor = runtimeLookup.descriptor,
              descriptor.providerFamily == readinessDecision.providerFamily,
              let capability = readinessDecision.capability,
              descriptor.supportedCapabilities.contains(capability) else {
            return false
        }
        return true
    }

    nonisolated private static func traceID(
        from readinessDecision: ServerProviderExecutionReadinessDecision
    ) -> String? {
        readinessDecision.sendReadyEnvelope?.traceID
            ?? readinessDecision.audit?.trace.traceID
            ?? readinessDecision.validation?.audit.trace.traceID
    }

    nonisolated private static func statusLine(
        state: ServerProviderRuntimeInvocationPlanState,
        descriptor: ServerProviderRuntimeDescriptor?,
        readinessDecision: ServerProviderExecutionReadinessDecision,
        runtimeLookup: ServerProviderRuntimeLookupResult
    ) -> String {
        switch state {
        case .planned:
            return "\(descriptor?.displayName ?? "Provider") invocation plan is available as metadata only. No provider runtime has run."
        case .localOnly:
            return "Local-only readiness has no server invocation plan. \(readinessDecision.statusLine)"
        case .confirmationRequired:
            return "Invocation plan is withheld until confirmation is satisfied. \(readinessDecision.statusLine)"
        case .blocked:
            return "Invocation plan is unavailable because readiness is blocked. \(readinessDecision.statusLine)"
        case .descriptorUnavailable:
            return "Invocation plan is unavailable because runtime descriptor lookup did not match readiness. \(runtimeLookup.statusLine)"
        }
    }
}
