//
//  ModelTierRouter.swift
//  kAir
//
//  Pure cost-aware model-tier selection (the model cascade).
//
//  Reserved interface R2 of `Docs/architecture/kair-architecture-redesign-v2.md`
//  §5.2. The provider track prices *services* (maps / search / MCP); this prices
//  *models*. A deterministic FrugalGPT / RouteLLM-style cascade over the A3
//  catalog roles — local router/planner/specialist first, paid remote only on
//  low confidence and only when entitled.
//
//  Research invariant (deep-dive §3.1, top implication #1): the **health/private
//  domain gate runs BEFORE the cost/confidence cascade**. No confidence score or
//  cost signal escalates health context to a remote model. Model choice is also
//  user-visible (Yuanbao 2×2): the router picks a *default* tier; the caller
//  surfaces it and never silently moves a user to a paid model.
//
//  Pure value function — no model runtime, no network, no SDK. Reuses
//  `CapabilityKind`, `IntentConfidence`, `MembershipTier`, `ProviderPrivacyClass`.
//

import Foundation

/// The model tiers a request can route to, cheapest first. Mirrors the A3
/// catalog roles (`ModelRole`): local router/planner/specialist, plus the paid
/// remote market model.
enum ModelTier: String, Codable, Hashable, Sendable, CaseIterable {
    case localRouter
    case localPlanner
    case localSpecialist
    case paidRemote

    /// Only the paid market tier leaves the device.
    var isRemote: Bool {
        self == .paidRemote
    }

    /// Relative cost ordering (router cheapest, paid remote most expensive).
    var costRank: Int {
        switch self {
        case .localRouter:     return 0
        case .localPlanner:    return 1
        case .localSpecialist: return 2
        case .paidRemote:      return 3
        }
    }
}

/// Why a tier was chosen.
enum ModelTierReason: String, Codable, Hashable, Sendable, CaseIterable {
    /// Health capability → local specialist, before any cost/confidence check.
    case healthLocalOnly
    /// Non-general (private) context stays local.
    case privateLocalOnly
    /// Confident + general → cheapest covering local tier.
    case confidentLocal
    /// Low confidence + general + entitled → escalate to paid remote.
    case escalatedLowConfidence
    /// Low confidence but no paid entitlement → best local tier (no silent paid).
    case paidUnavailableLocalFallback
}

/// Input to `ModelTierRouter`. `paidRemoteEntitled` comes from the membership /
/// entitlement layer (StoreKit-verified, server-mediated) — never inferred from
/// the raw tier alone, consistent with the provider track.
struct ModelTierRequest: Hashable, Sendable {
    let capability: CapabilityKind
    let confidence: IntentConfidence
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let paidRemoteEntitled: Bool

    init(
        capability: CapabilityKind,
        confidence: IntentConfidence,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        paidRemoteEntitled: Bool = false
    ) {
        self.capability = capability
        self.confidence = confidence
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.paidRemoteEntitled = paidRemoteEntitled
    }
}

/// The tier decision. Exactly one tier per request; `escalatedToPaid` flags the
/// only branch that selects a remote model so the UI can surface the choice.
struct ModelTierDecision: Hashable, Sendable {
    let tier: ModelTier
    let escalatedToPaid: Bool
    let reason: ModelTierReason

    var isRemote: Bool {
        tier.isRemote
    }
}

/// Pure cost-aware model cascade. Order is fixed and privacy-first.
enum ModelTierRouter {
    static func route(_ request: ModelTierRequest) -> ModelTierDecision {
        // 1. HARD GATE (before cost/confidence): health is local-only. A health
        //    capability always routes to the local specialist — never a remote
        //    model, regardless of confidence, membership, or entitlement.
        if isHealth(request.capability) {
            return ModelTierDecision(
                tier: .localSpecialist,
                escalatedToPaid: false,
                reason: .healthLocalOnly
            )
        }

        // 2. Non-general (private) context stays on device too.
        if request.privacyClass != .general {
            return ModelTierDecision(
                tier: localTier(for: request.capability),
                escalatedToPaid: false,
                reason: .privateLocalOnly
            )
        }

        // 3. Confident + general → cheapest local tier that covers the capability.
        if request.confidence.canExecute {
            return ModelTierDecision(
                tier: localTier(for: request.capability),
                escalatedToPaid: false,
                reason: .confidentLocal
            )
        }

        // 4. Low confidence + general + entitled → escalate to the paid remote
        //    model (FrugalGPT cascade). Surfaced to the user, never silent.
        if request.paidRemoteEntitled {
            return ModelTierDecision(
                tier: .paidRemote,
                escalatedToPaid: true,
                reason: .escalatedLowConfidence
            )
        }

        // 5. Low confidence but no paid entitlement → best available local tier.
        //    Never silently switch a non-entitled user to a paid model.
        return ModelTierDecision(
            tier: .localSpecialist,
            escalatedToPaid: false,
            reason: .paidUnavailableLocalFallback
        )
    }

    /// Health capabilities (§3 — `healthRead` / `healthWrite`). Derived here, as
    /// in `PlanValidator`, to keep this round confined to the R2 file.
    private static func isHealth(_ capability: CapabilityKind) -> Bool {
        capability == .healthRead || capability == .healthWrite
    }

    /// The cheapest local tier that covers a capability. Simple retrieval →
    /// router; planning/tool capabilities → planner; health → specialist.
    private static func localTier(for capability: CapabilityKind) -> ModelTier {
        switch capability {
        case .threadLookup, .localStoreLookup:
            return .localRouter
        case .aiCompletion, .placeSearch, .routePlanning, .musicPlayback,
             .videoPlayback, .webSearch:
            return .localPlanner
        case .healthRead, .healthWrite:
            return .localSpecialist
        }
    }
}
