//
//  ContinuationRuntime.swift
//  kAir
//
//  Protocol + ship-built implementations for the v1 continuation
//  runtime per `Contracts/UX/continuation-runtime-v1.md`.
//
//  Architectural shape (mirrors `FeedbackRuntime` from Main A):
//
//    - The runtime is the OBSERVABILITY sink for `ChatContinuationEvent`.
//      It is parallel to the transcript projection — the transcript
//      append for `renderEligible == true` is done by `ChatStore`
//      directly (per §8.1 projection option (b) — `ConversationMessage`
//      with a typed `continuationEvent` field).
//    - The runtime is composed at the app's composition root
//      (`AppBootstrap`) and threaded into the emit site. `ChatStore`
//      does NOT decide its own runtime.
//    - Default is `NoOpContinuationRuntime`. Production builds can
//      swap to a scorer / telemetry sink without changing call sites.
//
//  Per `Contracts/UX/continuation-runtime-v1.md`:
//    - §6: the runtime emits an event for ALL FOUR `TerminalOutcome`
//      cases. Only `renderEligible` gates the sub-payloads and the
//      transcript projection.
//    - §7: the event MUST pass validation before emission. Emit sites
//      use `ContinuationEventValidator` as the chokepoint.
//    - §8.3: the runtime emits an event AND records the appropriate
//      stage / outcome via the existing telemetry path. The two
//      streams are parallel. This v1 runtime does NOT emit telemetry
//      on its own — chain ids and span names belong to
//      `telemetry-contract-v1`.
//
//  Boundary (intentional):
//    - This runtime does NOT decide the user-visible transcript shape.
//      That belongs to `ChatStore.recordContinuation(_:)` (§8.1
//      projection (b)).
//    - This runtime does NOT mutate the chat session or the chat
//      transcript.
//    - This runtime is NOT a router. Surface routing decisions live
//      in the conversation-intent layer.
//

import Foundation

/// Records a single `ChatContinuationEvent`. Implementations route
/// to whatever sink the runtime selects (scorer, JSONL file,
/// in-memory ring buffer, no-op for previews).
///
/// `emit(_:)` is `async throws` for symmetry with `FeedbackRuntime`.
/// Per `Contracts/UX/continuation-runtime-v1.md` §6 + §8.3, emit
/// failures MUST NOT cause user-visible side effects — callers
/// MAY drop thrown errors silently. The transcript projection is
/// independent of emit success.
protocol ContinuationRuntime {
    /// Records a continuation event. Called by the emit chokepoint
    /// after `ContinuationEventValidator.validate(_:)` returns
    /// empty violations.
    func emit(_ event: ChatContinuationEvent) async throws
}

/// `ContinuationRuntime` that discards every event.
///
/// Suitable for SwiftUI previews and the test scaffold. Production
/// builds replace this default with a real scorer / telemetry sink
/// once those wire up (separate work lines per the v1 ratification
/// checklist).
final class NoOpContinuationRuntime: ContinuationRuntime {
    init() {}

    func emit(_ event: ChatContinuationEvent) async throws {
        // Intentionally empty. Continuation runtime emission is
        // silent observability; the no-op variant fulfills the
        // contract by doing nothing.
        _ = event
    }
}

/// Bounded in-memory ring-buffer `ContinuationRuntime` for tests and
/// local diagnostic builds. Records every emitted event so tests can
/// assert on what fired.
///
/// Mirrors `InMemoryTelemetryEmitter` (Main B). Process-local,
/// bounded by `capacity`, FIFO eviction when full. No transport, no
/// persistence, no sampling — those are out of v1 scope per
/// `continuation-runtime-v1.md` §10 (non-goals).
@MainActor
final class InMemoryContinuationRuntime: ContinuationRuntime {
    /// Default ring-buffer capacity when none is supplied.
    nonisolated static let defaultCapacity: Int = 64

    private(set) var emittedEvents: [ChatContinuationEvent] = []

    let capacity: Int

    init(capacity: Int = InMemoryContinuationRuntime.defaultCapacity) {
        precondition(capacity > 0, "InMemoryContinuationRuntime capacity must be positive")
        self.capacity = capacity
    }

    func emit(_ event: ChatContinuationEvent) async throws {
        if emittedEvents.count >= capacity {
            emittedEvents.removeFirst(emittedEvents.count - capacity + 1)
        }
        emittedEvents.append(event)
    }

    /// Returns every emitted event whose `outcome` matches the given
    /// kind, in insertion order. Tests use this to assert e.g.
    /// "exactly one `.completion` was emitted".
    func events(of outcome: TerminalOutcome) -> [ChatContinuationEvent] {
        emittedEvents.filter { $0.outcome == outcome }
    }

    /// Clears the buffer. Tests that reuse a single runtime across
    /// scenarios call this between scenarios.
    func reset() {
        emittedEvents.removeAll(keepingCapacity: true)
    }
}
