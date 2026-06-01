//
//  ServerProviderRuntimeAdapter.swift
//  kAir
//
//  Pure A20 adapter protocol/result contract for future provider adapters.
//  This file returns fixture metadata only and never invokes providers.
//

import Foundation

enum ServerProviderRuntimeAdapterResultState: String, Codable, Hashable, Sendable, CaseIterable {
    case acceptedFixture
    case notPrepared
    case localOnly
    case confirmationRequired
    case blocked
    case descriptorUnavailable
    case planRejected
}

enum ServerProviderRuntimeAdapterRejectionReason: String, Codable, Hashable, Sendable, CaseIterable {
    case boundaryNotPrepared
    case missingBoundaryID
    case missingPlanID
    case missingTraceID
    case missingProviderFamily
    case missingCapability
    case missingDescriptorID
    case unregisteredProvider
    case providerMismatch
    case adapterSetUseNotAuthorized
}

struct ServerProviderRuntimeAdapterAudit: Codable, Hashable, Sendable {
    let boundaryID: String
    let boundaryState: ServerProviderRuntimeDispatchState
    let planID: String
    let planState: ServerProviderRuntimeInvocationPlanState
    let readinessID: String
    let lookupID: String
    let readinessState: ServerProviderExecutionReadinessState
    let lookupState: ServerProviderRuntimeLookupState
    let dispatchRejectionReason: ServerProviderRuntimeDispatchRejectionReason?
    let adapterRejectionReason: ServerProviderRuntimeAdapterRejectionReason?
    let factoryRejectionReason: ServerProviderEnvelopeFactoryRejectionReason?
    let validatorDenialReason: ServerProviderDenialReason?
}

struct ServerProviderRuntimeAdapterResult: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeAdapterResultState
    let statusLine: String
    let boundaryID: String
    let planID: String
    let traceID: String?
    let providerFamily: ProviderFamily?
    let capability: ProviderCapability?
    let descriptorID: String?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness?
    let sourcePolicy: ServerSourcePolicy?
    let confirmationState: ServerConfirmationState?
    let audit: ServerProviderRuntimeAdapterAudit

    nonisolated var isAcceptedFixture: Bool {
        state == .acceptedFixture
            && traceID != nil
            && providerFamily != nil
            && capability != nil
            && descriptorID != nil
    }
}

protocol ServerProviderRuntimeAdapter: Sendable {
    var providerFamily: ProviderFamily { get }

    nonisolated func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult
}

struct FixtureServerProviderRuntimeAdapter: ServerProviderRuntimeAdapter {
    let providerFamily: ProviderFamily

    nonisolated init(providerFamily: ProviderFamily) {
        self.providerFamily = providerFamily
    }

    nonisolated func resolve(
        _ boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterResult {
        let rejection = rejectionReason(for: boundary)
        let state = resultState(for: boundary, rejection: rejection)
        let accepted = state == .acceptedFixture
        return ServerProviderRuntimeAdapterResult(
            id: "server-provider-adapter-\(safeID(boundary.id))",
            state: state,
            statusLine: statusLine(
                state: state,
                boundary: boundary,
                rejection: rejection
            ),
            boundaryID: boundary.id,
            planID: boundary.planID,
            traceID: accepted ? boundary.traceID : nil,
            providerFamily: accepted ? boundary.providerFamily : nil,
            capability: accepted ? boundary.capability : nil,
            descriptorID: accepted ? boundary.descriptorID : nil,
            costClass: accepted ? boundary.costClass : nil,
            freshness: accepted ? boundary.freshness : nil,
            sourcePolicy: accepted ? boundary.sourcePolicy : nil,
            confirmationState: accepted ? boundary.confirmationState : nil,
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
                adapterRejectionReason: rejection,
                factoryRejectionReason: boundary.audit.factoryRejectionReason,
                validatorDenialReason: boundary.audit.validatorDenialReason
            )
        )
    }

    nonisolated private func resultState(
        for boundary: ServerProviderRuntimeDispatchBoundary,
        rejection: ServerProviderRuntimeAdapterRejectionReason?
    ) -> ServerProviderRuntimeAdapterResultState {
        guard rejection == nil else {
            if rejection == .boundaryNotPrepared {
                return preservedState(for: boundary.state)
            }
            return .notPrepared
        }
        return .acceptedFixture
    }

    nonisolated private func preservedState(
        for boundaryState: ServerProviderRuntimeDispatchState
    ) -> ServerProviderRuntimeAdapterResultState {
        switch boundaryState {
        case .prepared:
            return .notPrepared
        case .localOnly:
            return .localOnly
        case .confirmationRequired:
            return .confirmationRequired
        case .blocked:
            return .blocked
        case .descriptorUnavailable:
            return .descriptorUnavailable
        case .planRejected:
            return .planRejected
        }
    }

    nonisolated private func rejectionReason(
        for boundary: ServerProviderRuntimeDispatchBoundary
    ) -> ServerProviderRuntimeAdapterRejectionReason? {
        guard boundary.state == .prepared else {
            return .boundaryNotPrepared
        }
        guard boundary.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingBoundaryID
        }
        guard boundary.planID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingPlanID
        }
        guard let traceID = boundary.traceID,
              traceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingTraceID
        }
        guard let family = boundary.providerFamily else {
            return .missingProviderFamily
        }
        guard boundary.capability != nil else {
            return .missingCapability
        }
        guard let descriptorID = boundary.descriptorID,
              descriptorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .missingDescriptorID
        }
        guard family == providerFamily else {
            return .providerMismatch
        }
        return nil
    }

    nonisolated private func statusLine(
        state: ServerProviderRuntimeAdapterResultState,
        boundary: ServerProviderRuntimeDispatchBoundary,
        rejection: ServerProviderRuntimeAdapterRejectionReason?
    ) -> String {
        switch state {
        case .acceptedFixture:
            return "Fixture adapter accepted prepared metadata only. No provider runtime has run."
        case .notPrepared:
            return "Adapter result is unavailable because dispatch metadata is invalid: \(rejectionLabel(rejection))."
        case .localOnly:
            return "Local-only boundary has no server adapter result. \(boundary.statusLine)"
        case .confirmationRequired:
            return "Adapter result is withheld until confirmation is satisfied. \(boundary.statusLine)"
        case .blocked:
            return "Adapter result is unavailable because boundary is blocked. \(boundary.statusLine)"
        case .descriptorUnavailable:
            return "Adapter result is unavailable because descriptor metadata is unavailable. \(boundary.statusLine)"
        case .planRejected:
            return "Adapter result is unavailable because plan metadata was rejected. \(boundary.statusLine)"
        }
    }

    nonisolated private func rejectionLabel(
        _ rejection: ServerProviderRuntimeAdapterRejectionReason?
    ) -> String {
        switch rejection {
        case .boundaryNotPrepared:
            return "boundary is not prepared"
        case .missingBoundaryID:
            return "boundary id is missing"
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
        case .unregisteredProvider:
            return "provider family is not registered"
        case .providerMismatch:
            return "provider family does not match adapter"
        case .adapterSetUseNotAuthorized:
            return "adapter set use is not authorized"
        case .none:
            return "unknown validation failure"
        }
    }

    nonisolated private func safeID(_ value: String) -> String {
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
