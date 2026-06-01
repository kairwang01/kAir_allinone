//
//  MemoryWritePolicyTests.swift
//  kAirTests
//
//  A4 memory facade (kair-ai-model-memory-v1.md §11 write policy). Coverage:
//  allowed vs blocked write sources, external-partner retention purpose, the
//  blocked sensitive / health-derived cross-domain writes, pause-rejects-writes,
//  and the `MemoryStore` write / delete / pause round-trips.
//

import XCTest
@testable import kAir

final class MemoryWritePolicyTests: XCTestCase {

    // MARK: - Allowed write sources (§11)

    func test_policy_allowedSources_areApproved() {
        let cases: [(MemorySource, MemoryDomain, MemorySensitivity)] = [
            (.explicitUserSave, .chat, .general),
            (.completedActionReceipt, .capability, .general),
            (.stablePreference, .chat, .personal),
            (.userSettingChange, .commerce, .general),
            (.localHealthSummary, .health, .sensitive),   // health summary, in Health
        ]
        for (source, domain, sensitivity) in cases {
            let record = Self.record(domain: domain, source: source, sensitivity: sensitivity)
            XCTAssertEqual(
                MemoryWritePolicy.evaluate(record, isPaused: false),
                .approved,
                "\(source) in \(domain) should be approved"
            )
        }
    }

    // MARK: - Categorically blocked sources (§11)

    func test_policy_unverifiedSources_areRejected() {
        for source in [MemorySource.modelHallucination, .unconfirmedPlan] {
            let record = Self.record(domain: .chat, source: source)
            XCTAssertEqual(
                MemoryWritePolicy.evaluate(record, isPaused: false),
                .rejected(.unverifiedModelOutput),
                "\(source) must be rejected as unverified"
            )
        }
    }

    // MARK: - External partner retention purpose (§11)

    func test_policy_externalPartnerWithoutProvenance_isRejected() {
        let record = Self.record(domain: .capability, source: .externalPartner, provenanceIDs: [])
        XCTAssertEqual(
            MemoryWritePolicy.evaluate(record, isPaused: false),
            .rejected(.externalPartnerWithoutPurpose)
        )
    }

    func test_policy_externalPartnerWithProvenance_isApproved() {
        let record = Self.record(
            domain: .capability,
            source: .externalPartner,
            provenanceIDs: ["partner-receipt-1"]
        )
        XCTAssertEqual(MemoryWritePolicy.evaluate(record, isPaused: false), .approved)
    }

    // MARK: - Blocked health-derived cross-domain writes (§11)

    func test_policy_healthDerivedContext_cannotEnterChatOrSocial() {
        for target in [MemoryDomain.chat, .social, .commerce, .capability, .model] {
            let record = Self.record(domain: target, derivedFromDomain: .health)
            XCTAssertEqual(
                MemoryWritePolicy.evaluate(record, isPaused: false),
                .rejected(.healthDerivedCrossDomain),
                "health-derived content must not be written to \(target)"
            )
        }
    }

    func test_policy_localHealthSummaryOutsideHealthDomain_isRejected() {
        let record = Self.record(domain: .chat, source: .localHealthSummary, sensitivity: .general)
        XCTAssertEqual(
            MemoryWritePolicy.evaluate(record, isPaused: false),
            .rejected(.healthDerivedCrossDomain)
        )
    }

    func test_policy_healthDerivedContent_intoHealthDomain_isApproved() {
        let record = Self.record(
            domain: .health,
            source: .localHealthSummary,
            sensitivity: .sensitive,
            derivedFromDomain: .health
        )
        XCTAssertEqual(MemoryWritePolicy.evaluate(record, isPaused: false), .approved)
    }

    // MARK: - Blocked sensitive cross-domain writes (§11)

    func test_policy_sensitiveContentOutsideHealth_isRejected() {
        let record = Self.record(domain: .chat, source: .explicitUserSave, sensitivity: .sensitive)
        XCTAssertEqual(
            MemoryWritePolicy.evaluate(record, isPaused: false),
            .rejected(.sensitiveOutsideDomain)
        )
    }

    func test_policy_sensitiveContentInsideHealth_isApproved() {
        let record = Self.record(domain: .health, source: .explicitUserSave, sensitivity: .sensitive)
        XCTAssertEqual(MemoryWritePolicy.evaluate(record, isPaused: false), .approved)
    }

    // MARK: - Pause rejects writes (§ memory ops)

