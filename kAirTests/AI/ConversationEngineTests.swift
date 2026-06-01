//
//  ConversationEngineTests.swift
//  kAirTests
//
//  Kernel A5 skeleton: `ConversationEngine.resolve` composes the ratified A2
//  pipeline (CapabilityRouter → ActionPlan → PlanValidator) into one terminal
//  outcome. Pure orchestration — no model, no dispatch, no ChatStore. Coverage:
//  ready/confirm/clarify(low+slots)/blocked(health-remote)/unresolved, and the
//  health-on-device approval.
//

import XCTest
@testable import kAir

final class ConversationEngineTests: XCTestCase {

    func test_readOnlyConfidentComplete_readyToDispatch() {
        let outcome = ConversationEngine.resolve(
            Self.draft(capability: CapabilityKind.placeSearch.rawValue)
        )
        guard case .readyToDispatch(let plan) = outcome else {
            return XCTFail("expected readyToDispatch, got \(outcome)")
        }
        XCTAssertEqual(plan.capability, .placeSearch)
        XCTAssertEqual(plan.surface, .maps)
    }

    func test_riskyAction_needsConfirmation() {
        let outcome = ConversationEngine.resolve(
            Self.draft(capability: CapabilityKind.localStoreLookup.rawValue, risk: .pay)
        )
        guard case .needsConfirmation = outcome else {
            return XCTFail("expected needsConfirmation, got \(outcome)")
        }
    }

    func test_lowConfidence_needsClarification() {
        let outcome = ConversationEngine.resolve(
            Self.draft(capability: CapabilityKind.placeSearch.rawValue, confidence: .low)
        )
        XCTAssertEqual(outcome, .needsClarification(.lowConfidence))
    }

    func test_missingSlots_needsClarification() {
        let outcome = ConversationEngine.resolve(
            Self.draft(capability: CapabilityKind.routePlanning.rawValue, missingSlots: ["destination"])
        )
        XCTAssertEqual(outcome, .needsClarification(.missingSlots(["destination"])))
    }

    func test_healthOnRemoteModel_isBlocked() {
        let outcome = ConversationEngine.resolve(
            Self.draft(capability: CapabilityKind.healthRead.rawValue),
            modelExecution: .remote
        )
        XCTAssertEqual(outcome, .blocked(.healthToRemoteModel))
    }

    func test_healthOnDevice_readyToDispatch() {
        let outcome = ConversationEngine.resolve(
            Self.draft(capability: CapabilityKind.healthRead.rawValue),
            modelExecution: .onDevice
        )
        guard case .readyToDispatch = outcome else {
            return XCTFail("health read on-device should be dispatchable, got \(outcome)")
        }
    }

    func test_unknownCapability_isUnresolved() {
        XCTAssertEqual(ConversationEngine.resolve(Self.draft(capability: "teleport")), .unresolved)
        XCTAssertEqual(ConversationEngine.resolve(Self.draft(capability: nil)), .unresolved)
    }

    // MARK: - Fixture

    private static func draft(
        capability: String?,
        risk: ActionRisk = .read,
        confidence: IntentConfidence = .high,
        missingSlots: [String] = []
    ) -> IntentDraft {
        IntentDraft(
            intentID: "intent",
            language: "en",
            capability: capability,
            surface: nil,
            risk: risk,
            confidence: confidence,
            requiresConfirmation: risk.requiresConfirmation,
            slots: [],
            missingSlots: missingSlots,
            userVisibleSummary: "summary"
        )
    }
}
