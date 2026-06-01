//
//  PlanValidator.swift
//  kAir
//
//  Pure validation of an `ActionPlan` before any dispatch.
//
//  A2 pure value contracts (kair-ai-model-memory-v1.md §2; ConversationEngine
//  step 8). The enforcement point for the §2 execution gates and the
//  PrivacyGuard health-to-remote rule. A deterministic value function — no
//  model, no network, no HealthKit, no side effects.
//
//  Order of checks (highest authority first):
//    1. Privacy: a health capability on a remote model is forbidden.
//    2. Low confidence cannot execute.
//    3. Missing required slots.
//    4. Risky action needs a confirmation artifact.
//    5. Otherwise approved (read-only, confident, complete).
//

import Foundation

/// Validates an `ActionPlan` and returns exactly one terminal outcome.
enum PlanValidator {
    static func validate(_ plan: ActionPlan) -> PlanValidation {
        // 1. Privacy gate (highest authority): a health capability must never
        //    run on a remote model in v1 (PrivacyGuard
        //    `.healthDataMustNotReachRemoteModel`; §2; §9). Blocked outright,
        //    regardless of confidence or slots — no remote attempt.
        if isHealth(plan.capability), plan.modelExecution == .remote {
            return .blocked(.healthToRemoteModel)
        }

        // 2. Low confidence cannot execute → clarification (§2; §16).
        guard plan.confidence.canExecute else {
            return .needsClarification(.lowConfidence)
        }

        // 3. Missing required slots → clarification (§2 missing_slots).
        if plan.missingSlots.isEmpty == false {
            return .needsClarification(.missingSlots(plan.missingSlots))
        }

        // 4. Risky actions (write / pay / share / externalOpen) require a user
        //    confirmation artifact before dispatch (§2; `ToolRegistry`).
        if plan.requiresConfirmation {
            return .needsConfirmation
        }

        // 5. Read-only, confident, complete → safe to dispatch.
        return .approved
    }

    /// Health capabilities (§3 — `healthRead` / `healthWrite`). Derived here
    /// rather than on the frozen `CapabilityKind` so this round's change stays
    /// confined to the A2 files.
    private static func isHealth(_ capability: CapabilityKind) -> Bool {
        capability == .healthRead || capability == .healthWrite
    }
}

/// The result of validating an `ActionPlan`. Exactly one state per plan.
enum PlanValidation: Hashable, Sendable {
    /// Safe (read-only), confident, and complete → may dispatch immediately.
    case approved
    /// A risky action that needs a user confirmation artifact first (§2).
    case needsConfirmation
    /// Cannot proceed yet → ask the user to clarify.
    case needsClarification(ClarificationReason)
    /// Forbidden by policy → explain locally, never attempt (§16 privacy
    /// blocked).
    case blocked(BlockReason)

    /// Why a plan needs clarification before it can execute.
    enum ClarificationReason: Hashable, Sendable {
        case lowConfidence
        case missingSlots([String])
    }

    /// Why a plan is blocked. Each reason cites the PrivacyGuard rule it
    /// enforces via `privacyRule`.
    enum BlockReason: String, Codable, Hashable, Sendable, CaseIterable {
        case healthToRemoteModel
    }
}

extension PlanValidation.BlockReason {
    /// The PrivacyGuard rule this block enforces, so callers can surface the
    /// canonical reason / copy without re-deriving policy.
    var privacyRule: PrivacyGuard.RuleID {
        switch self {
        case .healthToRemoteModel:
            return .healthDataMustNotReachRemoteModel
        }
    }
}
