//
//  ContinuationTelemetryTests.swift
//  kAirTests
//
//  Main D.1 integration tests: the §4.1 continuation telemetry
//  events (`transcript.continuation.append` /
//  `transcript.continuation.silent`) fire from the SAME chokepoint
//  as the continuation runtime emit (`AppBootstrap.recordSurfaceReturn(_:)`).
//
//  Pinned invariants per
//  Contracts/telemetry-contract-v1.md and continuation-runtime-v1.md:
//
//    - §4.1: render-eligible outcomes (`.completion` / `.abandon`)
//      fire `transcript.continuation.append`; non-render-eligible
//      outcomes (`.dismiss` / `.acceptNoEntry`) fire
//      `transcript.continuation.silent`.
//    - §5.2: both events require `trace_id`, `thread_id`, and
//      `surface_session_id`.
//    - §3 / §5.1: `surface_session_id` is fresh per surface entry;
//      `trace_id` propagates from the originating `chat.prompt.submit`;
//      `thread_id` is stable across the chat session.
//    - Same chokepoint, no second bypass: telemetry emit lives in
//      `recordSurfaceReturn(_:)` alongside the continuation runtime
//      emit; missing required ids skip the telemetry emit but do
//      NOT block the continuation runtime emit or the transcript
//      projection.
//

import XCTest
@testable import kAir

@MainActor
final class ContinuationTelemetryTests: XCTestCase {

    // MARK: - Event-name mapping (§4.1)

