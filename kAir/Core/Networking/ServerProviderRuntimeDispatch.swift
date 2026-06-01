//
//  ServerProviderRuntimeDispatch.swift
//  kAir
//
//  Pure A19 dispatch-boundary contract for future server-provider adapters.
//  This file prepares metadata only and never dispatches provider work.
//

import Foundation

enum ServerProviderRuntimeDispatchState: String, Codable, Hashable, Sendable, CaseIterable {
    case prepared
    case localOnly
    case confirmationRequired
    case blocked
    case descriptorUnavailable
    case planRejected
}

enum ServerProviderRuntimeDispatchRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case planNotPlanned
    case missingPlanID
    case missingTraceID
    case missingProviderFamily
    case missingCapability
    case missingDescriptorID
}

struct ServerProviderRuntimeDispatchAudit: Codable, Hashable, Sendable {
    let planID: String
    let planState: ServerProviderRuntimeInvocationPlanState
    let readinessID: String
    let lookupID: String
    let readinessState: ServerProviderExecutionReadinessState
    let lookupState: ServerProviderRuntimeLookupState
    let rejectionReason: ServerProviderRuntimeDispatchRejectionReason?
    let factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    let validatorDenialReason: ServerProviderDenialReason?
}

struct ServerProviderRuntimeDispatchBoundary: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeDispatchState
    let statusLine: String
    let planID: String
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let descriptorID: String?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let sourcePolicy: ServerSourcePolicy?
    let confirmationState: ServerConfirmationState?
    let audit: ServerProviderRuntimeDispatchAudit

    var isPrepared: Bool {
        state == .prepared
            && traceID != nil
            && providerFamily != nil
            && capability != nil
            && descriptorID != nil
    }
}

enum ServerProviderRuntimeDispatcher {
    nonisolated static func prepare(
        _ plan: ServerProviderRuntimeInvocationPlan
    ) -> ServerProviderRuntimeDispatchBoundary {
        let rejection = rejectionReason(for: plan)
        let state = dispatchState(for: plan, rejection: rejection)
        return ServerProviderRuntimeDispatchBoundary(
            id: "server-provider-dispatch-\(safeID(plan.id))",
            state: state,
            statusLine: statusLine(
                state: state,
                plan: plan,
                rejection: rejection
            ),
            planID: plan.id,
            traceID: state == .prepared ? plan.traceID : nil,
            providerFamily: state == .prepared ? plan.providerFamily : nil,
            capability: state == .prepared ? plan.capability : nil,
            descriptorID: state == .prepared ? plan.descriptorID : nil,
            costClass: state == .prepared ? plan.costClass : nil,
            freshness: state == .prepared ? plan.freshness : nil,
            sourcePolicy: state == .prepared ? plan.sourcePolicy : nil,
            confirmationState: state == .prepared ? plan.confirmationState : nil,
            audit: ServerProviderRuntimeDispatchAudit(
                planID: plan.id,
                planState: plan.state,
                readinessID: plan.audit.readinessID,
                lookupID: plan.audit.lookupID,
                readinessState: plan.audit.readinessState,
                lookupState: plan.audit.lookupState,
                rejectionReason: rejection,
                factoryRejectionReason: plan.audit.factoryRejectionReason,
                validatorDenialReason: plan.audit.validatorDenialReason
            )
        )
    }

    nonisolated private static func dispatchState(
        for plan: ServerProviderRuntimeInvocationPlan,
        rejection: ServerProviderRuntimeDispatchRejectionReason?
    ) -> ServerProviderRuntimeDispatchState {
        guard rejection == nil else {
            if rejection == .planNotPlanned {
                return preservedState(for: plan.state)
            }
            return .planRejected
        }
        return .prepared
    }

    nonisolated private static func preservedState(
        for planState: ServerProviderRuntimeInvocationPlanState
    ) -> ServerProviderRuntimeDispatchState {
        switch planState {
        case .planned:
            return .planRejected
        case .localOnly:
            return .localOnly
        case .confirmationRequired:
            return .confirmationRequired
        case .blocked:
            return .blocked
        case .descriptorUnavailable:
            return .descriptorUnavailable
        }
    }

    nonisolated private static func rejectionReason(
        for plan: ServerProviderRuntimeInvocationPlan
    ) -> ServerProviderRuntimeDispatchRejectionReason? {
        guard plan.state == .planned else {
            return .planNotPlanned
        }
        guard plan.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingPlanID
        }
        guard let traceID = plan.traceID,
              traceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingTraceID
        }
        guard plan.providerFamily != nil else {
            return .missingProviderFamily
        }
        guard plan.capability != nil else {
            return .missingCapability
        }
        guard let descriptorID = plan.descriptorID,
              descriptorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingDescriptorID
        }
        return nil
    }

    nonisolated private static func statusLine(
        state: ServerProviderRuntimeDispatchState,
        plan: ServerProviderRuntimeInvocationPlan,
        rejection: ServerProviderRuntimeDispatchRejectionReason?
    ) -> String {
        switch state {
        case .prepared:
            return "Provider dispatch boundary is prepared as metadata only. No provider runtime has run."
        case .localOnly:
            return "Local-only plan has no server dispatch boundary. \(plan.statusLine)"
        case .confirmationRequired:
            return "Dispatch boundary is withheld until confirmation is satisfied. \(plan.statusLine)"
        case .blocked:
            return "Dispatch boundary is unavailable because plan is blocked. \(plan.statusLine)"
        case .descriptorUnavailable:
            return "Dispatch boundary is unavailable because descriptor metadata is unavailable. \(plan.statusLine)"
        case .planRejected:
            return "Dispatch boundary is unavailable because plan metadata is invalid: \(rejectionLabel(rejection))."
        }
    }

    nonisolated private static func rejectionLabel(
        _ rejection: ServerProviderRuntimeDispatchRejectionReason?
    ) -> String {
        switch rejection {
        case .missingPlanID:
            return "plan id is missing"
        case .missingTraceID:
            return "trace id is missing"
        case .missingProviderFamily:
            return "provider family is missing"
        case .missingCapability:
            return "capability is missing"
        case .missingDescriptorID:
            return "descriptor id is missing"
        case .planNotPlanned:
            return "plan is not planned"
        case .none:
            return "unknown validation failure"
        }
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
        return slug.isEmpty ? "missing-plan-id" : slug
    }
}
