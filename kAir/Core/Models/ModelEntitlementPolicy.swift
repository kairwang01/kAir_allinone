//
//  ModelEntitlementPolicy.swift
//  kAir
//
//  Pure paid-gating policy for the model catalog.
//
//  A3 model-catalog value contracts (kair-ai-model-memory-v1.md §6, §7). A
//  deterministic value function over a catalog entry + a StoreKit-derived
//  entitlement. No real StoreKit, no receipt validation, no network — this is
//  the policy a future EntitlementState provider feeds.
//
//  Contract (the round's hard constraints):
//    - A paid model NEVER becomes downloadable without `.entitled` — no faked
//      purchase, no faked unlock.
//    - Free models are always download-eligible.
//    - This policy never returns an installed/active state; install progress
//      comes from a real download manager, never fabricated here.
//

import Foundation

/// A StoreKit-derived entitlement for a model (§7). Resolved server-side from a
/// validated receipt in production; an in-memory fixture for this round.
enum ModelEntitlement: String, Codable, Hashable, Sendable, CaseIterable {
    /// No purchase / no entitlement — a paid model stays locked.
    case notEntitled
    /// Purchase verified — a paid model may be downloaded / accessed.
    case entitled
}

/// Pure paid-gating policy (§6 "paid model download starts only after
/// entitlement"; §7 paid path). Stateless.
enum ModelEntitlementPolicy {
    /// The download eligibility of an entry given the user's entitlement.
    ///
    /// - Free entry (no `priceProductID`) → `.free`.
    /// - Paid + `.entitled` → `.entitled`.
    /// - Paid + `.notEntitled` → `.requiresPurchase` (locked).
    static func eligibility(
        for entry: ModelCatalogEntry,
        entitlement: ModelEntitlement
    ) -> DownloadEligibility {
        guard entry.isPaid else { return .free }
        switch entitlement {
        case .entitled:    return .entitled
        case .notEntitled: return .requiresPurchase
        }
    }

    /// Whether a user-initiated download may begin for an entry. `false` for a
    /// paid, not-yet-entitled entry (the lock holds — no faked unlock).
    static func canStartDownload(
        for entry: ModelCatalogEntry,
        entitlement: ModelEntitlement
    ) -> Bool {
        eligibility(for: entry, entitlement: entitlement).allowsDownload
    }

    /// The initial download state an entry presents *before any install
    /// progress*, derived purely from entitlement. Never returns
    /// `installed` / `active` / `downloading` — real progress comes from the
    /// (not-yet-wired) download manager, never fabricated.
    ///
    /// - Free or paid+entitled → `.eligible`.
    /// - Paid + not entitled → `.requiresPurchase`.
    static func initialDownloadState(
        for entry: ModelCatalogEntry,
        entitlement: ModelEntitlement
    ) -> ModelDownloadState {
        switch eligibility(for: entry, entitlement: entitlement) {
        case .free, .entitled:  return .eligible
        case .requiresPurchase: return .requiresPurchase
        }
    }

    /// The result of evaluating a catalog entry against an entitlement.
    enum DownloadEligibility: String, Codable, Hashable, Sendable, CaseIterable {
        /// Free model — always downloadable.
        case free
        /// Paid model with a verified entitlement — downloadable.
        case entitled
        /// Paid model without entitlement — locked until purchase (§7).
        case requiresPurchase

        /// Whether a download may begin. Only `requiresPurchase` blocks it.
        var allowsDownload: Bool {
            self != .requiresPurchase
        }
    }
}
