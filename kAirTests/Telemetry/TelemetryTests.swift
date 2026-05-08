//
//  TelemetryTests.swift
//  kAirTests
//
//  Skeleton-level tests for the v1 telemetry vocabulary. Each test
//  pins a clause from Contracts/telemetry-contract-v1.md so future
//  edits to this skeleton or to downstream emitters fail loudly when
//  they drift from the contract.
//
//  Coverage:
//  - Identifier wrappers round-trip (§3 + §3.2).
//  - Event raw values match the strings frozen in §4.1.
//  - `surfaceEnterName(for:)` / `surfaceReturnName(for:)` produce the
//    `surface.<kind>.enter` / `surface.<kind>.return` form for all
//    eight surfaces (§4.1).
//  - The §5.2 propagation matrix passes for a well-formed
//    `chat.prompt.submit` payload.
//  - The matrix flags `.missingRequiredID` for an under-filled
//    `rail.card.impression` payload.
//  - The matrix flags `.forbiddenIDPresent` when an id forbidden by
//    §5.2 (`✗`) appears on `chat.prompt.submit`.
//  - The no-op emitter does not crash.
//  - Naming sanity: every `TelemetryEvent.allCases` raw value is
//    non-empty and dotted-lowercase per §4.2.
//

import XCTest
@testable import kAir

final class TelemetryTests: XCTestCase {

    // MARK: - §3: Identifier wrappers round-trip raw strings

    func testTraceIDRoundTripsRawString() {
        let raw = "trace-abc"
        let id = TraceID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(TraceID(rawValue: raw), id)
    }

    func testThreadIDRoundTripsRawString() {
        let raw = "thread-xyz"
        let id = ThreadID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(ThreadID(rawValue: raw), id)
    }

    func testRecommendationIDRoundTripsRawString() {
        let raw = "rec-1"
        let id = RecommendationID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(RecommendationID(rawValue: raw), id)
    }

    func testSourceRequestIDRoundTripsRawString() {
        let raw = "src-req-1"
        let id = SourceRequestID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(SourceRequestID(rawValue: raw), id)
    }

    func testSourceRecommendationIDRoundTripsRawString() {
        let raw = "src-rec-1"
        let id = SourceRecommendationID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(SourceRecommendationID(rawValue: raw), id)
    }

    func testSurfaceSessionIDRoundTripsRawString() {
        let raw = "surface-1"
        let id = SurfaceSessionID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(SurfaceSessionID(rawValue: raw), id)
    }

    func testFeedbackChainIDRoundTripsRawString() {
        let raw = "feedback-1"
        let id = FeedbackChainID(raw)
        XCTAssertEqual(id.rawValue, raw)
        XCTAssertEqual(FeedbackChainID(rawValue: raw), id)
    }

    // MARK: - §4.1: Event raw values match contract

    func testTelemetryEventRawValues() {
        XCTAssertEqual(TelemetryEvent.chatPromptSubmit.rawValue, "chat.prompt.submit")
        XCTAssertEqual(TelemetryEvent.intentDecide.rawValue, "intent.decide")
        XCTAssertEqual(TelemetryEvent.railSlateMaterialize.rawValue, "rail.slate.materialize")
        XCTAssertEqual(TelemetryEvent.railCardImpression.rawValue, "rail.card.impression")
        XCTAssertEqual(TelemetryEvent.railCardAccept.rawValue, "rail.card.accept")
        XCTAssertEqual(TelemetryEvent.railCardDismiss.rawValue, "rail.card.dismiss")
        XCTAssertEqual(TelemetryEvent.surfaceEnter.rawValue, "surface.enter")
        XCTAssertEqual(TelemetryEvent.surfaceReturn.rawValue, "surface.return")
        XCTAssertEqual(TelemetryEvent.transcriptContinuationAppend.rawValue, "transcript.continuation.append")
        XCTAssertEqual(TelemetryEvent.transcriptContinuationSilent.rawValue, "transcript.continuation.silent")
        XCTAssertEqual(TelemetryEvent.feedbackEvent.rawValue, "feedback.event")
    }

    func testTelemetryEventAllCasesCount() {
        // Per §4.1, the v1 frozen vocabulary has exactly 11 events.
        XCTAssertEqual(TelemetryEvent.allCases.count, 11)
    }

    // MARK: - §4.1: surface.<kind>.{enter,return} dotted form

