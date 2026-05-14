//
//  ContinuationRuntimeTests.swift
//  kAirTests
//
//  Tests for `InMemoryContinuationRuntime` (Main D): the bounded
//  ring-buffer continuation sink used to verify Main D's first real
//  emit sites for `.completion` and `.abandon`.
//
//  Mirrors `InMemoryTelemetryEmitterTests`.
//

import XCTest
@testable import kAir

@MainActor
final class ContinuationRuntimeTests: XCTestCase {

    // MARK: - Append + filter

    func test_emit_appendsInOrder() async throws {
        let runtime = InMemoryContinuationRuntime()

        let e1 = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        let e2 = ContinuationProjection.makeEvent(surface: .ai, outcome: .abandon)

        try await runtime.emit(e1)
        try await runtime.emit(e2)

        XCTAssertEqual(runtime.emittedEvents.count, 2)
        XCTAssertEqual(runtime.emittedEvents[0].outcome, .completion)
        XCTAssertEqual(runtime.emittedEvents[1].outcome, .abandon)
    }

    func test_eventsOf_filtersByOutcome() async throws {
        let runtime = InMemoryContinuationRuntime()

        try await runtime.emit(ContinuationProjection.makeEvent(surface: .maps, outcome: .completion))
        try await runtime.emit(ContinuationProjection.makeEvent(surface: .ai, outcome: .abandon))
        try await runtime.emit(ContinuationProjection.makeEvent(surface: .store, outcome: .completion))
        try await runtime.emit(ContinuationProjection.makeEvent(surface: .store, outcome: .dismiss))

        XCTAssertEqual(runtime.events(of: .completion).count, 2)
        XCTAssertEqual(runtime.events(of: .abandon).count, 1)
        XCTAssertEqual(runtime.events(of: .dismiss).count, 1)
        XCTAssertEqual(runtime.events(of: .acceptNoEntry).count, 0)
    }

    func test_reset_clearsBuffer() async throws {
        let runtime = InMemoryContinuationRuntime()
        try await runtime.emit(ContinuationProjection.makeEvent(surface: .maps, outcome: .completion))
        XCTAssertEqual(runtime.emittedEvents.count, 1)

        runtime.reset()
        XCTAssertTrue(runtime.emittedEvents.isEmpty)
    }

    // MARK: - Ring-buffer capacity

    func test_capacityBound_evictsOldestWhenFull() async throws {
        let runtime = InMemoryContinuationRuntime(capacity: 2)

        let e1 = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        let e2 = ContinuationProjection.makeEvent(surface: .ai, outcome: .completion)
        let e3 = ContinuationProjection.makeEvent(surface: .store, outcome: .completion)

        try await runtime.emit(e1)
        try await runtime.emit(e2)
        try await runtime.emit(e3)

        XCTAssertEqual(runtime.emittedEvents.count, 2)
        XCTAssertEqual(runtime.emittedEvents[0].surface, .ai)
        XCTAssertEqual(runtime.emittedEvents[1].surface, .store)
    }

    func test_defaultCapacity_isReasonable() {
        XCTAssertGreaterThanOrEqual(InMemoryContinuationRuntime.defaultCapacity, 16)
    }

    // MARK: - NoOp baseline

    func test_noOpRuntime_doesNotThrow_andDoesNotRecord() async throws {
        let runtime = NoOpContinuationRuntime()
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        try await runtime.emit(event) // Must not throw.
        // No state to inspect — the assertion is non-throwing
        // completion.
    }
}
