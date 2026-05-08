//
//  FeedbackEventTests.swift
//  kAirTests
//
//  Skeleton coverage for `FeedbackEvent`, `FeedbackEventValidator`,
//  and the `NoOpFeedbackRuntime` stub.
//
//  Mirrors `Contracts/UX/feedback-runtime-v1.md`:
//    - §3 (envelope fields, types, optionality)
//    - §3.1 (5 frozen `MatchingFeedbackKind` cases)
//    - §8.1 / §8.3 / §8.4 (validation rules implemented at the
//      pure-function layer)
//
//  Out of scope for this skeleton (deferred to I4):
//    - §8.4 second clause (per-session id uniqueness)
//    - §8.5 (`recommendationId` corresponds to a present recommendation
//      in `recommendedMatches`)
//    - The transcript-silence assertion against
//      `ChatStore.dismissRecommendation(_:feedback:)` — the skeleton
//      deliberately does NOT touch `ChatStore`. The §14.1 ratification
//      checklist's transcript-silence test will land alongside I4
//      wiring.
//

import XCTest
@testable import kAir

final class FeedbackEventTests: XCTestCase {
    // MARK: - Fixtures

    /// A canonical, fully-populated envelope. Tests that need a
    /// "good" event start from this base and mutate one field at a
    /// time so violations isolate cleanly.
    private func wellFormedEvent(
        id: String = "evt-0001",
        recommendationId: String = "rec-abc",
        feedbackKind: MatchingFeedbackKind = .dismiss,
        surface: SurfaceKind? = .chat,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> FeedbackEvent {
        FeedbackEvent(
            id: id,
            recommendationId: recommendationId,
            feedbackKind: feedbackKind,
            surface: surface,
            createdAt: createdAt,
            traceId: "trace-1",
            threadId: "thread-1",
            sourceRequestId: "req-1",
            feedbackChainId: "chain-1"
        )
    }

    // MARK: - Construction round-trip (contract §3)

    /// All required fields and all optional chain identifiers
    /// round-trip through the memberwise initializer unchanged.
    func test_construction_preservesAllFields() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let event = FeedbackEvent(
            id: "evt-1",
            recommendationId: "rec-1",
            feedbackKind: .lessLikeThis,
            surface: .health,
            createdAt: createdAt,
            traceId: "tr-1",
            threadId: "th-1",
            sourceRequestId: "rq-1",
            feedbackChainId: "ch-1"
        )

        XCTAssertEqual(event.id, "evt-1")
        XCTAssertEqual(event.recommendationId, "rec-1")
        XCTAssertEqual(event.feedbackKind, .lessLikeThis)
        XCTAssertEqual(event.surface, .health)
        XCTAssertEqual(event.createdAt, createdAt)
        XCTAssertEqual(event.traceId, "tr-1")
        XCTAssertEqual(event.threadId, "th-1")
        XCTAssertEqual(event.sourceRequestId, "rq-1")
        XCTAssertEqual(event.feedbackChainId, "ch-1")
    }

