//
//  MemoryDomain.swift
//  kAir
//
//  Pure value contract for the local memory domains + the retrieval-isolation
//  rule.
//
//  A4 memory facade value contracts (kair-ai-model-memory-v1.md §9 domains,
//  §12 retrieval policy). Foundation only — in-memory, no SQLite/GRDB, no
//  embeddings/vector index, no remote services.
//

import Foundation

/// The domains local memory is partitioned into (§9). Each domain is stored
/// and retrieved separately; Health is the hard-isolated domain (§9 "never"
/// remote; PrivacyGuard `.healthAndSocialStoresMustRemainSeparate`).
enum MemoryDomain: String, Codable, Hashable, Sendable, CaseIterable {
    /// Thread summaries, user preferences, active tasks (§9).
    case chat
    /// Local health trends, coverage, user-entered notes — local-only (§9).
    case health
    /// Installed models, benchmark metrics, failure diagnostics (§9).
    case model
    /// Action receipts, route outcomes, partner errors (§9).
    case capability
    /// Friend metadata, invite state — never health (§9).
    case social
    /// Purchases, entitlement state (§9).
    case commerce

    /// Health is the isolated domain: its records must never reach general chat
    /// or social retrieval (§9/§12; PrivacyGuard
    /// `.healthAndSocialStoresMustRemainSeparate`).
    var isHealthIsolated: Bool {
        self == .health
    }

    /// Whether a record stored in `self` may be returned to a request from
    /// `requester` (§12). Retrieval is domain-scoped, and Health is
    /// bidirectionally isolated:
    ///   - Health records are returned ONLY to a Health request.
    ///   - A Health request receives ONLY Health records.
    /// The Health branch is written explicitly (not folded into the
    /// same-domain check) so it remains a release-blocking guarantee even if
    /// cross-domain retrieval for non-health domains is ever relaxed.
    func isRetrievable(by requester: MemoryDomain) -> Bool {
        if self == .health || requester == .health {
            return self == .health && requester == .health
        }
        return self == requester
    }
}
