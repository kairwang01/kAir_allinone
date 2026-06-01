//
//  ChatStoreGenerationTests.swift
//  kAirTests
//
//  B6b — on-device chat reply generation wiring. Verifies the optional
//  `KAirTextGenerator` injection: no generator keeps the static baseline
//  (existing behavior), a generator replaces the reply text in place, and a
//  generation failure leaves the baseline intact.
//

import XCTest
@testable import kAir

final class ChatStoreGenerationTests: XCTestCase {

    @MainActor
    func test_submit_withoutGenerator_usesStaticBaseline() {
        let store = ChatStore()
        store.submitPrompt("hello there", using: nil)
        XCTAssertNil(store.pendingReplyGeneration)   // nothing kicked off
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertFalse(last?.text.isEmpty ?? true)   // static baseline reply
    }

    @MainActor
    func test_submit_withGenerator_replacesReplyText() async {
        let store = ChatStore(textGenerator: StubTextGenerator(output: "ON-DEVICE REPLY"))
        store.submitPrompt("hello there", using: nil)
        await store.pendingReplyGeneration?.value
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertEqual(last?.text, "ON-DEVICE REPLY")
    }

    @MainActor
    func test_submit_generatorFailure_keepsBaseline() async {
        let store = ChatStore(textGenerator: StubTextGenerator(output: nil))   // throws
        store.submitPrompt("hello there", using: nil)
        let baseline = store.session.messages.last?.text
        XCTAssertNotNil(baseline)
        await store.pendingReplyGeneration?.value
        XCTAssertEqual(store.session.messages.last?.text, baseline)   // unchanged
    }
}

private struct StubTextGenerator: KAirTextGenerator {
    let output: String?   // nil → throw

    func isAvailable() async -> Bool { true }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        guard let output else { throw KAirTextGeneratorError.generationFailed }
        return output
    }
}
