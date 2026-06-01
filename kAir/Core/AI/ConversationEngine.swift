//
//  ConversationEngine.swift
//  kAir
//
//  The conversation orchestration engine (A5 skeleton).
//

import Foundation

// Architecture note:
// `ConversationEngine` is the command pipeline between Chat and the
// capability system. It owns orchestration, not UI rendering and not
// low-level adapter behavior.
//
// Canonical future flow:
// 1. Accept user input plus current chat/thread identifiers.
// 2. Ask `PrivacyGuard` and memory policy which context may be used.
// 3. Build a minimal `ContextPacket`.
// 4. Invoke the local router/planner model through `ModelProvider`, or a
//    deterministic parser fixture when no model is installed.
// 5. Parse structured `IntentDraft`; reject free-form plans.
// 6. Route to `CapabilityKind` via `CapabilityRouter`.
// 7. Build `ActionPlan` with slots, risk, confirmation need, and target
//    `SurfaceKind`.
// 8. Validate with `PlanValidator`.
// 9. Dispatch only approved read-only or confirmed tool calls.
// 10. Project `NormalizedResult` into transcript, recommendation,
//     execution surface, and memory candidate through `ResultProjector`.
//
// Forbidden:
// - No SwiftUI import.
// - No direct `ServerTransport` call.
// - No direct HealthKit access.
// - No remote paid model call unless model policy and entitlement allow.
// - No automatic execution of pay/write/share/external-open actions.
//
// Failure behavior:
// - Missing model -> deterministic fallback or model setup recommendation.
// - Low confidence -> ask clarification.
// - Privacy block -> local explanation, no remote attempt.
// - Adapter unavailable -> recommendation disabled or permission surface.
//
// A5 skeleton scope (this file): steps 5–8 only — the pure orchestration core
// that turns an already-parsed `IntentDraft` (the model/parser output of step 4)
// into a validated outcome by composing the ratified A2 contracts
// (`CapabilityRouter` -> `ActionPlan` -> `PlanValidator`). Step 4 (model
// invocation), step 9 (dispatch), and step 10 (projection) remain seams: this
// engine never invokes a model, calls an adapter, mutates `ChatStore`, or
// touches UI. `modelExecution` is injected (defaulting to on-device); a later
// cut feeds it from `ModelTierRouter` (redesign R2).

/// The single terminal outcome of orchestrating one `IntentDraft`. Mirrors the
/// `PlanValidator` decision plus a routing-failure case, so the Chat layer can
/// branch without re-deriving policy.
enum ConversationOutcome: Hashable, Sendable {
    /// Safe (read-only), confident, complete → the caller may dispatch.
    case readyToDispatch(ActionPlan)
    /// A risky action that needs a user confirmation artifact first.
    case needsConfirmation(ActionPlan)
    /// Cannot proceed yet → ask the user to clarify (low confidence / missing slots).
    case needsClarification(PlanValidation.ClarificationReason)
    /// Forbidden by policy (e.g. health → remote model) → explain locally.
    case blocked(PlanValidation.BlockReason)
    /// The capability could not be resolved → clarification / recommendation.
    case unresolved
}

/// Pure orchestration. Deterministic, no side effects: no model invocation, no
/// network, no HealthKit, no adapter dispatch, no `ChatStore`/UI mutation.
enum ConversationEngine {
    /// Compose the A2 pipeline for one structured draft:
    /// route the capability → build the typed plan → validate it.
    ///
    /// - Parameters:
    ///   - draft: the structured router/parser output (step 5). Free-form text
    ///     is never accepted as a plan — only this typed contract.
    ///   - modelExecution: the execution target for the plan (on-device by
    ///     default; a later cut supplies this from `ModelTierRouter`).
    static func resolve(
        _ draft: IntentDraft,
        modelExecution: ModelExecution = .onDevice
    ) -> ConversationOutcome {
        // 6. Route the raw capability string to the typed vocabulary.
        guard let capability = CapabilityRouter.route(draft).capability else {
            return .unresolved
        }

        // 7. Build the typed plan (derives surface, risk, confirmation need).
        let plan = ActionPlan.make(
            from: draft,
            capability: capability,
            modelExecution: modelExecution
        )

        // 8. Validate (privacy → confidence → slots → confirmation). The engine
        //    returns the decision; it never dispatches here.
        switch PlanValidator.validate(plan) {
        case .approved:
            return .readyToDispatch(plan)
        case .needsConfirmation:
            return .needsConfirmation(plan)
        case .needsClarification(let reason):
            return .needsClarification(reason)
        case .blocked(let reason):
            return .blocked(reason)
        }
    }
}
