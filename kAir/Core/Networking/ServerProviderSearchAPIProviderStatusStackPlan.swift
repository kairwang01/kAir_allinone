//
//  ServerProviderSearchAPIProviderStatusStackPlan.swift
//  kAir
//
//  A169 value-only ordering plan for future Search API provider-status
//  composition. The plan freezes stage order and extension slots without
//  installing a production source stack.
//

import Foundation

enum ServerProviderSearchAPIProviderStatusStackStage:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case envelope
    case invocationPreflight
    case adapterInterface
    case liveVendorSelection
    case readiness
    case meteredEntitlement
    case vendorPolicy
    case dispatchAuthorization
    case lease
    case request
    case response
    case transportPreflight
    case audit
    case fallback

    nonisolated static let defaultOrder: [Self] = [
        .envelope,
        .invocationPreflight,
        .adapterInterface,
        .liveVendorSelection,
        .readiness,
        .meteredEntitlement,
        .vendorPolicy,
        .dispatchAuthorization,
        .lease,
        .request,
        .response,
        .transportPreflight,
        .audit,
        .fallback,
    ]

    nonisolated var defaultRank: Int {
        Self.defaultOrder.firstIndex(of: self).map { $0 + 1 } ?? 0
    }

    nonisolated var stageID: String {
        switch self {
        case .envelope:
            return "search-api-status-envelope"
        case .invocationPreflight:
            return "search-api-status-invocation-preflight"
        case .adapterInterface:
            return "search-api-status-adapter-interface"
        case .liveVendorSelection:
            return "search-api-status-live-vendor-selection"
        case .readiness:
            return "search-api-status-readiness"
        case .meteredEntitlement:
            return "search-api-status-metered-entitlement"
        case .vendorPolicy:
            return "search-api-status-vendor-policy"
        case .dispatchAuthorization:
            return "search-api-status-dispatch-authorization"
        case .lease:
            return "search-api-status-lease"
        case .request:
            return "search-api-status-request"
        case .response:
            return "search-api-status-response"
        case .transportPreflight:
            return "search-api-status-transport-preflight"
        case .audit:
            return "search-api-status-audit"
        case .fallback:
            return "search-api-status-fallback"
        }
    }

    nonisolated var displayLabel: String {
        switch self {
        case .envelope:
            return "Invocation envelope"
        case .invocationPreflight:
            return "Invocation preflight"
        case .adapterInterface:
            return "Adapter interface"
        case .liveVendorSelection:
            return "Live vendor selection"
        case .readiness:
            return "Readiness"
        case .meteredEntitlement:
            return "Metered entitlement"
        case .vendorPolicy:
            return "Vendor policy"
        case .dispatchAuthorization:
            return "Dispatch authorization"
        case .lease:
            return "Lease"
        case .request:
            return "Request"
        case .response:
            return "Response"
        case .transportPreflight:
            return "Transport preflight"
        case .audit:
            return "Audit"
        case .fallback:
            return "Fallback"
        }
    }

    nonisolated var debugLabel: String {
        "\(defaultRank).\(stageID)"
    }

    nonisolated var contractNote: String {
        switch self {
        case .envelope:
            return "Ranks advisory envelope status first and keeps isRuntimeCallable false plus isExecutable false visible in UI copy."
        case .invocationPreflight:
            return "Pins invocation preflight metadata before lower stages shape provider status."
        case .adapterInterface:
            return "Reports selected adapter metadata for UI-safe status only."
        case .liveVendorSelection:
            return "Reports selected vendor metadata as advisory status when earlier stages miss."
        case .readiness:
            return "Reports planning readiness evidence without opening a remote path."
        case .meteredEntitlement:
            return "Reports quota and membership posture as metadata only."
        case .vendorPolicy:
            return "Reports vendor policy acceptance or block labels from safe metadata."
        case .dispatchAuthorization:
            return "Reports dispatch authorization labels for an approved plan."
        case .lease:
            return "Reports budget lease posture before request preparation."
        case .request:
            return "Reports prepared request metadata without a network hop."
        case .response:
            return "Reports response receipt metadata after normalized fixture review."
        case .transportPreflight:
            return "Reports transport preflight labels for UI copy only."
        case .audit:
            return "Reports audit labels and review dimensions as value-only copy."
        case .fallback:
            return "Last local fallback when earlier sources are absent."
        }
    }
}