    func test_policy_paused_rejectsOtherwiseValidWrite() {
        let record = Self.record(domain: .chat, source: .explicitUserSave)
        XCTAssertEqual(
            MemoryWritePolicy.evaluate(record, isPaused: true),
            .rejected(.writesPaused)
        )
    }

    // MARK: - Cross-domain rejections cite the release-blocking PrivacyGuard rule

    func test_rejection_crossDomainCitesSeparationRule() throws {
        XCTAssertEqual(
            MemoryWriteRejection.healthDerivedCrossDomain.privacyRule,
            .healthAndSocialStoresMustRemainSeparate
        )
        XCTAssertEqual(
            MemoryWriteRejection.sensitiveOutsideDomain.privacyRule,
            .healthAndSocialStoresMustRemainSeparate
        )
        XCTAssertNil(MemoryWriteRejection.writesPaused.privacyRule)
        XCTAssertNil(MemoryWriteRejection.unverifiedModelOutput.privacyRule)

        let guardrail = try XCTUnwrap(
            PrivacyGuard.guardrail(.healthAndSocialStoresMustRemainSeparate)
        )
        XCTAssertTrue(guardrail.releaseBlocking)
        guard case .deny = guardrail.defaultDecision else {
            return XCTFail("store-separation rule must default to deny")
        }
    }

    // MARK: - Store write / pause / delete round-trips (§ memory ops)

    @MainActor
    func test_store_writeApprovedPersists_blockedDoesNot() {
        let store = MemoryStore()

        let approved = store.write(Self.record(id: "ok", domain: .chat))
        XCTAssertTrue(approved.isApproved)
        XCTAssertNotNil(store.record(id: "ok"))
        XCTAssertEqual(store.recordCount, 1)

        let blocked = store.write(Self.record(id: "bad", domain: .chat, source: .modelHallucination))
        XCTAssertEqual(blocked.rejection, .unverifiedModelOutput)
        XCTAssertNil(store.record(id: "bad"))
        XCTAssertEqual(store.recordCount, 1)
    }

    @MainActor
    func test_store_pauseBlocksWrites_resumeAllows() {
        let store = MemoryStore()
        store.pauseWrites()
        XCTAssertTrue(store.isPaused)

        let paused = store.write(Self.record(id: "p", domain: .chat))
        XCTAssertEqual(paused.rejection, .writesPaused)
        XCTAssertEqual(store.recordCount, 0)

        store.resumeWrites()
        XCTAssertFalse(store.isPaused)
        XCTAssertTrue(store.write(Self.record(id: "p", domain: .chat)).isApproved)
        XCTAssertEqual(store.recordCount, 1)
    }

    @MainActor
    func test_store_writeUpsertsById() {
        let store = MemoryStore()
        store.write(Self.record(id: "x", domain: .chat, title: "first"))
        store.write(Self.record(id: "x", domain: .chat, title: "second"))
        XCTAssertEqual(store.recordCount, 1)
        XCTAssertEqual(store.record(id: "x")?.title, "second")
    }

    @MainActor
    func test_store_deleteRecord_domain_andAll() {
        let store = MemoryStore(seed: [
            Self.record(id: "c1", domain: .chat),
            Self.record(id: "c2", domain: .chat),
            Self.record(id: "m1", domain: .model),
        ])
        XCTAssertEqual(store.recordCount, 3)

        XCTAssertTrue(store.deleteRecord(id: "c1"))
        XCTAssertFalse(store.deleteRecord(id: "missing"))
        XCTAssertEqual(store.recordCount, 2)

        XCTAssertEqual(store.deleteDomain(.chat), 1)   // only c2 remains in chat
        XCTAssertEqual(store.recordCount, 1)
        XCTAssertTrue(store.records(in: .chat).isEmpty)

        store.deleteAll()
        XCTAssertEqual(store.recordCount, 0)
    }

    // MARK: - Fixture

    private static func record(
        id: String = "r1",
        domain: MemoryDomain,
        source: MemorySource = .explicitUserSave,
        sensitivity: MemorySensitivity = .general,
        title: String = "title",
        provenanceIDs: [String] = [],
        derivedFromDomain: MemoryDomain? = nil
    ) -> MemoryRecord {
        MemoryRecord(
            id: id,
            domain: domain,
            kind: "fact",
            title: title,
            body: "body",
            source: source,
            sensitivity: sensitivity,
            provenanceIDs: provenanceIDs,
            derivedFromDomain: derivedFromDomain
        )
    }
}
