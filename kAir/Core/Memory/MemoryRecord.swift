//
//  MemoryRecord.swift
//  kAir
//
//  Pure value contract for a single local memory record.
//
//  A4 memory facade value contracts (kair-ai-model-memory-v1.md §10 record
//  shape). Foundation only. Records must be inspectable (§10) — a future
//  memory-management screen can render them without decoding model internals.
//

import Foundation

/// How sensitive a record's content is (§10 sensitivity). Ordered for the
/// retrieval `sensitivityLimit` cap (§12): general < personal < sensitive.
/// Health-grade content is `.sensitive` and belongs only in the Health domain.
enum MemorySensitivity: String, Codable, Hashable, Sendable, CaseIterable {
    case general
    case personal
    case sensitive

    /// Ordered severity used for `sensitivityLimit` comparisons.
    var rank: Int {
        switch self {
        case .general:   return 0
        case .personal:  return 1
        case .sensitive: return 2
        }
    }
}

extension MemorySensitivity: Comparable {
    static func < (lhs: MemorySensitivity, rhs: MemorySensitivity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Where a memory write originated (§11 write sources). The write policy
/// approves the allowed sources and rejects the blocked ones.
enum MemorySource: String, Codable, Hashable, Sendable, CaseIterable {
    /// Allowed (§11): the user deliberately saved this.
    case explicitUserSave
    /// Allowed (§11): a completed, confirmed action receipt.
    case completedActionReceipt
    /// Allowed (§11): a preference observed stable across interactions.
    case stablePreference
    /// Allowed (§11): a user setting change.
    case userSettingChange
    /// Allowed (§11): a local health summary generated inside the Health domain.
    case localHealthSummary
    /// Conditionally allowed (§11): external partner data — only with a
    /// declared retention purpose (carried as provenance).
    case externalPartner
    /// Blocked (§11): output from an unconfirmed plan.
    case unconfirmedPlan
    /// Blocked (§11): a failed model hallucination.
    case modelHallucination

    /// Sources that are categorically forbidden regardless of domain (§11 —
    /// no automatic write from unconfirmed/hallucinated model output).
    var isCategoricallyBlocked: Bool {
        self == .unconfirmedPlan || self == .modelHallucination
    }
}

/// Retention intent for a record (§10 retentionPolicy).
enum MemoryRetention: String, Codable, Hashable, Sendable, CaseIterable {
    case ephemeral
    case session
    case persistent
}

/// Embedding/index status (§10 embeddingState). In v1 this is always `.none`:
/// embeddings + vector index are explicitly NOT wired (§13 is a later step).
enum MemoryEmbeddingState: String, Codable, Hashable, Sendable, CaseIterable {
    case none
    case pending
    case indexed
}

/// One local memory record (§10). Codable + inspectable; never holds raw
/// secrets or API keys.
struct MemoryRecord: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let domain: MemoryDomain
    let kind: String
    let title: String
    let body: String
    let source: MemorySource
    /// Upstream record/event ids this was derived from (§10 provenanceIDs).
    /// Also doubles as the declared retention purpose for `externalPartner`.
    let provenanceIDs: [String]
    /// Domain-level provenance: the domain this content was derived from, if
    /// any. Used to block health-derived context leaking into chat/social
    /// (§11), independent of the `sensitivity` cap.
    let derivedFromDomain: MemoryDomain?
    let createdAt: Date
    let updatedAt: Date
    let expiresAt: Date?
    let sensitivity: MemorySensitivity
    let retentionPolicy: MemoryRetention
    let embeddingState: MemoryEmbeddingState
    let userEditable: Bool
    var userDeleted: Bool
    let confidence: Double

    init(
        id: String,
        domain: MemoryDomain,
        kind: String,
        title: String,
        body: String,
        source: MemorySource,
        sensitivity: MemorySensitivity,
        provenanceIDs: [String] = [],
        derivedFromDomain: MemoryDomain? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expiresAt: Date? = nil,
        retentionPolicy: MemoryRetention = .persistent,
        embeddingState: MemoryEmbeddingState = .none,
        userEditable: Bool = true,
        userDeleted: Bool = false,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.domain = domain
        self.kind = kind
        self.title = title
        self.body = body
        self.source = source
        self.sensitivity = sensitivity
        self.provenanceIDs = provenanceIDs
        self.derivedFromDomain = derivedFromDomain
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.retentionPolicy = retentionPolicy
        self.embeddingState = embeddingState
        self.userEditable = userEditable
        self.userDeleted = userDeleted
        self.confidence = confidence
    }
}