enum ServerProviderSearchAPIProviderStatusStackExtensionSlot:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case costBasedProviderSelection
    case membershipTierRouting
    case quotaClassSelection
    case regionalPolicyRouting

    nonisolated static let defaultSlots: [Self] = [
        .costBasedProviderSelection,
        .membershipTierRouting,
        .quotaClassSelection,
        .regionalPolicyRouting,
    ]

    nonisolated var slotID: String {
        switch self {
        case .costBasedProviderSelection:
            return "search-api-slot-cost-based-provider-selection"
        case .membershipTierRouting:
            return "search-api-slot-membership-tier-routing"
        case .quotaClassSelection:
            return "search-api-slot-quota-class-selection"
        case .regionalPolicyRouting:
            return "search-api-slot-regional-policy-routing"
        }
    }

    nonisolated var reviewerNote: String {
        switch self {
        case .costBasedProviderSelection:
            return "Reserved for choosing included-quota or metered vendor status from budget metadata."
        case .membershipTierRouting:
            return "Reserved for free, plus, and pro membership routing in metadata."
        case .quotaClassSelection:
            return "Reserved for quota-class status labels before vendor policy review."
        case .regionalPolicyRouting:
            return "Reserved for region-aware vendor policy labels."
        }
    }
}

struct ServerProviderSearchAPIProviderStatusStackPlanStage:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let stage: ServerProviderSearchAPIProviderStatusStackStage
    let id: String
    let rank: Int
    let displayLabel: String
    let debugLabel: String
    let contractNote: String

    nonisolated init(stage: ServerProviderSearchAPIProviderStatusStackStage) {
        self.init(
            stage: stage,
            id: stage.stageID,
            rank: stage.defaultRank,
            displayLabel: stage.displayLabel,
            debugLabel: stage.debugLabel,
            contractNote: stage.contractNote
        )
    }

    nonisolated init(
        stage: ServerProviderSearchAPIProviderStatusStackStage,
        id: String,
        rank: Int,
        displayLabel: String,
        debugLabel: String,
        contractNote: String
    ) {
        self.stage = stage
        self.id = Self.safeID(id, fallback: stage.stageID)
        self.rank = rank
        self.displayLabel = displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.debugLabel = debugLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contractNote = contractNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func safeID(
        _ value: String,
        fallback: String
    ) -> String {
        let normalized = value
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
        let slug = normalized
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? fallback : slug
    }
}

struct ServerProviderSearchAPIProviderStatusStackPlanExtensionSlot:
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    let slot: ServerProviderSearchAPIProviderStatusStackExtensionSlot
    let id: String
    let reviewerNote: String

    nonisolated init(slot: ServerProviderSearchAPIProviderStatusStackExtensionSlot) {
        self.slot = slot
        self.id = slot.slotID
        self.reviewerNote = slot.reviewerNote
    }
}

enum ServerProviderSearchAPIProviderStatusStackPlanValidationState:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case accepted
    case rejected
}

enum ServerProviderSearchAPIProviderStatusStackPlanValidationReason:
    String,
    Codable,
    Hashable,
    Sendable,
    CaseIterable
{
    case emptyStages
    case duplicateStageID
    case duplicateStageKind
    case duplicateRank
    case nonContiguousRanks
    case envelopeNotFirst
    case fallbackNotLast
    case stageOrderMismatch
    case rankStageMismatch
}

struct ServerProviderSearchAPIProviderStatusStackPlanValidationResult:
    Codable,
    Hashable,
    Sendable
{
    let state: ServerProviderSearchAPIProviderStatusStackPlanValidationState
    let reasons: [ServerProviderSearchAPIProviderStatusStackPlanValidationReason]

    nonisolated var isAccepted: Bool {
        state == .accepted
    }
}

struct ServerProviderSearchAPIProviderStatusStackPlanSafeCopy:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let stageIDs: [String]
    let stageRanks: [Int]
    let extensionSlotIDs: [String]
    let isRuntimeCallable: Bool
    let envelopeStageRequiresNonExecutableCopy: Bool
    let validationState: ServerProviderSearchAPIProviderStatusStackPlanValidationState
    let validationReasons: [ServerProviderSearchAPIProviderStatusStackPlanValidationReason]

    nonisolated var description: String {
        "SearchAPIProviderStatusStackPlanSafeCopy(id: \(id), stages: \(stageIDs.count), callable: \(isRuntimeCallable), validation: \(validationState.rawValue))"
    }
}

