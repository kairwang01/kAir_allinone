//
//  TelemetryIdentifierFactory.swift
//  kAir
//
//  Single seam through which `trace_id` and `thread_id` are issued.
//
//  Per Contracts/telemetry-contract-v1.md §3:
//    - `trace_id` is issued by chat home (the composer / `ChatStore`)
//      at the moment a user prompt is committed. Issued exactly once
//      per submitted prompt.
//    - `thread_id` is issued by the chat session manager (the layer
//      that owns `ConversationMessage` history). Issued when the
//      thread is created.
//
//  Both issuers live inside `ChatStore` in this codebase, so this
//  factory is the SOLE place new ids appear. Centralizing issuance
//  here serves three reviewer-stated invariants:
//
//    1. Identifier-generation is single-sourced (no ad-hoc `UUID()`
//       sprinkled across the prompt commit path).
//    2. Tests can inject a deterministic factory to make trace_id /
//       thread_id values predictable per scenario.
//    3. Future runtimes (e.g. a process-wide id pool, a ULID issuer,
//       or a debug-build counter for log readability) can swap in by
//       replacing the conformance — without touching `ChatStore`.
//
//  Per Contracts/telemetry-contract-v1.md §3.2 (identifier opacity):
//  consumers MUST NOT parse the raw string. Whatever the factory
//  produces is opaque; the matrix and downstream emitters propagate
//  the bytes verbatim.
//
//  Boundary (intentional):
//    - This factory does NOT know about events. It does not return
//      payloads, does not run propagation checks, does not call
//      emit.
//    - This factory does NOT issue the other five identifier kinds
//      (recommendation_id, source_request_id, source_recommendation_id,
//      surface_session_id, feedback_chain_id). Those have other
//      issuers per §3 and will get their own seams in later main
//      lines (rail / surface / feedback / continuation).
//

import Foundation

/// Issues the two identifier kinds that originate inside chat home
/// (the composer / `ChatStore`).
///
/// Implementations MUST:
///   - Return a fresh `TraceID` on every `makeTraceID()` call (one
///     trace = one user request lifecycle per §3).
///   - Return the same `ThreadID` for the lifetime of one thread.
///     Whether that means "one per `ChatStore` instance" or "one per
///     persisted thread restored from disk" is the implementation's
///     decision; the factory just guarantees stability for the
///     caller's lifetime.
///
/// Implementations MUST NOT:
///   - Parse, mutate, or compare ids beyond their `RawRepresentable`
///     contract (per §3.2 opacity rule).
protocol TelemetryIdentifierFactory {
    /// Issue a fresh `TraceID`. Called once per committed user prompt
    /// per `Contracts/telemetry-contract-v1.md` §3 + §5.1.
    func makeTraceID() -> TraceID

    /// Issue a `ThreadID`. Called by `ChatStore` once at construction
    /// time to capture the thread's stable id. Subsequent emissions
    /// reuse the captured value.
    func makeThreadID() -> ThreadID
}

/// Default factory: `UUID().uuidString` for both ids.
///
/// Suitable for production runs and any test that does not need
/// deterministic identifier values. Tests that DO need determinism
/// inject a custom conformance (e.g. a counter-backed factory).
final class UUIDTelemetryIdentifierFactory: TelemetryIdentifierFactory {
    init() {}

    func makeTraceID() -> TraceID {
        TraceID(UUID().uuidString)
    }

    func makeThreadID() -> ThreadID {
        ThreadID(UUID().uuidString)
    }
}
