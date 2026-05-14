//
//  ChatStorePromptSubmitTelemetryTests.swift
//  kAirTests
//
//  Main B integration tests: the FIRST real telemetry emit in kAir.
//  `ChatStore.submit(prompt:using:)` MUST fire exactly one
//  `TelemetryEvent.chatPromptSubmit` per committed prompt with a
//  payload that satisfies the §5.2 propagation matrix.
//
//  Pinned invariants per `Contracts/telemetry-contract-v1.md`:
//    - §3 + §3.2: identifier opacity (consumers don't parse the
//      bytes; tests only care that ids are propagated verbatim).
//    - §4.1: event name is exactly `"chat.prompt.submit"`.
//    - §5.1 + §3: each `submit` issues a NEW `trace_id`. `thread_id`
//      is stable across multiple submits in the same `ChatStore`.
//    - §5.2: REQUIRED ids = {trace_id, thread_id}. FORBIDDEN ids =
//      {recommendation_id, source_request_id, source_recommendation_id,
//      surface_session_id, feedback_chain_id}.
//
//  Tests use:
//    - `InMemoryTelemetryEmitter` to capture emitted records.
//    - `DeterministicTelemetryIdentifierFactory` (a local test
//      double) to make trace / thread ids predictable per scenario.
//

import XCTest
@testable import kAir

@MainActor
final class ChatStorePromptSubmitTelemetryTests: XCTestCase {

    // MARK: - One submit ⇒ one chat.prompt.submit

