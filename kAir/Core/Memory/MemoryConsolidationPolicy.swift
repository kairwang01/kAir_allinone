//
//  MemoryConsolidationPolicy.swift
//  kAir
//
//  Pure consolidation / reflection rules for local memory.
//
//  Reserved interface R5 of `Docs/architecture/kair-architecture-redesign-v2.md`
//  §5.5. A-MEM (arXiv:2502.12110) shows memory should co-evolve (update existing
//  notes), Generative Agents reflect/summarize, and MemoryBank decays unused
//  records. This is a pure decision function the `MemoryStore` can call — no
//  background scheduler, no model, no network. Stays domain-isolated: health
//  consolidation never reads or edits non-health notes (PrivacyGuard
//  `.healthAndSocialStoresMustRemainSeparate`), reusing
//  `MemoryDomain.isRetrievable(by:)`.
//

import Foundation

/// What consolidation recommends for a record.
enum MemoryConsolidationAction: Hashable, Sendable {
    /// Leave as-is.
    case keep
    /// Fold into a domain-scoped summary (Generative-Agents reflection).
    case summarize
    /// Co-evolve: update an existing same-domain note (A-MEM).
    case supersede(existingID: String)
    /// Forget: stale + low-confidence + not user-pinned (MemoryBank decay).
    case decay
}

/// Inputs for one consolidation decision. `now` is caller-injected for
/// determinism (no clock read).
struct MemoryConsolidationContext: Hashable, Sendable {
    let now: Date
    /// Age past which a record is considered stale.
    let staleAfter: TimeInterval
    /// Below this confidence, a stale unpinned record decays.
    let minConfidence: Double
    /// A prior note this record updates (co-evolution), if any.
    let supersedesID: String?
    /// The domain of the superseded note, for the isolation guard.
    let supersedesDomain: MemoryDomain?

    init(
        now: Date,
        staleAfter: TimeInterval = 60 * 60 * 24 * 30,   // 30 days
        minConfidence: Double = 0.3,
        supersedesID: String? = nil,
        supersedesDomain: MemoryDomain? = nil
    ) {
        self.now = now
        self.staleAfter = staleAfter
        self.minConfidence = minConfidence
        self.supersedesID = supersedesID
        self.supersedesDomain = supersedesDomain
    }
}

/// Pure consolidation policy.
enum MemoryConsolidationPolicy {
    static func evaluate(
        _ record: MemoryRecord,
        context: MemoryConsolidationContext
    ) -> MemoryConsolidationAction {
        // Co-evolution (A-MEM): update an existing note — but ONLY when it is in
        // a domain this record may consolidate with (health stays isolated).
        if let supersedesID = context.supersedesID,
           let supersedesDomain = context.supersedesDomain,
           canConsolidate(recordDomain: record.domain, withNoteIn: supersedesDomain) {
            return .supersede(existingID: supersedesID)
        }

        let age = context.now.timeIntervalSince(record.updatedAt)
        let isStale = age >= context.staleAfter

        guard isStale else {
            return .keep
        }

        // Decay only unpinned, low-confidence records (user-editable == not pinned
        // by an explicit save the user controls).
        if record.confidence < context.minConfidence, record.userEditable {
            return .decay
        }

        // Stale but still trusted / pinned → fold into a summary, never forget.
        return .summarize
    }

    /// Whether a record in `recordDomain` may be consolidated with a note in
    /// `noteDomain`. Reuses the §12 isolation rule: same-domain only, and Health
    /// is bidirectionally isolated.
    static func canConsolidate(
        recordDomain: MemoryDomain,
        withNoteIn noteDomain: MemoryDomain
    ) -> Bool {
        recordDomain.isRetrievable(by: noteDomain)
    }
}
