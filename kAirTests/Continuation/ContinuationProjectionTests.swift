//
//  ContinuationProjectionTests.swift
//  kAirTests
//
//  Main D: pins the §6 + §7 invariants for the minimum-shape events
//  produced by `ContinuationProjection.makeEvent(surface:outcome:)`.
//
//  Per `Contracts/UX/continuation-runtime-v1.md`:
//    - §6: renderEligible is true for `.completion` / `.abandon`,
//      false for `.dismiss` / `.acceptNoEntry`.
//    - §7.1: renderEligible == (outcome ∈ {.completion, .abandon}).
//    - §7.2: renderEligible implies summary present.
//    - §7.3: suppressed events carry no sub-payloads.
//    - §7.4/§7.5/§7.6: 3 metrics, continuity at index 2, locked key.
//    - §7.7: outcomeTone matches outcome.
//

import XCTest
@testable import kAir

@MainActor
final class ContinuationProjectionTests: XCTestCase {

    // MARK: - renderEligible derivation (§6 + §7.1)

    func test_completion_isRenderEligible() {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        XCTAssertTrue(event.renderEligible)
        XCTAssertEqual(event.outcome, .completion)
    }

    func test_abandon_isRenderEligible() {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .abandon)
        XCTAssertTrue(event.renderEligible)
        XCTAssertEqual(event.outcome, .abandon)
    }

    func test_dismiss_isNotRenderEligible() {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .dismiss)
        XCTAssertFalse(event.renderEligible)
    }

    func test_acceptNoEntry_isNotRenderEligible() {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .acceptNoEntry)
        XCTAssertFalse(event.renderEligible)
    }

    // MARK: - Sub-payload presence (§7.2 + §7.3)

    func test_completion_hasSummary_noEvidenceOrNextStep() {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        XCTAssertNotNil(event.summary)
        XCTAssertNil(event.evidence)
        XCTAssertNil(event.nextStep)
    }

    func test_abandon_hasSummary_noEvidenceOrNextStep() {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .abandon)
        XCTAssertNotNil(event.summary)
        XCTAssertNil(event.evidence)
        XCTAssertNil(event.nextStep)
    }

    func test_dismiss_carriesNoSubPayloads() {
        let event = ContinuationProjection.makeEvent(surface: .store, outcome: .dismiss)
        XCTAssertNil(event.summary)
        XCTAssertNil(event.evidence)
        XCTAssertNil(event.nextStep)
    }

    func test_acceptNoEntry_carriesNoSubPayloads() {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .acceptNoEntry)
        XCTAssertNil(event.summary)
        XCTAssertNil(event.evidence)
        XCTAssertNil(event.nextStep)
    }

    // MARK: - Summary shape (§7.4/§7.5/§7.6/§7.7)

    func test_summary_hasThreeMetrics_continuityAtIndexTwo() throws {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        let summary = try XCTUnwrap(event.summary)
        XCTAssertEqual(summary.metrics.count, 3)
        XCTAssertEqual(summary.continuityMetricIndex, 2)
        XCTAssertEqual(summary.metrics[2].key, "Thread")
    }

    func test_completionSummary_hasCompletionTone() throws {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .completion)
        let summary = try XCTUnwrap(event.summary)
        XCTAssertEqual(summary.outcomeTone, .completion)
    }

    func test_abandonSummary_hasAbandonTone() throws {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .abandon)
        let summary = try XCTUnwrap(event.summary)
        XCTAssertEqual(summary.outcomeTone, .abandon)
    }

    // MARK: - Validator parity (§7 invariants by construction)

    func test_completionEvent_passesValidator() {
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion)
        let violations = ContinuationEventValidator.validate(event)
        XCTAssertEqual(violations, [], "completion produced violations: \(violations)")
    }

    func test_abandonEvent_passesValidator() {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .abandon)
        let violations = ContinuationEventValidator.validate(event)
        XCTAssertEqual(violations, [], "abandon produced violations: \(violations)")
    }

    func test_dismissEvent_passesValidator() {
        let event = ContinuationProjection.makeEvent(surface: .store, outcome: .dismiss)
        let violations = ContinuationEventValidator.validate(event)
        XCTAssertEqual(violations, [], "dismiss produced violations: \(violations)")
    }

    func test_acceptNoEntryEvent_passesValidator() {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .acceptNoEntry)
        let violations = ContinuationEventValidator.validate(event)
        XCTAssertEqual(violations, [], "acceptNoEntry produced violations: \(violations)")
    }

    func test_validator_passesForAllSurfaceOutcomePairs() {
        // Each of the 8 SurfaceKind × 4 TerminalOutcome pairs must
        // produce a validator-clean event. This pins the projection
        // against future drift in either contract.
        for surface in SurfaceKind.allCases {
            for outcome in TerminalOutcome.allCases {
                let event = ContinuationProjection.makeEvent(surface: surface, outcome: outcome)
                let violations = ContinuationEventValidator.validate(event)
                XCTAssertEqual(
                    violations,
                    [],
                    "(\(surface), \(outcome)) produced violations: \(violations)"
                )
            }
        }
    }

    // MARK: - Identity

    func test_event_surfaceFieldMatchesInput() {
        for surface in SurfaceKind.allCases {
            let event = ContinuationProjection.makeEvent(surface: surface, outcome: .completion)
            XCTAssertEqual(event.surface, surface)
        }
    }

    func test_event_outcomeFieldMatchesInput() {
        for outcome in TerminalOutcome.allCases {
            let event = ContinuationProjection.makeEvent(surface: .maps, outcome: outcome)
            XCTAssertEqual(event.outcome, outcome)
        }
    }

    func test_event_idStartsWithContinuationPrefix() {
        let event = ContinuationProjection.makeEvent(surface: .ai, outcome: .completion)
        XCTAssertTrue(event.id.hasPrefix("continuation-ai-completion-"))
    }

    func test_event_createdAtIsRespected() {
        let pin = Date(timeIntervalSince1970: 1_715_000_000)
        let event = ContinuationProjection.makeEvent(surface: .maps, outcome: .completion, now: pin)
        XCTAssertEqual(event.createdAt, pin)
    }

    // MARK: - isRenderEligible helper

    func test_isRenderEligible_matchesContract() {
        XCTAssertTrue(ContinuationProjection.isRenderEligible(.completion))
        XCTAssertTrue(ContinuationProjection.isRenderEligible(.abandon))
        XCTAssertFalse(ContinuationProjection.isRenderEligible(.dismiss))
        XCTAssertFalse(ContinuationProjection.isRenderEligible(.acceptNoEntry))
    }
}
