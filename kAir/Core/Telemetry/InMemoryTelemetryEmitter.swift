//
//  InMemoryTelemetryEmitter.swift
//  kAir
//
//  Bounded in-memory ring-buffer `TelemetryEmitter` for tests and
//  diagnostic builds. Captures every `(event, payload)` pair so a
//  caller (typically the test suite) can assert on what was emitted.
//
//  Per Contracts/telemetry-contract-v1.md §10 (non-goals): wire format,
//  sampling, redaction, retention, and persistence schema are out of
//  v1 scope. This sink is intentionally process-local and unbounded
//  beyond `capacity` — it does not hit disk, network, or any real
//  observability backend. It is appropriate for:
//    - Unit tests that need to verify a specific event fired.
//    - Local debug builds where a developer wants to inspect recent
//      emissions interactively.
//
//  Concurrency: `@MainActor`-isolated. `ChatStore` is `@MainActor`,
//  so the emitter ride-alongs the same actor without any extra
//  cross-actor hop. Production builds can swap to a non-MainActor
//  emitter (e.g. an OpenTelemetry-backed one) once §10 is lifted.
//
//  Capacity: defaults to `defaultCapacity` (256). When the buffer is
//  full, the oldest record is evicted. Tests typically construct one
//  with capacity > expected emissions and assert the buffer is the
//  emission log; debug builds use the default.
//
//  Per `TelemetryEmitter` protocol contract: `emit(_:_:)` MUST NOT
//  throw. This implementation is non-throwing and never blocks.
//

import Foundation

/// `TelemetryEmitter` that records every emitted `(event, payload)`
/// pair into a bounded ring buffer. Suitable for tests and local
/// diagnostic builds.
///
/// - SeeAlso: `TelemetryEmitter`
@MainActor
final class InMemoryTelemetryEmitter: TelemetryEmitter {
    /// One captured emission. Records the `event` (e.g.
    /// `.chatPromptSubmit`) and the full `payload` so tests can
    /// assert on identifier propagation per
    /// `Contracts/telemetry-contract-v1.md` §5.2.
    struct Record: Hashable {
        let event: TelemetryEvent
        let payload: TelemetryEventPayload
    }

    /// Default ring-buffer capacity when none is supplied. Sized for
    /// "the last few user actions" — far smaller than a real
    /// telemetry pipeline would retain, but enough for an interactive
    /// inspector or a single-test scenario.
    ///
    /// `nonisolated` so it can be referenced from default-argument
    /// expressions on `init(capacity:)`, which evaluate in the
    /// caller's isolation (often nonisolated) rather than the
    /// MainActor.
    nonisolated static let defaultCapacity: Int = 256

    /// All currently-retained records, oldest first. Once `capacity`
    /// is reached, every additional `emit(_:_:)` evicts `records[0]`
    /// (FIFO ring buffer semantics).
    private(set) var records: [Record] = []

    /// Maximum number of records retained before the oldest is
    /// evicted. Set at construction.
    let capacity: Int

    /// - Parameter capacity: ring-buffer capacity. Must be positive.
    ///   When the buffer reaches `capacity`, additional emissions
    ///   evict the oldest record.
    init(capacity: Int = InMemoryTelemetryEmitter.defaultCapacity) {
        precondition(capacity > 0, "InMemoryTelemetryEmitter capacity must be positive")
        self.capacity = capacity
    }

    func emit(_ event: TelemetryEvent, _ payload: TelemetryEventPayload) async {
        let record = Record(event: event, payload: payload)
        if records.count >= capacity {
            records.removeFirst(records.count - capacity + 1)
        }
        records.append(record)
    }

    /// Convenience: returns every record matching the given event
    /// kind, in insertion order. Tests use this to assert e.g.
    /// "exactly one `chat.prompt.submit` was emitted".
    func records(of event: TelemetryEvent) -> [Record] {
        records.filter { $0.event == event }
    }

    /// Clears the buffer. Tests that reuse a single emitter across
    /// scenarios call this between scenarios.
    func reset() {
        records.removeAll(keepingCapacity: true)
    }
}