    func test_submit_emitsOneChatPromptSubmit() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        XCTAssertEqual(emitter.records(of: .chatPromptSubmit).count, 1)
    }

    func test_emittedEventName_isFrozenContractString() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        // §4.1: the raw value must be exactly "chat.prompt.submit".
        // (TelemetryEvent's raw string is the canonical wire name.)
        let record = try XCTUnwrap(emitter.records.first)
        XCTAssertEqual(record.event.rawValue, "chat.prompt.submit")
    }

    // MARK: - Required ids present, forbidden ids absent (§5.2)

    func test_emittedPayload_carriesTraceIDAndThreadID() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let factory = DeterministicTelemetryIdentifierFactory(
            traces: ["trace-1"],
            thread: "thread-A"
        )
        let store = ChatStore(
            telemetryEmitter: emitter,
            identifierFactory: factory
        )

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        let record = try XCTUnwrap(emitter.records.first)
        XCTAssertEqual(record.payload.traceID, TraceID("trace-1"))
        XCTAssertEqual(record.payload.threadID, ThreadID("thread-A"))
    }

    func test_emittedPayload_satisfiesPropagationMatrix() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        let record = try XCTUnwrap(emitter.records.first)
        let violations = TelemetryPropagationMatrix.violations(
            record.event,
            record.payload
        )
        XCTAssertEqual(
            violations,
            [],
            "chat.prompt.submit payload violated §5.2: \(violations)"
        )
    }

    func test_emittedPayload_omitsForbiddenIDs() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        // §5.2 forbids these five for chat.prompt.submit.
        let record = try XCTUnwrap(emitter.records.first)
        XCTAssertNil(record.payload.recommendationID)
        XCTAssertNil(record.payload.sourceRequestID)
        XCTAssertNil(record.payload.sourceRecommendationID)
        XCTAssertNil(record.payload.surfaceSessionID)
        XCTAssertNil(record.payload.feedbackChainID)
    }

    // MARK: - Identifier lifecycle (§3 + §5.1)

    func test_twoSubmits_issueDistinctTraceIDs() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let factory = DeterministicTelemetryIdentifierFactory(
            traces: ["trace-1", "trace-2"],
            thread: "thread-A"
        )
        let store = ChatStore(
            telemetryEmitter: emitter,
            identifierFactory: factory
        )

        store.submitPrompt("first", using: nil)
        await store.pendingTelemetryEmit?.value
        store.submitPrompt("second", using: nil)
        await store.pendingTelemetryEmit?.value

        let records = emitter.records(of: .chatPromptSubmit)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].payload.traceID, TraceID("trace-1"))
        XCTAssertEqual(records[1].payload.traceID, TraceID("trace-2"))
        XCTAssertNotEqual(records[0].payload.traceID, records[1].payload.traceID)
    }

    func test_twoSubmits_shareSameThreadID() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let factory = DeterministicTelemetryIdentifierFactory(
            traces: ["trace-1", "trace-2"],
            thread: "thread-A"
        )
        let store = ChatStore(
            telemetryEmitter: emitter,
            identifierFactory: factory
        )

        store.submitPrompt("first", using: nil)
        await store.pendingTelemetryEmit?.value
        store.submitPrompt("second", using: nil)
        await store.pendingTelemetryEmit?.value

        let records = emitter.records(of: .chatPromptSubmit)
        XCTAssertEqual(records[0].payload.threadID, ThreadID("thread-A"))
        XCTAssertEqual(records[1].payload.threadID, ThreadID("thread-A"))
    }

    func test_uuidFactoryDefault_producesNonEmptyTraceIDs() async throws {
        // Default `UUIDTelemetryIdentifierFactory` should produce a
        // non-empty raw value. Two submits should issue distinct
        // raw values (UUID collision probability ~ 0).
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)

        store.submitPrompt("first", using: nil)
        await store.pendingTelemetryEmit?.value
        store.submitPrompt("second", using: nil)
        await store.pendingTelemetryEmit?.value

        let records = emitter.records(of: .chatPromptSubmit)
        XCTAssertEqual(records.count, 2)
        XCTAssertFalse(records[0].payload.traceID?.rawValue.isEmpty ?? true)
        XCTAssertNotEqual(records[0].payload.traceID, records[1].payload.traceID)
        XCTAssertEqual(records[0].payload.threadID, records[1].payload.threadID)
    }

    // MARK: - Boundary: emit happens, but a) prompt still commits and b) no other events fire

    func test_submit_appendsUserMessageAfterEmit() async throws {
        // Telemetry MUST NOT replace or block the user-visible
        // commit. After submit, the transcript has a `.user` message
        // for the prompt regardless of telemetry status.
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)
        let beforeCount = store.session.messages.count

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        XCTAssertGreaterThan(store.session.messages.count, beforeCount)
    }

    func test_submit_emitsOnlyChatPromptSubmit_noOtherTelemetry() async throws {
        // Main B scope: only `chat.prompt.submit`. No `intent.decide`,
        // no `rail.slate.materialize`, no surface / continuation /
        // feedback events. This pins the scope until the next main
        // line wires those.
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)

        store.submitPrompt("hello", using: nil)
        await store.pendingTelemetryEmit?.value

        XCTAssertEqual(emitter.records.count, 1)
        XCTAssertEqual(emitter.records[0].event, .chatPromptSubmit)
    }

    func test_sendDraft_emitsOneChatPromptSubmit() async throws {
        // The view's "send" path (`sendDraft`) flows into the same
        // `submit(prompt:using:)` and so should also fire exactly
        // one `chat.prompt.submit`.
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)
        store.draft = "hello via draft"

        store.sendDraft(using: nil)
        await store.pendingTelemetryEmit?.value

        XCTAssertEqual(emitter.records(of: .chatPromptSubmit).count, 1)
    }

    func test_sendDraft_emptyDraft_doesNotEmit() async throws {
        // Empty / whitespace-only drafts short-circuit before submit.
        // No telemetry event should fire in that case.
        let emitter = InMemoryTelemetryEmitter()
        let store = ChatStore(telemetryEmitter: emitter)
        store.draft = "   "

        store.sendDraft(using: nil)
        // Nothing to await: no submit fired, so no
        // pendingTelemetryEmit was set.
        XCTAssertNil(store.pendingTelemetryEmit)
        XCTAssertEqual(emitter.records.count, 0)
    }
}

// MARK: - Test double

/// Deterministic `TelemetryIdentifierFactory` that hands out a
/// pre-seeded sequence of `TraceID`s and a fixed `ThreadID`. Falls
/// back to `"trace-overflow-N"` once the seed is exhausted so
/// over-call regressions are visible without crashing the test.
@MainActor
private final class DeterministicTelemetryIdentifierFactory: TelemetryIdentifierFactory {
    private var nextTraces: [String]
    private let threadRaw: String
    private var overflow = 0

    init(traces: [String], thread: String) {
        self.nextTraces = traces
        self.threadRaw = thread
    }

    func makeTraceID() -> TraceID {
        if !nextTraces.isEmpty {
            return TraceID(nextTraces.removeFirst())
        }
        overflow += 1
        return TraceID("trace-overflow-\(overflow)")
    }

    func makeThreadID() -> ThreadID {
        ThreadID(threadRaw)
    }

    func makeSurfaceSessionID() -> SurfaceSessionID {
        // Main D.1 added `makeSurfaceSessionID()` to the protocol;
        // this test double doesn't exercise the surface-session path,
        // so a unique-per-call UUID is sufficient.
        SurfaceSessionID(UUID().uuidString)
    }
}
