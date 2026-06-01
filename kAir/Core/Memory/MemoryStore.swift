//
//  MemoryStore.swift
//  kAir
//
//  In-memory facade for local-first agent memory.
//

import Foundation
import Observation

// Architecture note:
// `MemoryStore` is the facade for local-first agent memory. It exposes
// write / retrieve / delete / pause operations while hiding the storage
// backend. This A4 implementation is in-memory only
// (kair-ai-model-memory-v1.md §9–§12); SQLite/GRDB, FTS5, and a vector index
// come later behind the same facade (§13).
//
// Enforced here:
// - Writes go through `MemoryWritePolicy` (§11) — no automatic write from
//   unconfirmed/hallucinated output, no health-derived context into chat/social.
// - Retrieval is scoped + health-isolated (§12) — general chat and social
//   retrieval can never return Health memory.
// - Writes can be paused without breaking chat; records can be deleted one by
//   one, by domain, or entirely.
//
// NOT wired (round constraints): SQLite/GRDB, embeddings/vector index, remote
// services, iCloud for health.

/// A scoped memory retrieval request (§12). `maxTokens` is part of the contract
/// for when a tokenizer/budgeter lands; this in-memory store caps by
/// `maxRecords` and the `sensitivityLimit`.
struct MemoryRetrievalRequest: Hashable, Sendable {
    let domain: MemoryDomain
    let purpose: String
    let query: String
    let maxRecords: Int
    let maxTokens: Int
    let sensitivityLimit: MemorySensitivity

    init(
        domain: MemoryDomain,
        purpose: String = "",
        query: String = "",
        maxRecords: Int = 20,
        maxTokens: Int = 4000,
        sensitivityLimit: MemorySensitivity = .sensitive
    ) {
        self.domain = domain
        self.purpose = purpose
        self.query = query
        self.maxRecords = maxRecords
        self.maxTokens = maxTokens
        self.sensitivityLimit = sensitivityLimit
    }
}

/// Why a retrieval returned what it did (§12 — retrieval returns provenance and
/// reason).
enum MemoryRetrievalReason: String, Codable, Hashable, Sendable, CaseIterable {
    /// Records scoped to the requested domain (Health isolation applied).
    case domainScoped
    /// Nothing matched the scope.
    case empty
}

/// The result of a scoped retrieval (§12). Carries provenance + reason.
struct MemoryRetrievalResult: Hashable, Sendable {
    let records: [MemoryRecord]
    let reason: MemoryRetrievalReason

    /// Flattened provenance of the returned records (§12).
    var provenanceIDs: [String] {
        records.flatMap(\.provenanceIDs)
    }
}

/// Owns local memory records in-memory. Observable so a future memory-management
/// screen can bind to it. All write admission + retrieval isolation is enforced
/// here through `MemoryWritePolicy` and `MemoryDomain.isRetrievable(by:)`.
@MainActor
@Observable
final class MemoryStore {
    /// Whether memory writes are currently paused (§ memory ops).
    private(set) var isPaused: Bool

    /// The in-memory record store (no SQLite/GRDB in this round).
    private var storage: [MemoryRecord]

    init(seed: [MemoryRecord] = [], isPaused: Bool = false) {
        self.storage = seed
        self.isPaused = isPaused
    }

    // MARK: - Write (policy-gated, §11)

    /// Admit a record through `MemoryWritePolicy` and persist it only if
    /// approved. Returns the decision so callers can surface a reason. A record
    /// with an existing id is updated in place; a rejected write changes
    /// nothing.
    @discardableResult
    func write(_ record: MemoryRecord) -> MemoryWriteDecision {
        let decision = MemoryWritePolicy.evaluate(record, isPaused: isPaused)
        guard decision.isApproved else { return decision }

        if let index = storage.firstIndex(where: { $0.id == record.id }) {
            storage[index] = record
        } else {
            storage.append(record)
        }
        return decision
    }

    // MARK: - Retrieve (scoped + health-isolated, §12)

    /// Retrieve records for a scoped request. Health records are returned only
    /// to a Health request, and a Health request receives only Health records
    /// (§12; release-blocking). Deleted records, expired records, and records
    /// above the sensitivity cap are excluded. Caps to `maxRecords`.
    func retrieve(_ request: MemoryRetrievalRequest) -> MemoryRetrievalResult {
        let now = Date()
        let matched = storage.filter { record in
            guard record.userDeleted == false else { return false }
            if let expiresAt = record.expiresAt, expiresAt <= now { return false }
            // §12 isolation: stored domain must permit return to the requester.
            guard record.domain.isRetrievable(by: request.domain) else { return false }
            // §12 sensitivity cap.
            guard record.sensitivity <= request.sensitivityLimit else { return false }
            return true
        }

        let limit = max(0, request.maxRecords)
        let limited = Array(matched.prefix(limit))
        return MemoryRetrievalResult(
            records: limited,
            reason: limited.isEmpty ? .empty : .domainScoped
        )
    }

    // MARK: - Pause (§ memory ops)

    /// Pause memory writes. Retrieval and chat keep working; new writes are
    /// rejected with `.writesPaused`.
    func pauseWrites() {
        isPaused = true
    }

    /// Resume memory writes.
    func resumeWrites() {
        isPaused = false
    }

    // MARK: - Delete (§ memory ops)

    /// Delete a single record by id. Returns `true` if a record was removed.
    @discardableResult
    func deleteRecord(id: String) -> Bool {
        guard let index = storage.firstIndex(where: { $0.id == id }) else { return false }
        storage.remove(at: index)
        return true
    }

    /// Delete every record in a domain. Returns the number removed.
    @discardableResult
    func deleteDomain(_ domain: MemoryDomain) -> Int {
        let before = storage.count
        storage.removeAll { $0.domain == domain }
        return before - storage.count
    }

    /// Delete all records across all domains.
    func deleteAll() {
        storage.removeAll()
    }

    // MARK: - Inspection (for the future memory-management screen)

    /// Total stored records (including soft-deleted).
    var recordCount: Int {
        storage.count
    }

    /// All records in a domain, in insertion order.
    func records(in domain: MemoryDomain) -> [MemoryRecord] {
        storage.filter { $0.domain == domain }
    }

    /// A record by id, if present.
    func record(id: String) -> MemoryRecord? {
        storage.first { $0.id == id }
    }
}
