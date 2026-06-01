//
//  HealthMemoryIsolationTests.swift
//  kAirTests
//
//  A4 memory facade (kair-ai-model-memory-v1.md §12 retrieval policy;
//  PrivacyGuard `.healthAndSocialStoresMustRemainSeparate`). Coverage: the pure
//  domain-isolation rule, and `MemoryStore` retrieval proving Health memory is
//  never returned to general chat or social retrieval, that a Health request
//  receives only Health, plus scoping / sensitivity-cap / provenance / deleted.
//

import XCTest
@testable import kAir

final class HealthMemoryIsolationTests: XCTestCase {

    // MARK: - Pure domain isolation rule (§12)

    func test_domain_healthIsBidirectionallyIsolated() {
        // Health ↔ Health only.
        XCTAssertTrue(MemoryDomain.health.isRetrievable(by: .health))
        // Health records are never retrievable by any non-health requester.
        for requester in MemoryDomain.allCases where requester != .health {
            XCTAssertFalse(
                MemoryDomain.health.isRetrievable(by: requester),
                "health must not be retrievable by \(requester)"
            )
        }
        // A health request retrieves nothing from any non-health domain.
        for stored in MemoryDomain.allCases where stored != .health {
            XCTAssertFalse(
                stored.isRetrievable(by: .health),
                "\(stored) must not be retrievable by a health request"
            )
        }
    }

    func test_domain_retrievalIsScopedToSameDomain() {
        // Across the full matrix, retrieval is permitted only same-domain.
        for stored in MemoryDomain.allCases {
            for requester in MemoryDomain.allCases {
                XCTAssertEqual(
                    stored.isRetrievable(by: requester),
                    stored == requester,
                    "\(stored) retrievable-by \(requester) must equal same-domain"
                )
            }
        }
        XCTAssertTrue(MemoryDomain.health.isHealthIsolated)
        XCTAssertFalse(MemoryDomain.chat.isHealthIsolated)
    }

    // MARK: - Store: general chat / social can never read Health (§12)

    @MainActor
    func test_store_chatRequestNeverReturnsHealth() {
        let store = Self.seededStore()
        let result = store.retrieve(MemoryRetrievalRequest(domain: .chat))
        XCTAssertFalse(result.records.isEmpty)
        XCTAssertTrue(
            result.records.allSatisfy { $0.domain == .chat },
            "a chat request must return only chat records"
        )
        XCTAssertFalse(result.records.contains { $0.domain == .health })
    }

    @MainActor
    func test_store_socialRequestNeverReturnsHealth() {
        let store = Self.seededStore()
        let result = store.retrieve(MemoryRetrievalRequest(domain: .social))
        XCTAssertTrue(result.records.allSatisfy { $0.domain == .social })
        XCTAssertFalse(result.records.contains { $0.domain == .health })
    }

    // MARK: - Store: a Health request receives only Health (§12)

    @MainActor
    func test_store_healthRequestReturnsOnlyHealth() {
        let store = Self.seededStore()
        let result = store.retrieve(
            MemoryRetrievalRequest(domain: .health, sensitivityLimit: .sensitive)
        )
        XCTAssertFalse(result.records.isEmpty)
        XCTAssertTrue(
            result.records.allSatisfy { $0.domain == .health },
            "a health request must return only health records"
        )
    }

    // MARK: - Store: provenance + reason (§12)

    @MainActor
    func test_store_retrievalReturnsProvenanceAndReason() {
        let store = MemoryStore(seed: [
            Self.record(id: "c1", domain: .chat, provenanceIDs: ["thread-1", "thread-2"]),
        ])
        let result = store.retrieve(MemoryRetrievalRequest(domain: .chat))
        XCTAssertEqual(result.reason, .domainScoped)
        XCTAssertEqual(result.provenanceIDs, ["thread-1", "thread-2"])

        let empty = store.retrieve(MemoryRetrievalRequest(domain: .commerce))
        XCTAssertEqual(empty.reason, .empty)
        XCTAssertTrue(empty.records.isEmpty)
    }

    // MARK: - Store: sensitivity cap + deleted + maxRecords (§12)

    @MainActor
    func test_store_sensitivityLimitExcludesAboveCap() {
        let store = MemoryStore(seed: [
            Self.record(id: "h-low", domain: .health, sensitivity: .general),
            Self.record(id: "h-high", domain: .health, sensitivity: .sensitive),
        ])
        let capped = store.retrieve(
            MemoryRetrievalRequest(domain: .health, sensitivityLimit: .general)
        )
        XCTAssertEqual(capped.records.map(\.id), ["h-low"])
    }

    @MainActor
    func test_store_excludesUserDeletedRecords() {
        let store = MemoryStore(seed: [
            Self.record(id: "live", domain: .chat),
            Self.record(id: "gone", domain: .chat, userDeleted: true),
        ])
        let result = store.retrieve(MemoryRetrievalRequest(domain: .chat))
        XCTAssertEqual(result.records.map(\.id), ["live"])
    }

    @MainActor
    func test_store_excludesExpiredRecords() {
        let store = MemoryStore(seed: [
            Self.record(
                id: "expired",
                domain: .chat,
                expiresAt: Date(timeIntervalSinceNow: -60)
            ),
            Self.record(
                id: "live",
                domain: .chat,
                expiresAt: Date(timeIntervalSinceNow: 60)
            ),
        ])
        let result = store.retrieve(MemoryRetrievalRequest(domain: .chat))
        XCTAssertEqual(result.records.map(\.id), ["live"])
    }

    @MainActor
    func test_store_respectsMaxRecords() {
        let store = MemoryStore(seed: [
            Self.record(id: "a", domain: .chat),
            Self.record(id: "b", domain: .chat),
            Self.record(id: "c", domain: .chat),
        ])
        let result = store.retrieve(MemoryRetrievalRequest(domain: .chat, maxRecords: 2))
        XCTAssertEqual(result.records.count, 2)
    }

    // MARK: - Fixtures

    /// A store seeded with one record in each domain (health is `.sensitive`).
    @MainActor
    private static func seededStore() -> MemoryStore {
        MemoryStore(seed: MemoryDomain.allCases.map { domain in
            record(
                id: "\(domain.rawValue)-1",
                domain: domain,
                sensitivity: domain == .health ? .sensitive : .general,
                provenanceIDs: ["\(domain.rawValue)-src"]
            )
        })
    }

    private static func record(
        id: String,
        domain: MemoryDomain,
        sensitivity: MemorySensitivity = .general,
        provenanceIDs: [String] = [],
        userDeleted: Bool = false,
        expiresAt: Date? = nil
    ) -> MemoryRecord {
        MemoryRecord(
            id: id,
            domain: domain,
            kind: "fact",
            title: "title",
            body: "body",
            source: domain == .health ? .localHealthSummary : .explicitUserSave,
            sensitivity: sensitivity,
            provenanceIDs: provenanceIDs,
            derivedFromDomain: domain == .health ? .health : nil,
            expiresAt: expiresAt,
            userDeleted: userDeleted
        )
    }
}
