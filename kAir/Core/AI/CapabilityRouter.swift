//
//  CapabilityRouter.swift
//  kAir
//
//  Pure routing from an `IntentDraft` to a resolved capability + surface.
//
//  A2 pure value contracts (kair-ai-model-memory-v1.md §2; ConversationEngine
//  step 6). A deterministic value function — no model, no network, no side
//  effects. It resolves the raw capability string the router emitted into the
//  typed `CapabilityKind` vocabulary, or reports why it could not.
//
//  Routing is only "which capability / surface". The downstream
//  `PlanValidator` owns the execution gates (confidence, slots, confirmation,
//  privacy) — this stays a pure, single-purpose resolver.
//

import Foundation

/// Routes a structured `IntentDraft` to a capability (the §2 "route to
/// capability" step).
enum CapabilityRouter {
    /// Resolve the intent's capability identifier into a `CapabilityKind`. An
    /// absent or unrecognized identifier is `unresolved(.unknownCapability)`
    /// — the §2 "unknown capability → clarification / recommendation" fallback.
    static func route(_ intent: IntentDraft) -> CapabilityRoute {
        guard
            let raw = intent.capability,
            let capability = CapabilityKind(rawValue: raw)
        else {
            return .unresolved(reason: .unknownCapability)
        }
        return .resolved(capability: capability, surface: capability.surfaceFamily)
    }
}

/// The outcome of routing an `IntentDraft`.
enum CapabilityRoute: Hashable, Sendable {
    /// The intent resolved to a known capability and its target surface.
    case resolved(capability: CapabilityKind, surface: SurfaceKind)
    /// The intent could not be routed; the engine falls back to clarification
    /// or a recommendation (§2).
    case unresolved(reason: UnresolvedReason)

    /// Why an intent could not be routed.
    enum UnresolvedReason: String, Codable, Hashable, Sendable, CaseIterable {
        /// No capability, or a capability identifier outside the frozen
        /// `CapabilityKind` vocabulary.
        case unknownCapability
    }

    /// Convenience: the resolved capability, or `nil` when unresolved.
    var capability: CapabilityKind? {
        if case let .resolved(capability, _) = self { return capability }
        return nil
    }
}
