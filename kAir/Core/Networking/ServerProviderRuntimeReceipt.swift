//
//  ServerProviderRuntimeReceipt.swift
//  kAir
//
//  Pure A22 receipt/projection contract for future provider result display.
//  This file projects adapter metadata only and never invokes providers.
//

import Foundation

enum ServerProviderRuntimeReceiptState: String, Codable, Hashable, Sendable, CaseIterable {
    case fixtureProjected
    case localOnly
    case confirmationRequired
    case blocked
    case descriptorUnavailable
    case planRejected
    case notPrepared
    case unavailable
}

struct ServerProviderRuntimeReceiptAudit: Codable, Hashable, Sendable {
    let adapterResultID: String
    let adapterResultState: ServerProviderRuntimeAdapterResultState
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

    nonisolated init(
        adapterResultID: String,
        adapterResultState: ServerProviderRuntimeAdapterResultState,
        adapterAudit: ServerProviderRuntimeAdapterAudit
    ) {
        self.adapterResultID = adapterResultID
        self.adapterResultState = adapterResultState
        self.boundaryID = adapterAudit.boundaryID
        self.boundaryState = adapterAudit.boundaryState
        self.planID = adapterAudit.planID
        self.planState = adapterAudit.planState
        self.readinessID = adapterAudit.readinessID
        self.lookupID = adapterAudit.lookupID
        self.readinessState = adapterAudit.readinessState
        self.lookupState = adapterAudit.lookupState
        self.dispatchRejectionReason = adapterAudit.dispatchRejectionReason
        self.adapterRejectionReason = adapterAudit.adapterRejectionReason
        self.factoryRejectionReason = adapterAudit.factoryRejectionReason
        self.validatorDenialReason = adapterAudit.validatorDenialReason
    }
}

struct ServerProviderRuntimeReceipt: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let state: ServerProviderRuntimeReceiptState
    let statusLine: String
    let adapterResultID: String
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
    let audit: ServerProviderRuntimeReceiptAudit

    nonisolated var isFixtureProjected: Bool {
        state == .fixtureProjected
            && traceID != nil
            && providerFamily != nil
            && capability != nil
            && descriptorID != nil
    }

    nonisolated init(
        id: String,
        state: ServerProviderRuntimeReceiptState,
        statusLine: String,
        adapterResultID: String,
        boundaryID: String,
        planID: String,
        traceID: String?,
        providerFamily: ProviderFamily?,
        capability: ProviderCapability?,
        descriptorID: String?,
        costClass: ProviderCostClass?,
        freshness: ProviderFreshness?,
        sourcePolicy: ServerSourcePolicy?,
        confirmationState: ServerConfirmationState?,
        audit: ServerProviderRuntimeReceiptAudit
    ) {
        self.id = id
        self.state = state
        self.statusLine = statusLine
        self.adapterResultID = adapterResultID
        self.boundaryID = boundaryID
        self.planID = planID
        self.traceID = traceID
        self.providerFamily = providerFamily
        self.capability = capability
        self.descriptorID = descriptorID
        self.costClass = costClass
        self.freshness = freshness
        self.sourcePolicy = sourcePolicy
        self.confirmationState = confirmationState
        self.audit = audit
    }
}

enum ServerProviderRuntimeReceiptProjector {
    nonisolated static func project(
        _ result: ServerProviderRuntimeAdapterResult
    ) -> ServerProviderRuntimeReceipt {
        let state = receiptState(for: result)
        let projected = state == .fixtureProjected
        return ServerProviderRuntimeReceipt(
            id: "server-provider-receipt-\(safeID(result.id))",
            state: state,
            statusLine: statusLine(state: state, result: result),
            adapterResultID: result.id,
            boundaryID: result.boundaryID,
            planID: result.planID,
            traceID: projected ? result.traceID : nil,
            providerFamily: projected ? result.providerFamily : nil,
            capability: projected ? result.capability : nil,
            descriptorID: projected ? result.descriptorID : nil,
            costClass: projected ? result.costClass : nil,
            freshness: projected ? result.freshness : nil,
            sourcePolicy: projected ? result.sourcePolicy : nil,
            confirmationState: projected ? result.confirmationState : nil,
            audit: ServerProviderRuntimeReceiptAudit(
                adapterResultID: result.id,
                adapterResultState: result.state,
                adapterAudit: result.audit
            )
        )
    }

    nonisolated private static func receiptState(
        for result: ServerProviderRuntimeAdapterResult
    ) -> ServerProviderRuntimeReceiptState {
        switch result.state {
        case .acceptedFixture:
            return result.isAcceptedFixture ? .fixtureProjected : .notPrepared
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
        case .notPrepared:
            return unavailableReason(result.audit.adapterRejectionReason)
                ? .unavailable
                : .notPrepared
        }
    }

    nonisolated private static func unavailableReason(
        _ rejection: ServerProviderRuntimeAdapterRejectionReason?
    ) -> Bool {
        switch rejection {
        case .unregisteredProvider, .providerMismatch, .adapterSetUseNotAuthorized:
            return true
        case .boundaryNotPrepared, .missingBoundaryID, .missingPlanID,
             .missingTraceID, .missingProviderFamily, .missingCapability,
             .missingDescriptorID, .none:
            return false
        }
    }

    nonisolated private static func statusLine(
        state: ServerProviderRuntimeReceiptState,
        result: ServerProviderRuntimeAdapterResult
    ) -> String {
        switch state {
        case .fixtureProjected:
            return "Fixture receipt is projected from adapter metadata only. No provider runtime has run."
        case .localOnly:
            return "Receipt remains local-only because no server adapter output is available. \(result.statusLine)"
        case .confirmationRequired:
            return "Receipt is withheld until confirmation is satisfied. \(result.statusLine)"
        case .blocked:
            return "Receipt is unavailable because adapter output is blocked. \(result.statusLine)"
        case .descriptorUnavailable:
            return "Receipt is unavailable because descriptor metadata is unavailable. \(result.statusLine)"
        case .planRejected:
            return "Receipt is unavailable because plan metadata was rejected. \(result.statusLine)"
        case .notPrepared:
            return "Receipt is unavailable because adapter metadata is not prepared. \(result.statusLine)"
        case .unavailable:
            return "Receipt is unavailable because no registered adapter output can be projected. \(result.statusLine)"
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
        return slug.isEmpty ? "missing-adapter-result-id" : slug
    }
}
