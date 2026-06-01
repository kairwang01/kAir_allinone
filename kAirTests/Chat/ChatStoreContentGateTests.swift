//
//  ChatStoreContentGateTests.swift
//  kAirTests
//
//  Locks the v1 chat-content gate: a prompt aimed at a withheld surface
//  (Maps/Store/AI) must never surface that surface's copy or a placeholder tool
//  card — it answers on-device with no surface card. With every surface enabled
//  (the default) the full keyword content is unchanged.
//

import XCTest
@testable import kAir

@MainActor
final class ChatStoreContentGateTests: XCTestCase {

    func test_v1_withheldSurfacePrompt_answersOnDeviceWithoutCard() {
        let store = ChatStore(enabledSurfaces: [.chat, .health])
        store.submitPrompt("buy supplements for sleep", using: nil)   // Store intent
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertTrue(last?.text.localizedCaseInsensitiveContains("on-device") ?? false)
        XCTAssertTrue(last?.toolResults.isEmpty ?? false)            // no Store card
    }

    func test_v1_healthPrompt_stillAnswersNormally() {
        let store = ChatStore(enabledSurfaces: [.chat, .health])
        store.submitPrompt("how is my sleep", using: nil)            // Health is enabled
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        // Not the withheld-surface fallback — health content flows as normal.
        XCTAssertFalse(last?.text.localizedCaseInsensitiveContains("focused on your health and on-device questions in this version") ?? false)
    }

    func test_allSurfaces_storePrompt_keepsStoreCard() {
        let store = ChatStore()                                       // default = all
        store.submitPrompt("buy supplements for sleep", using: nil)
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertFalse(last?.toolResults.isEmpty ?? true)            // Store card preserved
    }

    /// Free-typed chit-chat (no recognized intent) hits the reply fall-through;
    /// in v1 it must not advertise a withheld surface or emit a placeholder card.
    func test_v1_freeTypedPrompt_hasNoWithheldSurfaceCopyOrCard() {
        let store = ChatStore(enabledSurfaces: [.chat, .health])
        store.submitPrompt("hello", using: nil)
        let last = store.session.messages.last
        let text = last?.text ?? ""
        XCTAssertFalse(text.contains("Maps"), text)
        XCTAssertFalse(text.contains("Store"), text)
        let cardTitles = (last?.toolResults ?? []).map(\.title)
        XCTAssertFalse(cardTitles.contains("Maps Surface"))
        XCTAssertFalse(cardTitles.contains("Store Curation"))
    }

    /// Regression for the greedy `contains("ai")` route: "explain" / "kair" must
    /// not classify a health prompt as the (withheld) AI surface and deflect it.
    func test_v1_healthPrompt_withAiSubstring_notDeflected() {
        let store = ChatStore(enabledSurfaces: [.chat, .health])
        store.submitPrompt("Explain my sleep trend", using: nil)
        let text = store.session.messages.last?.text ?? ""
        XCTAssertFalse(
            text.localizedCaseInsensitiveContains("focused on your health and on-device questions in this version"),
            "health prompt was wrongly deflected to the withheld-surface fallback"
        )
    }
}
