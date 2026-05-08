//
//  TelemetryPropagationMatrix.swift
//  kAir
//
//  Pure-function check that a `(TelemetryEvent, TelemetryEventPayload)`
//  pair satisfies the §5.2 required-id propagation matrix from
//  Contracts/telemetry-contract-v1.md.
//
//  The matrix is reproduced exhaustively below for every (event, id)
//  pair from §5.2 of the contract. The mapping uses three states per
//  cell:
//   - ✓ (required): the id MUST be set; missing the id is a
//     `.missingRequiredID` violation.
//   - ✗ (forbidden): the id MUST NOT be set; setting the id is a
//     `.forbiddenIDPresent` violation.
//   - • (optional): the id MAY be set per the chain rules in §5.1; no
//     constraint is enforced at this layer.
//
//  This is pure: no side effects, no I/O, deterministic per input.
//  Callers (an instrumentation site, the test suite) build a payload,
//  pass it through, and inspect the returned violations.
//

import Foundation

/// A single way the propagation matrix in
/// Contracts/telemetry-contract-v1.md §5.2 can be violated by a
/// `(TelemetryEvent, TelemetryEventPayload)` pair.
enum TelemetryPropagationViolation: Hashable {
    /// An id required (✓) for the event is unset on the payload.
    case missingRequiredID(event: TelemetryEvent, id: TelemetryRequiredID)

    /// An id forbidden (✗) for the event is set on the payload.
    case forbiddenIDPresent(event: TelemetryEvent, id: TelemetryRequiredID)
}

/// Pure-function namespace for the §5.2 propagation matrix check.
enum TelemetryPropagationMatrix {
    /// Returns the list of ways the (event, payload) pair violates the
    /// §5.2 propagation matrix. An empty list means the payload is
    /// well-formed for the event.
    static func violations(
        _ event: TelemetryEvent,
        _ payload: TelemetryEventPayload
    ) -> [TelemetryPropagationViolation] {
        let required = TelemetryEventPayload.required(for: event)
        let forbidden = TelemetryEventPayload.forbidden(for: event)
        let present = payload.presentIDs()

        var violations: [TelemetryPropagationViolation] = []

        // Missing required ids: every ✓ entry that is not present.
        // Iterate in the canonical case order so violations are
        // emitted in a stable order across runs.
        for id in TelemetryRequiredID.allCases where required.contains(id) && !present.contains(id) {
            violations.append(.missingRequiredID(event: event, id: id))
        }

        // Forbidden ids that are present: every ✗ entry that IS set.
        for id in TelemetryRequiredID.allCases where forbidden.contains(id) && present.contains(id) {
            violations.append(.forbiddenIDPresent(event: event, id: id))
        }

        return violations
    }
}
