//
//  InMemoryTelemetryEmitterTests.swift
//  kAirTests
//
//  Tests for `InMemoryTelemetryEmitter` (Main B): the bounded
//  ring-buffer telemetry sink used to verify Main B's first real
//  emit (`chat.prompt.submit`) and any subsequent emit sites.
//
//  Coverage:
//    - emit(_:_:) appends in-order.
//    - records(of:) filters by event name.
//    - reset() clears the buffer.
//    - capacity bound: oldest record is evicted when full.
//

import XCTest
@testable import kAir

@MainActor
final class InMemoryTelemetryEmitterTests: XCTestCase {

    // MARK: - Append + filter

    func test_emit_appendsInOrder() async {
        let emitter = InMemoryTelemetryEmitter()

        let p1 = TelemetryEventPayload(
            traceID: TraceID("t1"),
            threadID: ThreadID("h1")
        )
        let p2 = TelemetryEventPayload(
            traceID: TraceID("t2"),
            threadID: ThreadID("h1")
        )

        await emitter.emit(.chatPromptSubmit, p1)
        await emitter.emit(.chatPromptSubmit, p2)

        XCTAssertEqual(emitter.records.count, 2)
        XCTAssertEqual(emitter.records[0].event, .chatPromptSubmit)
        XCTAssertEqual(emitter.records[0].payload.traceID, TraceID("t1"))
        XCTAssertEqual(emitter.records[1].payload.traceID, TraceID("t2"))
    }

    func test_recordsOf_filtersByEvent() async {
        let emitter = InMemoryTelemetryEmitter()

        let chatPayload = TelemetryEventPayload(
            traceID: TraceID("t1"),
            threadID: ThreadID("h1")
        )
        // Synthetic payload that satisfies the matrix for intent.decide.
        let intentPayload = TelemetryEventPayload(
            traceID: TraceID("t1"),
            threadID: ThreadID("h1"),
            sourceRequestID: SourceRequestID("t1")
        )

        await emitter.emit(.chatPromptSubmit, chatPayload)
        await emitter.emit(.intentDecide, intentPayload)
        await emitter.emit(.chatPromptSubmit, chatPayload)

        let chatRecords = emitter.records(of: .chatPromptSubmit)
        XCTAssertEqual(chatRecords.count, 2)
        XCTAssertEqual(emitter.records(of: .intentDecide).count, 1)
    }

    func test_reset_clearsBuffer() async {
        let emitter = InMemoryTelemetryEmitter()
        let payload = TelemetryEventPayload(
            traceID: TraceID("t1"),
            threadID: ThreadID("h1")
        )
        await emitter.emit(.chatPromptSubmit, payload)
        XCTAssertEqual(emitter.records.count, 1)

        emitter.reset()
        XCTAssertEqual(emitter.records.count, 0)
    }

    // MARK: - Ring-buffer capacity

    func test_capacityBound_evictsOldestWhenFull() async {
        let emitter = InMemoryTelemetryEmitter(capacity: 2)

        let p1 = TelemetryEventPayload(traceID: TraceID("t1"), threadID: ThreadID("h1"))
        let p2 = TelemetryEventPayload(traceID: TraceID("t2"), threadID: ThreadID("h1"))
        let p3 = TelemetryEventPayload(traceID: TraceID("t3"), threadID: ThreadID("h1"))

        await emitter.emit(.chatPromptSubmit, p1)
        await emitter.emit(.chatPromptSubmit, p2)
        await emitter.emit(.chatPromptSubmit, p3)

        XCTAssertEqual(emitter.records.count, 2)
        // Oldest (t1) was evicted; buffer holds t2, t3 in order.
        XCTAssertEqual(emitter.records[0].payload.traceID, TraceID("t2"))
        XCTAssertEqual(emitter.records[1].payload.traceID, TraceID("t3"))
    }

    func test_defaultCapacity_isLargeEnoughForTypicalTests() {
        // The default isn't a contract but tests should be able to
        // assume "more than a handful". Pin the current default so a
        // future tightening becomes a deliberate change.
        XCTAssertGreaterThanOrEqual(InMemoryTelemetryEmitter.defaultCapacity, 16)
    }
}
