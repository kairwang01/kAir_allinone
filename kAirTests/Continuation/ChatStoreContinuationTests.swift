//
//  ChatStoreContinuationTests.swift
//  kAirTests
//
//  Main D transcript-projection tests for
//  `ChatStore.recordContinuation(_:)`.
//
//  Per `Contracts/UX/continuation-runtime-v1.md` §8.1 (projection
//  option b): `renderEligible == true` events project to exactly one
//  `.assistant` `ConversationMessage` carrying the typed
//  `continuationEvent` field; `renderEligible == false` events
//  produce zero session messages (silent transcript).
//
//  Includes an end-to-end test that wires `AppBootstrap` →
//  `continuationHandler` → `ChatStore` and asserts the full path:
//  the bootstrap-built event lands in the chat transcript only for
//  render-eligible outcomes.
//

import XCTest
@testable import kAir

@MainActor
final class ChatStoreContinuationTests: XCTestCase {

    // MARK: - Direct projection (§8.1 option b)

    func test_recordContinuation_renderEligible_appendsAssistantMessage() {
        let store = ChatStore()
        let before = store.session.messages.count

        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        store.recordContinuation(event)

        XCTAssertEqual(store.session.messages.count, before + 1)
        let last = store.session.messages.last!
        XCTAssertEqual(last.role, .assistant)
        XCTAssertNotNil(last.continuationEvent)
        XCTAssertEqual(last.continuationEvent?.outcome, .completion)
        XCTAssertEqual(last.continuationEvent?.surface, .maps)
    }

    func test_recordContinuation_abandon_appendsAssistantMessage() {
        let store = ChatStore()
        let before = store.session.messages.count

        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .abandon)
        store.recordContinuation(event)

        XCTAssertEqual(store.session.messages.count, before + 1)
        XCTAssertEqual(store.session.messages.last?.continuationEvent?.outcome, .abandon)
    }

    func test_recordContinuation_dismiss_appendsNothing() {
        let store = ChatStore()
        let before = store.session.messages.count

        let event = ContinuationProjection.makeEvent(surface: .store, outcome: .dismiss)
        store.recordContinuation(event)

        XCTAssertEqual(store.session.messages.count, before)
    }

    func test_recordContinuation_acceptNoEntry_appendsNothing() {
        let store = ChatStore()
        let before = store.session.messages.count

        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .acceptNoEntry)
        store.recordContinuation(event)

        XCTAssertEqual(store.session.messages.count, before)
    }

    func test_recordContinuation_multipleRenderEligible_appendsInOrder() {
        let store = ChatStore()
        let before = store.session.messages.count

        let e1 = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        let e2 = ContinuationProjection.makeEvent(surface: .ai, outcome: .abandon)
        store.recordContinuation(e1)
        store.recordContinuation(e2)

        XCTAssertEqual(store.session.messages.count, before + 2)
        let lastTwo = store.session.messages.suffix(2)
        XCTAssertEqual(lastTwo.first?.continuationEvent?.outcome, .completion)
        XCTAssertEqual(lastTwo.last?.continuationEvent?.outcome, .abandon)
    }

    func test_recordContinuation_messageText_usesSummaryText() {
        let store = ChatStore()
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        store.recordContinuation(event)

        let assistantText = store.session.messages.last?.text ?? ""
        XCTAssertEqual(assistantText, event.summary?.summary)
    }

    // MARK: - End-to-end: composition root → handler → store

    func test_compositionRoot_completionReachesChatStoreTranscript() async throws {
        // Mirror what `ChatHomeView.onAppear` does: install the
        // continuation handler so the bootstrap-built event lands in
        // the chat transcript.
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        let store = ChatStore(
            feedbackRuntime: bootstrap.feedbackRuntime,
            completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
            telemetryEmitter: bootstrap.telemetryEmitter,
            capabilityRegistry: bootstrap.capabilityRegistry
        )
        bootstrap.continuationHandler = { event in
            store.recordContinuation(event)
        }
        await store.pendingCapabilityRefresh?.value

        let before = store.session.messages.count
        bootstrap.openSurface(.maps)
        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value

        // Runtime received the event.
        XCTAssertEqual(runtime.events(of: .completion).count, 1)
        // Transcript received the assistant message with continuationEvent.
        XCTAssertEqual(store.session.messages.count, before + 1)
        XCTAssertEqual(store.session.messages.last?.continuationEvent?.outcome, .completion)
    }

    func test_compositionRoot_abandonReachesChatStoreTranscript() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        let store = ChatStore(
            feedbackRuntime: bootstrap.feedbackRuntime,
            completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
            telemetryEmitter: bootstrap.telemetryEmitter,
            capabilityRegistry: bootstrap.capabilityRegistry
        )
        bootstrap.continuationHandler = { event in
            store.recordContinuation(event)
        }
        await store.pendingCapabilityRefresh?.value

        let before = store.session.messages.count
        bootstrap.openSurface(.ai)
        bootstrap.recordSurfaceReturn(.abandon)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertEqual(runtime.events(of: .abandon).count, 1)
        XCTAssertEqual(store.session.messages.count, before + 1)
        XCTAssertEqual(store.session.messages.last?.continuationEvent?.outcome, .abandon)
    }

    func test_compositionRoot_dismissDoesNotReachTranscript() async throws {
        // The silent path: runtime records, transcript stays unchanged.
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        let store = ChatStore(
            feedbackRuntime: bootstrap.feedbackRuntime,
            completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
            telemetryEmitter: bootstrap.telemetryEmitter,
            capabilityRegistry: bootstrap.capabilityRegistry
        )
        bootstrap.continuationHandler = { event in
            store.recordContinuation(event)
        }
        await store.pendingCapabilityRefresh?.value

        let before = store.session.messages.count
        bootstrap.openSurface(.store)
        bootstrap.recordSurfaceReturn(.dismiss)
        await bootstrap.pendingContinuationEmit?.value

        // Runtime received the silent event.
        XCTAssertEqual(runtime.events(of: .dismiss).count, 1)
        // Transcript untouched (no new message).
        XCTAssertEqual(store.session.messages.count, before)
    }
}
