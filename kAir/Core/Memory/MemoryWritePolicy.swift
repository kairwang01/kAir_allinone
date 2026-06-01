//
//  MemoryWritePolicy.swift
//  kAir
//
//  Pure write-admission policy for local memory.
//
//  A4 memory facade value contracts (kair-ai-model-memory-v1.md §11 write
//  policy; PrivacyGuard `.healthAndSocialStoresMustRemainSeparate`). A
//  deterministic value function — no store, no model, no network, no side
//  effects. The `MemoryStore` consults it before persisting any record.
//
//  Order of checks (highest authority first):
//    1. Writes paused → reject (pause must stop writes without breaking chat).
//    2. Categorically blocked source (hallucination / unconfirmed plan) → reject.
//    3. External-partner data without a declared retention purpose → reject.
//    4. Health-derived context targeting a non-Health domain → reject.
//    5. Sensitive content outside the Health domain → reject.
//    6. Otherwise approved.
//

import Foundation

/// Admits or rejects a proposed memory write (§11). Pure and stateless; the
/// pause flag is passed in by the store.
enum MemoryWritePolicy {
    static func evaluate(_ record: MemoryRecord, isPaused: Bool) -> MemoryWriteDecision {
        // 1. Pause stops every write while leaving chat usable (§ memory ops).
        if isPaused {
            return .rejected(.writesPaused)
        }

        // 2. No automatic write from unconfirmed or hallucinated output (§11).
        if record.source.isCategoricallyBlocked {
            return .rejected(.unverifiedModelOutput)
        }

        // 3. External partner data needs a declared retention purpose, carried
        //    as provenance (§11). No provenance → reject.
        if record.source == .externalPartner, record.provenanceIDs.isEmpty {
            return .rejected(.externalPartnerWithoutPurpose)
        }

        // 4. Health-derived context must never be written outside the Health
        //    domain (§11 health-to-chat / health-to-social; PrivacyGuard
        //    `.healthAndSocialStoresMustRemainSeparate`). A local health summary
        //    or any health-provenance record targeting chat/social/etc. is
        //    rejected outright.
        if record.domain != .health,
           record.derivedFromDomain == .health || record.source == .localHealthSummary {
            return .rejected(.healthDerivedCrossDomain)
        }

        // 5. Sensitive content belongs only in the Health domain in v1 (§11 —
        //    sensitive context outside domain policy).
        if record.sensitivity == .sensitive, record.domain != .health {
            return .rejected(.sensitiveOutsideDomain)
        }

        // 6. Allowed write.
        return .approved
    }
}

/// The outcome of evaluating a proposed write. Exactly one per record.
enum MemoryWriteDecision: Hashable, Sendable {
    case approved
    case rejected(MemoryWriteRejection)

    /// `true` only for an approved write.
    var isApproved: Bool {
        if case .approved = self { return true }
        return false
    }

    /// The rejection reason, if rejected.
    var rejection: MemoryWriteRejection? {
        if case .rejected(let reason) = self { return reason }
        return nil
    }
}

/// Why a write was rejected (§11).
enum MemoryWriteRejection: String, Codable, Hashable, Sendable, CaseIterable {
    /// Memory writes are paused by the user.
    case writesPaused
    /// Source was an unconfirmed plan or a model hallucination.
    case unverifiedModelOutput
    /// External partner data arrived without a declared retention purpose.
    case externalPartnerWithoutPurpose
    /// Health-derived context tried to land in a non-Health domain.
    case healthDerivedCrossDomain
    /// Sensitive content tried to land outside the Health domain.
    case sensitiveOutsideDomain
}

extension MemoryWriteRejection {
    /// The PrivacyGuard rule a cross-domain rejection enforces, so callers can
    /// surface the canonical reason without re-deriving policy. `nil` for
    /// non-privacy rejections (pause / unverified / missing purpose).
    var privacyRule: PrivacyGuard.RuleID? {
        switch self {
        case .healthDerivedCrossDomain, .sensitiveOutsideDomain:
            return .healthAndSocialStoresMustRemainSeparate
        case .writesPaused, .unverifiedModelOutput, .externalPartnerWithoutPurpose:
            return nil
        }
    }
}
