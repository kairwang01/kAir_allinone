//
//  ActionPlan.swift
//  kAir
//
//  Pure value contract for a routed, ready-to-validate execution plan.
//
//  A2 pure value contracts (kair-ai-model-memory-v1.md §2; ConversationEngine
//  step 7). Built from an `IntentDraft` plus the `CapabilityKind` the
//  `CapabilityRouter` resolved. Foundation only — no model, no network, no
//  HealthKit, no SwiftUI.
//
//  Not `Codable`: it holds the typed `CapabilityKind` / `SurfaceKind`
//  vocabulary (frozen, intentionally non-`Codable`), which is the right trade
//  for a downstream pipeline value. It is `Hashable` + `Sendable`.
//

import Foundation

/// A routed execution plan awaiting `PlanValidator` approval (step 8). It
/// carries the resolved capability, derived target surface, slots, risk,
/// confirmation need (derived from risk), confidence, and the model-execution
/// location used for the privacy gate.
struct ActionPlan: Hashable, Sendable {
    let intentID: String
    let capability: CapabilityKind
    let slots: [IntentSlot]
    let missingSlots: [String]
    let risk: ActionRisk
    let confidence: IntentConfidence
    /// Where the plan's model work would run. Health capabilities must never
    /// resolve to `.remote` — see `PlanValidator` + PrivacyGuard
    /// `.healthDataMustNotReachRemoteModel`.
    let modelExecution: ModelExecution
    let userVisibleSummary: String

    init(
        intentID: String,
        capability: CapabilityKind,
        slots: [IntentSlot] = [],
        missingSlots: [String] = [],
        risk: ActionRisk,
        confidence: IntentConfidence,
        modelExecution: ModelExecution,
        userVisibleSummary: String
    ) {
        self.intentID = intentID
        self.capability = capability
        self.slots = slots
        self.missingSlots = missingSlots
        self.risk = risk
        self.confidence = confidence
        self.modelExecution = modelExecution
        self.userVisibleSummary = userVisibleSummary
    }

    /// The target surface family, derived from the capability (§3.3 mapping in
    /// `CapabilityKind.surfaceFamily`). Always consistent with the capability
    /// — never set independently.
    var surface: SurfaceKind {
        capability.surfaceFamily
    }

    /// Whether this plan needs a user confirmation artifact before dispatch,
    /// derived from its risk class (§2). `PlanValidator` is the enforcement
    /// point.
    var requiresConfirmation: Bool {
        risk.requiresConfirmation
    }

    /// Builds a plan from a structured intent and the capability the router
    /// resolved it to (ConversationEngine step 7). Risk / slots / confidence
    /// carry over from the intent; the surface is derived from the capability.
    static func make(
        from intent: IntentDraft,
        capability: CapabilityKind,
        modelExecution: ModelExecution
    ) -> ActionPlan {
        ActionPlan(
            intentID: intent.intentID,
            capability: capability,
            slots: intent.slots,
            missingSlots: intent.missingSlots,
            risk: intent.risk,
            confidence: intent.confidence,
            modelExecution: modelExecution,
            userVisibleSummary: intent.userVisibleSummary
        )
    }
}

/// Where a plan's model work runs. The router / planner / health specialist
/// are on-device; premium market models are remote (§1, §7). Privacy gates
/// depend on this distinction.
enum ModelExecution: String, Codable, Hashable, Sendable, CaseIterable {
    case onDevice
    case remote
}