struct ServerProviderSearchAPIProviderStatusStackPlan:
    Codable,
    Hashable,
    Identifiable,
    Sendable,
    CustomStringConvertible
{
    let id: String
    let stages: [ServerProviderSearchAPIProviderStatusStackPlanStage]
    let extensionSlots: [ServerProviderSearchAPIProviderStatusStackPlanExtensionSlot]
    let runtimeEntryPointName: String?

    nonisolated init(
        id: String = "a169-search-api-provider-status-stack-plan",
        stages: [ServerProviderSearchAPIProviderStatusStackPlanStage],
        extensionSlots: [ServerProviderSearchAPIProviderStatusStackPlanExtensionSlot],
        runtimeEntryPointName: String? = nil
    ) {
        self.id = id
        self.stages = stages
        self.extensionSlots = extensionSlots
        self.runtimeEntryPointName = runtimeEntryPointName
    }

    nonisolated static func defaultPlan() -> Self {
        ServerProviderSearchAPIProviderStatusStackPlan(
            stages: ServerProviderSearchAPIProviderStatusStackStage.defaultOrder
                .map(ServerProviderSearchAPIProviderStatusStackPlanStage.init),
            extensionSlots: ServerProviderSearchAPIProviderStatusStackExtensionSlot.defaultSlots
                .map(ServerProviderSearchAPIProviderStatusStackPlanExtensionSlot.init),
            runtimeEntryPointName: nil
        )
    }

    nonisolated static func stages(
        for order: [ServerProviderSearchAPIProviderStatusStackStage]
    ) -> [ServerProviderSearchAPIProviderStatusStackPlanStage] {
        order.map(ServerProviderSearchAPIProviderStatusStackPlanStage.init)
    }

    nonisolated var isRuntimeCallable: Bool {
        false
    }

    nonisolated var validation: ServerProviderSearchAPIProviderStatusStackPlanValidationResult {
        Self.validate(stages: stages)
    }

    nonisolated var safeCopy: ServerProviderSearchAPIProviderStatusStackPlanSafeCopy {
        let result = validation
        return ServerProviderSearchAPIProviderStatusStackPlanSafeCopy(
            id: id,
            stageIDs: stages.map(\.id),
            stageRanks: stages.map(\.rank),
            extensionSlotIDs: extensionSlots.map(\.id),
            isRuntimeCallable: isRuntimeCallable,
            envelopeStageRequiresNonExecutableCopy: stages.first?.stage == .envelope,
            validationState: result.state,
            validationReasons: result.reasons
        )
    }

    nonisolated var description: String {
        "ServerProviderSearchAPIProviderStatusStackPlan(id: \(id), stages: \(stages.count), slots: \(extensionSlots.count), callable: \(isRuntimeCallable), validation: \(validation.state.rawValue))"
    }

    nonisolated static func validate(
        stages: [ServerProviderSearchAPIProviderStatusStackPlanStage]
    ) -> ServerProviderSearchAPIProviderStatusStackPlanValidationResult {
        var reasons: [ServerProviderSearchAPIProviderStatusStackPlanValidationReason] = []

        if stages.isEmpty {
            reasons.append(.emptyStages)
        }
        if Set(stages.map(\.id)).count != stages.count {
            reasons.append(.duplicateStageID)
        }
        if Set(stages.map(\.stage)).count != stages.count {
            reasons.append(.duplicateStageKind)
        }
        if Set(stages.map(\.rank)).count != stages.count {
            reasons.append(.duplicateRank)
        }
        if !stages.isEmpty, stages.map(\.rank) != Array(1...stages.count) {
            reasons.append(.nonContiguousRanks)
        }
        if stages.first?.stage != .envelope {
            reasons.append(.envelopeNotFirst)
        }
        if stages.last?.stage != .fallback {
            reasons.append(.fallbackNotLast)
        }
        if stages.map(\.stage) != ServerProviderSearchAPIProviderStatusStackStage.defaultOrder {
            reasons.append(.stageOrderMismatch)
        }
        if stages.contains(where: { $0.rank != $0.stage.defaultRank }) {
            reasons.append(.rankStageMismatch)
        }

        let stableReasons = deduplicated(reasons)
        return ServerProviderSearchAPIProviderStatusStackPlanValidationResult(
            state: stableReasons.isEmpty ? .accepted : .rejected,
            reasons: stableReasons
        )
    }

    private nonisolated static func deduplicated<T: Hashable>(
        _ values: [T]
    ) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
