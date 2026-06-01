//
//  PlanValidatorTests.swift
//  kAirTests
//
//  A2 pure value contracts: `PlanValidator` gates over `ActionPlan`
//  (kair-ai-model-memory-v1.md §2; PrivacyGuard). Acceptance coverage here:
//  missing slots, confirmation requirement, privacy-blocked health-to-remote
//  route, and low confidence.
//

import XCTest
@testable import kAir

final class PlanValidatorTests: XCTestCase {

    // MARK: - Approved: read-only, confident, complete

    func test_validate_readOnlyConfidentComplete_isApproved() {
        let plan = Self.plan(capability: .placeSearch, risk: .read)
        XCTAssertEqual(PlanValidator.validate(plan), .approved)
    }

    // MARK: - Missing slots (acceptance)

    func test_validate_missingSlots_needsClarification() {
        let plan = Self.plan(
            capability: .routePlanning,
            risk: .read,
            missingSlots: ["destination"]
        )
        XCTAssertEqual(
            PlanValidator.validate(plan),
            .needsClarification(.missingSlots(["destination"]))
        )
    }

    // MARK: - Confirmation requirement (acceptance)

    func test_validate_riskyAction_needsConfirmation() {
        for risk in [ActionRisk.write, .pay, .share, .externalOpen] {
            let plan = Self.plan(capability: .localStoreLookup, risk: risk)
            XCTAssertEqual(
                PlanValidator.validate(plan),
                .needsConfirmation,
                "\(risk) must need confirmation"
            )
        }
    }

    // MARK: - Privacy: health → remote is blocked (acceptance)

    func test_validate_healthOnRemoteModel_isBlocked() {
        for capability in [CapabilityKind.healthRead, .healthWrite] {
            let plan = Self.plan(
                capability: capability,
                risk: .read,
                modelExecution: .remote
            )
            XCTAssertEqual(
                PlanValidator.validate(plan),
                .blocked(.healthToRemoteModel),
                "\(capability) on a remote model must be blocked"
            )
        }
    }

    func test_blockReason_citesReleaseBlockingPrivacyGuardDeny() throws {
        XCTAssertEqual(
            PlanValidation.BlockReason.healthToRemoteModel.privacyRule,
            .healthDataMustNotReachRemoteModel
        )
        let guardrail = try XCTUnwrap(
            PrivacyGuard.guardrail(.healthDataMustNotReachRemoteModel)
        )
        XCTAssertTrue(guardrail.releaseBlocking)
        guard case .deny = guardrail.defaultDecision else {
            return XCTFail("health-to-remote rule must default to deny")
        }
    }

    func test_validate_healthOnDevice_isNotBlockedByPrivacy() {
        let plan = Self.plan(capability: .healthRead, risk: .read, modelExecution: .onDevice)
        XCTAssertEqual(PlanValidator.validate(plan), .approved)
    }

    // MARK: - Low confidence (acceptance)

    func test_validate_lowConfidence_needsClarification() {
        let plan = Self.plan(capability: .placeSearch, risk: .read, confidence: .low)
        XCTAssertEqual(PlanValidator.validate(plan), .needsClarification(.lowConfidence))
    }

    // MARK: - Privacy outranks the other gates

    func test_validate_healthRemote_blockedEvenWhenAlsoLowAndIncomplete() {
        let plan = Self.plan(
            capability: .healthRead,
            risk: .write,
            confidence: .low,
            modelExecution: .remote,
            missingSlots: ["range"]
        )
        XCTAssertEqual(PlanValidator.validate(plan), .blocked(.healthToRemoteModel))
    }

    // MARK: - ActionPlan.make derives surface + carries intent fields

    func test_actionPlanMake_derivesSurfaceFromCapability() {
        let intent = IntentDraft(
            intentID: "i",
            language: "en",
            capability: CapabilityKind.routePlanning.rawValue,
            surface: nil,
            risk: .read,
            confidence: .high,
            requiresConfirmation: false,
            slots: [],
            missingSlots: [],
            userVisibleSummary: "go"
        )
        let plan = ActionPlan.make(from: intent, capability: .routePlanning, modelExecution: .onDevice)
        XCTAssertEqual(plan.surface, .maps)
        XCTAssertEqual(plan.intentID, "i")
        XCTAssertEqual(plan.capability, .routePlanning)
        XCTAssertEqual(PlanValidator.validate(plan), .approved)
    }

    // MARK: - Fixtures

    private static func plan(
        capability: CapabilityKind,
        risk: ActionRisk,
        confidence: IntentConfidence = .high,
        modelExecution: ModelExecution = .onDevice,
        missingSlots: [String] = []
    ) -> ActionPlan {
        ActionPlan(
            intentID: "plan-1",
            capability: capability,
            slots: [],
            missingSlots: missingSlots,
            risk: risk,
            confidence: confidence,
            modelExecution: modelExecution,
            userVisibleSummary: "Test plan"
        )
    }
}