    /// `surface` and the chain identifiers are optional per §3 and
    /// default to `nil` in the convenience initializer.
    func test_construction_optionalFieldsDefaultToNil() {
        let event = FeedbackEvent(
            id: "evt-x",
            recommendationId: "rec-x",
            feedbackKind: .notNow,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertNil(event.surface)
        XCTAssertNil(event.traceId)
        XCTAssertNil(event.threadId)
        XCTAssertNil(event.sourceRequestId)
        XCTAssertNil(event.feedbackChainId)
    }

    /// `Identifiable` conformance: `id` is the canonical identifier.
    func test_identifiable_idIsCanonicalIdentifier() {
        let event = wellFormedEvent(id: "evt-canonical")
        XCTAssertEqual(event.id, "evt-canonical")
    }

    // MARK: - Validator (contract §8)

    /// Well-formed event passes every pure-function rule.
    func test_validator_wellFormedEventReturnsNoViolations() {
        let event = wellFormedEvent()
        let violations = FeedbackEventValidator.validate(
            event,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(violations, [])
    }

    /// §8.1 — empty `recommendationId` is rejected with
    /// `.recommendationIdEmpty`.
    func test_validator_emptyRecommendationIdProducesViolation() {
        let event = wellFormedEvent(recommendationId: "")
        let violations = FeedbackEventValidator.validate(
            event,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(
            violations.contains(.recommendationIdEmpty),
            "expected .recommendationIdEmpty in \(violations)"
        )
    }

    /// §8.4 — empty `id` is rejected with `.idEmpty`.
    func test_validator_emptyIdProducesViolation() {
        let event = wellFormedEvent(id: "")
        let violations = FeedbackEventValidator.validate(
            event,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(
            violations.contains(.idEmpty),
            "expected .idEmpty in \(violations)"
        )
    }

    /// §8.3 — `createdAt` more than the skew tolerance into the
    /// future is rejected with `.createdAtInFuture`.
    /// Here, the event's `createdAt` is one hour past `now`.
    func test_validator_futureCreatedAtProducesViolation() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oneHour: TimeInterval = 60 * 60
        let event = wellFormedEvent(createdAt: now.addingTimeInterval(oneHour))

        let violations = FeedbackEventValidator.validate(event, now: now)
        XCTAssertTrue(
            violations.contains(.createdAtInFuture),
            "expected .createdAtInFuture in \(violations)"
        )
    }

    /// §8.3 — events whose `createdAt` is within the skew tolerance
    /// (≤ 5s past `now`) are accepted. Pin to the boundary.
    func test_validator_slightlyFutureCreatedAtWithinSkewIsAccepted() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let event = wellFormedEvent(
            createdAt: now.addingTimeInterval(
                FeedbackEventValidator.skewToleranceSeconds
            )
        )

        let violations = FeedbackEventValidator.validate(event, now: now)
        XCTAssertFalse(
            violations.contains(.createdAtInFuture),
            "expected NO .createdAtInFuture for event at the skew boundary; got \(violations)"
        )
    }

    /// Multiple violations accumulate — the validator is not a
    /// short-circuit. An event that violates §8.1 and §8.4 reports
    /// both.
    func test_validator_multipleViolationsAccumulate() {
        let event = wellFormedEvent(id: "", recommendationId: "")
        let violations = FeedbackEventValidator.validate(
            event,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(violations.contains(.recommendationIdEmpty))
        XCTAssertTrue(violations.contains(.idEmpty))
    }

    // MARK: - All MatchingFeedbackKind cases (§3.1)

    /// Each of the 5 frozen `MatchingFeedbackKind` cases can produce a
    /// valid `FeedbackEvent`. The validator returns no violations for
    /// any of them.
    func test_allFeedbackKinds_produceValidEvents() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        for kind in MatchingFeedbackKind.allCases {
            let event = wellFormedEvent(feedbackKind: kind, createdAt: now)
            let violations = FeedbackEventValidator.validate(event, now: now)
            XCTAssertEqual(
                violations,
                [],
                "kind \(kind) should produce a valid event; got \(violations)"
            )
        }
    }

    /// The 5 frozen cases match the contract §3.1 vocabulary
    /// (defensive — type-level guarantee plus a runtime sanity
    /// check). Adding a 6th case requires a coordinated v2 of the
    /// behavior, visual, and runtime contracts.
    func test_matchingFeedbackKind_hasExactlyFiveFrozenCases() {
        XCTAssertEqual(MatchingFeedbackKind.allCases.count, 5)
        XCTAssertEqual(
            Set(MatchingFeedbackKind.allCases),
            [.dismiss, .notInterested, .lessLikeThis, .notNow, .alreadyDone]
        )
    }

    // MARK: - NoOpFeedbackRuntime stub (§5.2)

    /// The no-op stub never throws, regardless of the event passed
    /// in. Suitable for SwiftUI previews and the test scaffold.
    func test_noOpRuntime_emitDoesNotThrow() async {
        let runtime: FeedbackRuntime = NoOpFeedbackRuntime()
        let event = wellFormedEvent()

        do {
            try await runtime.emit(event)
        } catch {
            XCTFail("NoOpFeedbackRuntime should not throw; got \(error)")
        }
    }

    /// The stub also accepts events that would otherwise fail
    /// validation — the stub is intentionally inert and does not
    /// pre-validate. Real runtime implementations will pre-validate
    /// per §6.3 step 2.
    func test_noOpRuntime_acceptsInvalidEventsWithoutThrowing() async {
        let runtime: FeedbackRuntime = NoOpFeedbackRuntime()
        let invalid = wellFormedEvent(id: "", recommendationId: "")

        do {
            try await runtime.emit(invalid)
        } catch {
            XCTFail("NoOpFeedbackRuntime should be inert; got \(error)")
        }
    }
}