    func test_completion_fires_transcriptContinuationAppend() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let appendRecords = env.emitter.records(of: .transcriptContinuationAppend)
        XCTAssertEqual(appendRecords.count, 1)
        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationSilent).count, 0)
    }

    func test_abandon_fires_transcriptContinuationAppend() async throws {
        // §6: `.abandon` is render-eligible → maps to
        // `transcript.continuation.append`, NOT to `.silent`.
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.ai)
        env.bootstrap.recordSurfaceReturn(.abandon)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationAppend).count, 1)
        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationSilent).count, 0)
    }

    func test_dismiss_fires_transcriptContinuationSilent() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.store)
        env.bootstrap.recordSurfaceReturn(.dismiss)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationSilent).count, 1)
        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationAppend).count, 0)
    }

    func test_acceptNoEntry_fires_transcriptContinuationSilent() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.ai)
        env.bootstrap.recordSurfaceReturn(.acceptNoEntry)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationSilent).count, 1)
        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationAppend).count, 0)
    }

    // MARK: - §5.2 propagation matrix

    func test_emittedAppendPayload_carriesAllThreeRequiredIDs() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let record = try XCTUnwrap(env.emitter.records.first)
        XCTAssertNotNil(record.payload.traceID)
        XCTAssertNotNil(record.payload.threadID)
        XCTAssertNotNil(record.payload.surfaceSessionID)
    }

    func test_emittedAppendPayload_satisfiesPropagationMatrix() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let record = try XCTUnwrap(env.emitter.records.first)
        let violations = TelemetryPropagationMatrix.violations(record.event, record.payload)
        XCTAssertEqual(violations, [], "violations: \(violations)")
    }

    func test_emittedSilentPayload_satisfiesPropagationMatrix() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.dismiss)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let record = try XCTUnwrap(env.emitter.records.first)
        let violations = TelemetryPropagationMatrix.violations(record.event, record.payload)
        XCTAssertEqual(violations, [], "violations: \(violations)")
    }

    func test_allFourOutcomes_produceMatrixCompliantPayloads() async throws {
        for outcome in TerminalOutcome.allCases {
            let env = makeEnvironment()
            try await prime(env)
            env.bootstrap.openSurface(.maps)
            env.bootstrap.recordSurfaceReturn(outcome)
            await env.bootstrap.pendingContinuationTelemetryEmit?.value

            let record = try XCTUnwrap(
                env.emitter.records.first,
                "no record for \(outcome)"
            )
            let violations = TelemetryPropagationMatrix.violations(record.event, record.payload)
            XCTAssertEqual(violations, [], "\(outcome) violations: \(violations)")
        }
    }

    // MARK: - Identifier propagation (§3 + §5.1)

    func test_traceID_matchesLastIssuedFromPromptSubmit() async throws {
        let env = makeEnvironment()
        try await prime(env)

        let expectedTrace = try XCTUnwrap(env.store.lastIssuedTraceID)
        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let record = try XCTUnwrap(env.emitter.records.first)
        XCTAssertEqual(record.payload.traceID, expectedTrace)
    }

    func test_threadID_matchesChatStoreThreadID() async throws {
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.ai)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let record = try XCTUnwrap(env.emitter.records.first)
        XCTAssertEqual(record.payload.threadID, env.store.telemetryThreadID)
    }

    func test_surfaceSessionID_isFreshPerSurfaceEntry() async throws {
        // Two open → return cycles produce two distinct surface
        // session ids.
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let appendRecords = env.emitter.records(of: .transcriptContinuationAppend)
        XCTAssertEqual(appendRecords.count, 2)
        XCTAssertNotEqual(
            appendRecords[0].payload.surfaceSessionID,
            appendRecords[1].payload.surfaceSessionID
        )
    }

    func test_traceID_sharedAcrossSurfaceEntriesWithinSamePrompt() async throws {
        // The trace_id is owned by the chat prompt that committed
        // it; while no new prompt is submitted, all surface
        // entries / returns SHOULD carry the same trace_id (the
        // user request lifecycle is still open).
        let env = makeEnvironment()
        try await prime(env)
        let expectedTrace = try XCTUnwrap(env.store.lastIssuedTraceID)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value
        env.bootstrap.openSurface(.ai)
        env.bootstrap.recordSurfaceReturn(.abandon)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let appendRecords = env.emitter.records(of: .transcriptContinuationAppend)
        XCTAssertEqual(appendRecords.count, 2)
        XCTAssertEqual(appendRecords[0].payload.traceID, expectedTrace)
        XCTAssertEqual(appendRecords[1].payload.traceID, expectedTrace)
    }

    func test_traceID_updatesAfterNewPromptSubmit() async throws {
        let env = makeEnvironment()
        try await prime(env)
        let trace1 = try XCTUnwrap(env.store.lastIssuedTraceID)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        // Submit a second prompt — new trace_id.
        env.store.submitPrompt("second", using: nil)
        await env.store.pendingTelemetryEmit?.value
        let trace2 = try XCTUnwrap(env.store.lastIssuedTraceID)
        XCTAssertNotEqual(trace1, trace2)

        env.bootstrap.openSurface(.ai)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let appendRecords = env.emitter.records(of: .transcriptContinuationAppend)
        XCTAssertEqual(appendRecords.count, 2)
        XCTAssertEqual(appendRecords[0].payload.traceID, trace1)
        XCTAssertEqual(appendRecords[1].payload.traceID, trace2)
    }

    // MARK: - Programming-error path (missing trace_id)

    func test_recordSurfaceReturn_withoutPriorPrompt_skipsTelemetryEmit() async throws {
        // No prompt submitted yet → lastIssuedTraceID is nil →
        // continuation telemetry is silently skipped. The
        // continuation runtime emit and the transcript projection
        // are NOT blocked.
        let env = makeEnvironment()
        // Do NOT prime — skip the prompt submit.

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationEmit?.value
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        // No continuation telemetry recorded.
        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationAppend).count, 0)
        XCTAssertEqual(env.emitter.records(of: .transcriptContinuationSilent).count, 0)
        // But the continuation runtime emit DID fire.
        XCTAssertEqual(env.continuationRuntime.events(of: .completion).count, 1)
        // And the transcript projection DID fire.
        XCTAssertTrue(env.store.session.messages.contains(where: {
            $0.continuationEvent?.outcome == .completion
        }))
    }

    func test_recordSurfaceReturn_withoutResolver_skipsTelemetryEmit() async throws {
        // No resolver installed (typical of previews / tests that
        // don't wire chat) → telemetry skipped, runtime still emits.
        let emitter = InMemoryTelemetryEmitter()
        let continuationRuntime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(
            telemetryEmitter: emitter,
            continuationRuntime: continuationRuntime
        )
        // Intentionally DO NOT set bootstrap.surfaceTelemetryIdentifiers.

        bootstrap.openSurface(.maps)
        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value
        await bootstrap.pendingContinuationTelemetryEmit?.value

        XCTAssertEqual(emitter.records.count, 0)
        XCTAssertEqual(continuationRuntime.events(of: .completion).count, 1)
    }

    // MARK: - Single chokepoint (no second bypass)

    func test_recordSurfaceReturn_emitsExactlyOneTelemetryEvent() async throws {
        // No matter the outcome, exactly one §4.1 continuation
        // telemetry event fires — never two, never zero (assuming
        // ids are available).
        let env = makeEnvironment()
        try await prime(env)

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        let continuationEvents = env.emitter.records.filter {
            $0.event == .transcriptContinuationAppend
                || $0.event == .transcriptContinuationSilent
        }
        XCTAssertEqual(continuationEvents.count, 1)
    }

    func test_recordSurfaceReturn_emitsNoOtherTelemetryEvents() async throws {
        // Main D.1 scope: ONLY `transcript.continuation.append` and
        // `.silent` fire. No rail / surface-enter/return /
        // intent.decide / feedback.event.
        let env = makeEnvironment()
        try await prime(env)
        env.emitter.reset()  // clear the chat.prompt.submit record

        env.bootstrap.openSurface(.maps)
        env.bootstrap.recordSurfaceReturn(.completion)
        await env.bootstrap.pendingContinuationTelemetryEmit?.value

        // Only the one continuation telemetry event.
        XCTAssertEqual(env.emitter.records.count, 1)
        XCTAssertEqual(env.emitter.records[0].event, .transcriptContinuationAppend)
    }

    // MARK: - Test environment

    private struct Environment {
        let emitter: InMemoryTelemetryEmitter
        let continuationRuntime: InMemoryContinuationRuntime
        let bootstrap: AppBootstrap
        let store: ChatStore
    }

    /// Builds the composition seam exactly the way
    /// `ChatHomeView.init(bootstrap:)` + `.onAppear` does. Both
    /// handlers (transcript projection + telemetry identifier
    /// resolver) are installed.
    private func makeEnvironment() -> Environment {
        let emitter = InMemoryTelemetryEmitter()
        let continuationRuntime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(
            telemetryEmitter: emitter,
            continuationRuntime: continuationRuntime
        )
        let store = ChatStore(
            feedbackRuntime: bootstrap.feedbackRuntime,
            completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
            telemetryEmitter: bootstrap.telemetryEmitter,
            capabilityRegistry: bootstrap.capabilityRegistry
        )
        bootstrap.continuationHandler = { [weak store] event in
            store?.recordContinuation(event)
        }
        bootstrap.surfaceTelemetryIdentifiers = { [weak store] in
            guard let store else { return (nil, nil) }
            return (store.lastIssuedTraceID, store.telemetryThreadID)
        }
        return Environment(
            emitter: emitter,
            continuationRuntime: continuationRuntime,
            bootstrap: bootstrap,
            store: store
        )
    }

    /// Submits one prompt so a `trace_id` is in flight for the
    /// continuation telemetry emit to propagate. Awaits the prompt
    /// telemetry task. Then clears the prompt-submit record from
    /// the emitter so tests can assert only on the continuation
    /// events.
    private func prime(_ env: Environment) async throws {
        await env.store.pendingCapabilityRefresh?.value
        env.store.submitPrompt("hello", using: nil)
        await env.store.pendingTelemetryEmit?.value
        env.emitter.reset()
    }
}
