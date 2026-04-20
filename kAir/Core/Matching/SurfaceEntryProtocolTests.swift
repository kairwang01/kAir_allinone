//
//  SurfaceEntryProtocolTests.swift
//  kAir
//
//  Contract tests for the unified Execution Surface entry protocol.
//  Verifies that SurfaceEntryRequest round-trips through Codable, the
//  3 surface-entry events serialize cleanly, and ExecutionReturnPayload
//  keeps the requestId / recommendationId link on encode/decode.
//

import Foundation

struct SurfaceEntryProtocolReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum SurfaceEntryProtocolTests {
    @MainActor
    static func runAll() -> SurfaceEntryProtocolReport {
        let results: [KernelPhase1TestResult] = [
            testSurfaceEntryRequestRoundTrip(),
            testEntryEventTypesSerialize(),
            testExecutionReturnPayloadCarriesRequestIds(),
            testMatchingEventCarriesEntryRequestId(),
        ]
        return SurfaceEntryProtocolReport(results: results)
    }

    // MARK: - Test 1: SurfaceEntryRequest round-trips through JSON

    static func testSurfaceEntryRequestRoundTrip() -> KernelPhase1TestResult {
        let request = SurfaceEntryRequest(
            requestId: "req-1",
            surfaceType: .maps,
            entryIntent: .navigate,
            sourceCardId: "card-1",
            sourceRecommendationId: "rec-1",
            sourceThreadId: "thread-1",
            objectType: "place",
            objectId: "place-1",
            normalizedArgs: ["query": "pharmacy", "transport_mode": "walking"],
            requiresConfirmation: false,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: "Find a nearby pharmacy",
                returnThreadId: "thread-1",
                priorContextStateSummary: nil
            ),
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        do {
            let data = try request.encodeJSONData()
            let decoded = try SurfaceEntryRequest.decode(from: data)
            guard decoded == request else {
                return KernelPhase1TestResult(
                    name: "surface_entry_request_round_trip",
                    passed: false,
                    detail: "decoded mismatch: \(decoded) vs \(request)"
                )
            }
            guard decoded.normalizedArgs["query"] == "pharmacy" else {
                return KernelPhase1TestResult(
                    name: "surface_entry_request_round_trip",
                    passed: false,
                    detail: "normalizedArgs lost query on round-trip"
                )
            }
            return KernelPhase1TestResult(
                name: "surface_entry_request_round_trip",
                passed: true,
                detail: "request survived encode→decode with all 11 fields intact"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "surface_entry_request_round_trip",
                passed: false,
                detail: "encode/decode threw: \(error)"
            )
        }
    }

    // MARK: - Test 2: 3 entry event types serialize

    static func testEntryEventTypesSerialize() -> KernelPhase1TestResult {
        let cases: [(MatchingEventType, String)] = [
            (.surfaceEntryRequested, "surface_entry_requested"),
            (.surfaceEntryStarted, "surface_entry_started"),
            (.surfaceEntryReturned, "surface_entry_returned"),
        ]
        for (eventType, expectedRaw) in cases {
            guard eventType.rawValue == expectedRaw else {
                return KernelPhase1TestResult(
                    name: "entry_event_types_serialize",
                    passed: false,
                    detail: "\(eventType) raw value is \(eventType.rawValue), expected \(expectedRaw)"
                )
            }
            let event = MatchingEvent(
                type: eventType,
                sessionId: "sess-1",
                recommendationId: "rec-1",
                candidateId: "cand-1",
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                objectType: "place",
                executionSurfaceType: AppSection.maps.rawValue,
                policyVersion: MatchingPolicyVersion.current.policyVersion,
                surfaceEntryRequestId: "req-1"
            )
            do {
                let data = try event.encodeJSONData()
                let decoded = try MatchingEvent.decode(from: data)
                guard decoded.type == eventType,
                      decoded.surfaceEntryRequestId == "req-1" else {
                    return KernelPhase1TestResult(
                        name: "entry_event_types_serialize",
                        passed: false,
                        detail: "round-trip lost fields for \(expectedRaw)"
                    )
                }
            } catch {
                return KernelPhase1TestResult(
                    name: "entry_event_types_serialize",
                    passed: false,
                    detail: "encode threw for \(expectedRaw): \(error)"
                )
            }
        }
        return KernelPhase1TestResult(
            name: "entry_event_types_serialize",
            passed: true,
            detail: "3 entry event types serialize and carry surfaceEntryRequestId"
        )
    }

    // MARK: - Test 3: ExecutionReturnPayload carries source ids

    static func testExecutionReturnPayloadCarriesRequestIds() -> KernelPhase1TestResult {
        let payload = ExecutionReturnPayload(
            executedCandidateId: "cand-1",
            executionSurfaceType: .maps,
            outcome: .completed,
            duration: 12.5,
            returnContextDelta: .neutral,
            sourceRequestId: "req-1",
            sourceRecommendationId: "rec-1"
        )
        do {
            let data = try payload.encodeJSONData()
            let decoded = try ExecutionReturnPayload.decode(from: data)
            guard decoded.sourceRequestId == "req-1",
                  decoded.sourceRecommendationId == "rec-1" else {
                return KernelPhase1TestResult(
                    name: "execution_return_payload_carries_request_ids",
                    passed: false,
                    detail: "source ids lost on round-trip: requestId=\(decoded.sourceRequestId ?? "nil"), recId=\(decoded.sourceRecommendationId ?? "nil")"
                )
            }
            return KernelPhase1TestResult(
                name: "execution_return_payload_carries_request_ids",
                passed: true,
                detail: "payload links back to sourceRequestId and sourceRecommendationId"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "execution_return_payload_carries_request_ids",
                passed: false,
                detail: "encode/decode threw: \(error)"
            )
        }
    }

    // MARK: - Test 4: MatchingEvent carries surfaceEntryRequestId

    static func testMatchingEventCarriesEntryRequestId() -> KernelPhase1TestResult {
        let event = MatchingEvent(
            type: .surfaceEntryStarted,
            sessionId: "sess-1",
            recommendationId: "rec-1",
            candidateId: "cand-1",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            objectType: "song",
            executionSurfaceType: AppSection.music.rawValue,
            policyVersion: MatchingPolicyVersion.current.policyVersion,
            surfaceEntryRequestId: "req-42"
        )
        do {
            let data = try event.encodeJSONData()
            let decoded = try MatchingEvent.decode(from: data)
            guard decoded.surfaceEntryRequestId == "req-42" else {
                return KernelPhase1TestResult(
                    name: "matching_event_carries_entry_request_id",
                    passed: false,
                    detail: "surfaceEntryRequestId lost on round-trip: \(decoded.surfaceEntryRequestId ?? "nil")"
                )
            }
            guard decoded == event else {
                return KernelPhase1TestResult(
                    name: "matching_event_carries_entry_request_id",
                    passed: false,
                    detail: "event not equal after round-trip"
                )
            }
            return KernelPhase1TestResult(
                name: "matching_event_carries_entry_request_id",
                passed: true,
                detail: "MatchingEvent carries surfaceEntryRequestId through JSON"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "matching_event_carries_entry_request_id",
                passed: false,
                detail: "encode/decode threw: \(error)"
            )
        }
    }
}
