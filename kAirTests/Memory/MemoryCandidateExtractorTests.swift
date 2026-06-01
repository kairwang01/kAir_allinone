//
//  MemoryCandidateExtractorTests.swift
//  kAirTests
//
//  Explicit user-save extraction coverage for the local memory boundary.
//

import XCTest
@testable import kAir

final class MemoryCandidateExtractorTests: XCTestCase {

    func test_extractExplicitEnglishSaveBuildsPolicyApprovedChatRecord() throws {
        let now = Date(timeIntervalSince1970: 1_780_300_800)

        let record = try XCTUnwrap(
            MemoryCandidateExtractor.extractExplicitSave(
                from: "Remember that I prefer concise replies.",
                now: now
            )
        )

        XCTAssertEqual(record.domain, .chat)
        XCTAssertEqual(record.kind, "explicit_user_memory")
        XCTAssertEqual(record.body, "I prefer concise replies")
        XCTAssertEqual(record.source, .explicitUserSave)
        XCTAssertEqual(record.sensitivity, .personal)
        XCTAssertEqual(record.createdAt, now)
        XCTAssertEqual(MemoryWritePolicy.evaluate(record, isPaused: false), .approved)
    }

    @MainActor
    func test_extractExplicitChineseSaveCanWriteThroughStore() throws {
        let record = try XCTUnwrap(
            MemoryCandidateExtractor.extractExplicitSave(from: "请记住我喜欢先看结论")
        )

        XCTAssertEqual(record.domain, .chat)
        XCTAssertEqual(record.body, "我喜欢先看结论")

        let store = MemoryStore()
        XCTAssertTrue(store.write(record).isApproved)
        XCTAssertEqual(store.record(id: record.id)?.body, "我喜欢先看结论")
    }

    func test_nonExplicitPromptDoesNotCreateMemoryCandidate() {
        XCTAssertNil(
            MemoryCandidateExtractor.extractExplicitSave(from: "Maybe answer shorter next time.")
        )
    }

    func test_healthMemoryIsClassifiedIntoHealthDomain() throws {
        let record = try XCTUnwrap(
            MemoryCandidateExtractor.extractExplicitSave(
                from: "Remember that my blood pressure medication changed."
            )
        )

        XCTAssertEqual(record.domain, .health)
        XCTAssertEqual(record.sensitivity, .sensitive)
        XCTAssertEqual(record.derivedFromDomain, .health)
        XCTAssertEqual(MemoryWritePolicy.evaluate(record, isPaused: false), .approved)
    }
}
