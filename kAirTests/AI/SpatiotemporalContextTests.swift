//
//  SpatiotemporalContextTests.swift
//  kAirTests
//
//  Reserved interface R6 (kair-architecture-redesign-v2.md §5.6): life-service
//  time/place grounding + the N≤5 agent loop budget. Pure values; caller-
//  injected time/place keep it deterministic.
//

import XCTest
@testable import kAir

final class SpatiotemporalContextTests: XCTestCase {

    // MARK: - SpatiotemporalContext

    func test_promptGroundingPrefix_includesPlaceLocaleRegionDay() {
        let prefix = Self.context().promptGroundingPrefix
        XCTAssertTrue(prefix.contains("Chaoyang"))
        XCTAssertTrue(prefix.contains("zh-Hans"))
        XCTAssertTrue(prefix.contains("china"))
        XCTAssertTrue(prefix.contains("saturday"))
    }

    func test_dayOfWeek_weekendClassification() {
        XCTAssertTrue(SpatiotemporalContext.DayOfWeek.saturday.isWeekend)
        XCTAssertTrue(SpatiotemporalContext.DayOfWeek.sunday.isWeekend)
        XCTAssertFalse(SpatiotemporalContext.DayOfWeek.monday.isWeekend)
    }

    func test_codableRoundTrip() throws {
        let context = Self.context()
        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(SpatiotemporalContext.self, from: data)
        XCTAssertEqual(decoded, context)
    }

    // MARK: - AgentLoopBudget

    func test_lifeServiceDefault_isFiveRoundsPlanFirst() {
        let budget = AgentLoopBudget.lifeServiceDefault
        XCTAssertEqual(budget.maxToolRounds, 5)
        XCTAssertTrue(budget.requirePlanFirst)
    }

    func test_allowsRound_capsAtBudget() {
        let budget = AgentLoopBudget(maxToolRounds: 5)
        XCTAssertTrue(budget.allowsRound(4))
        XCTAssertFalse(budget.allowsRound(5))
        XCTAssertFalse(budget.allowsRound(6))
    }

    func test_allowsToolCall_requiresPlanFirstAndBudget() {
        let planFirst = AgentLoopBudget(maxToolRounds: 5, requirePlanFirst: true)
        XCTAssertFalse(planFirst.allowsToolCall(usedRounds: 0, hasPlan: false))
        XCTAssertTrue(planFirst.allowsToolCall(usedRounds: 0, hasPlan: true))
        XCTAssertFalse(planFirst.allowsToolCall(usedRounds: 5, hasPlan: true)) // over budget

        let noPlan = AgentLoopBudget(maxToolRounds: 5, requirePlanFirst: false)
        XCTAssertTrue(noPlan.allowsToolCall(usedRounds: 0, hasPlan: false))
    }

    // MARK: - Fixture

    private static func context() -> SpatiotemporalContext {
        SpatiotemporalContext(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            dayOfWeek: .saturday,
            coarseLocation: "Chaoyang",
            region: .china,
            locale: "zh-Hans",
            weather: .clear
        )
    }
}
