//
//  MemoryConsolidationPolicyTests.swift
//  kAirTests
//
//  Reserved interface R5 (kair-architecture-redesign-v2.md §5.5): co-evolving /
//  decaying memory consolidation. Coverage: keep / summarize / decay / supersede,
//  pinned-record protection, and the health-isolation guard on cross-domain
//  supersede. Pure rules; caller-injected `now`.
//

import XCTest
@testable import kAir

final class MemoryConsolidationPolicyTests: XCTestCase {

    func test_freshRecord_isKept() {
        let record = Self.record(updatedAt: Self.now, confidence: 0.9)
        XCTAssertEqual(MemoryConsolidationPolicy.evaluate(record, context: Self.context()), .keep)
    }

    func test_staleLowConfidenceEditable_decays() {
        let record = Self.record(updatedAt: Self.old, confidence: 0.1, userEditable: true)
        XCTAssertEqual(MemoryConsolidationPolicy.evaluate(record, context: Self.context()), .decay)
    }

    func test_staleHighConfidence_summarizes() {
        let record = Self.record(updatedAt: Self.old, confidence: 0.9)
        XCTAssertEqual(MemoryConsolidationPolicy.evaluate(record, context: Self.context()), .summarize)
    }

    func test_staleLowConfidenceButPinned_summarizesNotDecays() {
        let record = Self.record(updatedAt: Self.old, confidence: 0.1, userEditable: false)
        XCTAssertEqual(MemoryConsolidationPolicy.evaluate(record, context: Self.context()), .summarize)
    }

    func test_supersedeSameDomain_coEvolves() {
        let record = Self.record(domain: .chat, updatedAt: Self.now)
        let context = Self.context(supersedesID: "note-1", supersedesDomain: .chat)
        XCTAssertEqual(
            MemoryConsolidationPolicy.evaluate(record, context: context),
            .supersede(existingID: "note-1")
        )
    }

    func test_supersedeCrossDomain_isRefused() {
        // A chat record must not supersede a health note (domain isolation).
        let record = Self.record(domain: .chat, updatedAt: Self.now, confidence: 0.9)
        let context = Self.context(supersedesID: "health-note", supersedesDomain: .health)
        XCTAssertEqual(MemoryConsolidationPolicy.evaluate(record, context: context), .keep)
    }

    func test_canConsolidate_sameDomainOnly_healthIsolated() {
        XCTAssertTrue(MemoryConsolidationPolicy.canConsolidate(recordDomain: .chat, withNoteIn: .chat))
        XCTAssertFalse(MemoryConsolidationPolicy.canConsolidate(recordDomain: .chat, withNoteIn: .health))
        XCTAssertFalse(MemoryConsolidationPolicy.canConsolidate(recordDomain: .health, withNoteIn: .chat))
        XCTAssertTrue(MemoryConsolidationPolicy.canConsolidate(recordDomain: .health, withNoteIn: .health))
    }

    // MARK: - Fixtures

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let old = Date(timeIntervalSince1970: 1_600_000_000)   // ~3 years earlier

    private static func context(
        supersedesID: String? = nil,
        supersedesDomain: MemoryDomain? = nil
    ) -> MemoryConsolidationContext {
        MemoryConsolidationContext(
            now: now,
            supersedesID: supersedesID,
            supersedesDomain: supersedesDomain
        )
    }

    private static func record(
        domain: MemoryDomain = .chat,
        updatedAt: Date,
        confidence: Double = 0.9,
        userEditable: Bool = true
    ) -> MemoryRecord {
        MemoryRecord(
            id: "r",
            domain: domain,
            kind: "fact",
            title: "t",
            body: "b",
            source: .explicitUserSave,
            sensitivity: .general,
            updatedAt: updatedAt,
            userEditable: userEditable,
            confidence: confidence
        )
    }
}