    func testSurfaceEnterNameForAllSurfaces() {
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .chat), "surface.chat.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .health), "surface.health.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .ai), "surface.ai.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .maps), "surface.maps.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .store), "surface.store.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .music), "surface.music.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .video), "surface.video.enter")
        XCTAssertEqual(TelemetryEvent.surfaceEnterName(for: .search), "surface.search.enter")
    }

    func testSurfaceReturnNameForAllSurfaces() {
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .chat), "surface.chat.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .health), "surface.health.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .ai), "surface.ai.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .maps), "surface.maps.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .store), "surface.store.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .music), "surface.music.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .video), "surface.video.return")
        XCTAssertEqual(TelemetryEvent.surfaceReturnName(for: .search), "surface.search.return")
    }

    func testSurfaceKindHasAllEightCases() {
        // Per §4: the `<kind>` placeholder is filled with one of the
        // eight `SurfaceKind` values from continuation-runtime-v1.md
        // §2.1 (chat / health / ai / maps / store / music / video /
        // search). The canonical type MUST host that set.
        XCTAssertEqual(SurfaceKind.allCases.count, 8)
    }

    // MARK: - §5.2: propagation matrix happy path

    func testPropagationMatrixAcceptsWellFormedChatPromptSubmit() {
        let payload = TelemetryEventPayload(
            traceID: TraceID("T1"),
            threadID: ThreadID("H7")
        )
        let violations = TelemetryPropagationMatrix.violations(.chatPromptSubmit, payload)
        XCTAssertTrue(
            violations.isEmpty,
            "Expected no violations for well-formed chat.prompt.submit; got \(violations)"
        )
    }

    // MARK: - §5.2: missing-required violation

    func testPropagationMatrixFlagsMissingRequiredIDForRailCardImpression() {
        // rail.card.impression requires trace_id, thread_id,
        // recommendation_id, source_request_id. We deliberately leave
        // recommendation_id and source_request_id unset.
        let payload = TelemetryEventPayload(
            traceID: TraceID("T1"),
            threadID: ThreadID("H7")
        )
        let violations = TelemetryPropagationMatrix.violations(.railCardImpression, payload)

        let missingRecommendationID = violations.contains(
            .missingRequiredID(event: .railCardImpression, id: .recommendationID)
        )
        let missingSourceRequestID = violations.contains(
            .missingRequiredID(event: .railCardImpression, id: .sourceRequestID)
        )

        XCTAssertTrue(
            missingRecommendationID,
            "Expected .missingRequiredID(.recommendationID) for rail.card.impression"
        )
        XCTAssertTrue(
            missingSourceRequestID,
            "Expected .missingRequiredID(.sourceRequestID) for rail.card.impression"
        )
    }

    // MARK: - §5.2: forbidden-id violation

    func testPropagationMatrixFlagsForbiddenIDOnChatPromptSubmit() {
        // chat.prompt.submit forbids recommendation_id (✗ in §5.2).
        let payload = TelemetryEventPayload(
            traceID: TraceID("T1"),
            threadID: ThreadID("H7"),
            recommendationID: RecommendationID("R1")
        )
        let violations = TelemetryPropagationMatrix.violations(.chatPromptSubmit, payload)

        let forbiddenRec = violations.contains(
            .forbiddenIDPresent(event: .chatPromptSubmit, id: .recommendationID)
        )
        XCTAssertTrue(
            forbiddenRec,
            "Expected .forbiddenIDPresent(.recommendationID) for chat.prompt.submit"
        )
    }

    // MARK: - Emitter sanity

    func testNoOpEmitterDoesNotCrash() async {
        let emitter: TelemetryEmitter = NoOpTelemetryEmitter()
        let payload = TelemetryEventPayload(
            traceID: TraceID("T1"),
            threadID: ThreadID("H7")
        )
        // Calling emit should complete without throwing or crashing.
        // No assertion needed beyond reaching the next line.
        await emitter.emit(.chatPromptSubmit, payload)
    }

    // MARK: - §4.2: naming-rule sanity

    func testEveryEventRawValueIsNonEmptyAndDottedLowercase() {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz.")
        for event in TelemetryEvent.allCases {
            let raw = event.rawValue
            XCTAssertFalse(raw.isEmpty, "Event \(event) has empty raw value")

            for character in raw {
                XCTAssertTrue(
                    allowed.contains(character),
                    "Event \(event) raw value \"\(raw)\" contains disallowed character \"\(character)\" — §4.2 requires dotted-lowercase ASCII"
                )
            }

            // §4.2: dotted form. Every event name has at least one `.`
            // separator (the un-templated `surface.enter` /
            // `surface.return` and every other event have ≥ 2
            // segments).
            XCTAssertTrue(
                raw.contains("."),
                "Event \(event) raw value \"\(raw)\" must be dotted per §4.2"
            )
        }
    }
}
