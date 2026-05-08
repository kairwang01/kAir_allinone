//
//  TelemetryEmitter.swift
//  kAir
//
//  Protocol + no-op implementation for the v1 telemetry skeleton.
//
//  Per Contracts/telemetry-contract-v1.md §1 (purpose): the contract
//  exists so every emitter (chat home, the conversation intent engine,
//  the recommendation rail, execution surfaces, the continuation
//  runtime, the feedback affordances) records the same correlation
//  keys against the same span / event names. This file provides the
//  Swift-side seam through which those emitters will eventually fire.
//
//  Per Contracts/telemetry-contract-v1.md §10 (non-goals): the wire
//  format, sampling, redaction, retention, and persistence schema are
//  explicitly out of v1 scope. This protocol intentionally takes no
//  stance on transport. The only ship-built emitter at v1 skeleton
//  time is `NoOpTelemetryEmitter`, which discards every call.
//
//  `emit(_:_:)` is `async` but NOT `throws`. Telemetry emission failure
//  MUST NOT propagate to callers — telemetry is silent observability
//  and should never break a user-visible flow. Errors are absorbed by
//  whatever real emitter eventually wires up; the no-op stub
//  trivially satisfies that.
//

import Foundation

/// Emits telemetry events. Implementations route the event + payload
/// to whatever transport / sink the runtime selects (OpenTelemetry, a
/// JSONL file, an in-memory ring buffer, or the no-op emitter for
/// previews and tests).
protocol TelemetryEmitter {
    /// Emit a single telemetry event with the given payload. Per the
    /// contract, this method MUST NOT throw; emission failures are
    /// silently absorbed. Implementations are expected to enforce the
    /// §5.2 propagation matrix via `TelemetryPropagationMatrix` before
    /// shipping the event.
    func emit(_ event: TelemetryEvent, _ payload: TelemetryEventPayload) async
}

/// No-op emitter: discards every call. Suitable for SwiftUI previews,
/// the test scaffold, and any environment in which emitting telemetry
/// would be a side effect callers cannot tolerate. This is the only
/// emitter shipped by the v1 telemetry skeleton; nothing in the
/// existing kAir codebase calls it.
final class NoOpTelemetryEmitter: TelemetryEmitter {
    init() {}

    func emit(_ event: TelemetryEvent, _ payload: TelemetryEventPayload) async {
        // Intentionally empty. Telemetry emission is silent
        // observability; the no-op variant fulfills the contract by
        // doing nothing.
        _ = event
        _ = payload
    }
}
