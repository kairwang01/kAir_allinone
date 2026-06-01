//
//  IntentDraftContractTests.swift
//  kAirTests
//
//  A2 pure value contracts: `IntentDraft` shape + `CapabilityRouter` routing
//  (kair-ai-model-memory-v1.md §2). Acceptance coverage here: capability
//  route, and unknown-intent fallback.
//

import XCTest
@testable import kAir

final class IntentDraftContractTests: XCTestCase {

    // MARK: - IntentDraft is the typed, Codable router contract (§2)

    func test_intentDraft_codableRoundTrip() throws {
        let draft = Self.routePlanningDraft()
        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(IntentDraft.self, from: data)
        XCTAssertEqual(decoded, draft)
    }

    func test_intentDraft_decodesArchitectureJSONContract() throws {
        let json = """
        {
          "intent_id": "intent-json",
          "language": "zh-Hans",
          "surface": "maps",
          "capability": "routePlanning",
          "risk": "externalOpen",
          "confidence": 0.82,
          "requires_confirmation": true,
          "slots": {
            "destination": "Union Station",
            "origin": "current_location"
          },
          "missing_slots": [],
          "user_visible_summary": "准备打开路线规划"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        let decoded = try JSONDecoder().decode(IntentDraft.self, from: data)

        XCTAssertEqual(decoded.intentID, "intent-json")
        XCTAssertEqual(decoded.language, "zh-Hans")
        XCTAssertEqual(decoded.surface, "maps")
        XCTAssertEqual(decoded.capability, CapabilityKind.routePlanning.rawValue)
        XCTAssertEqual(decoded.risk, .externalOpen)
        XCTAssertEqual(decoded.confidence.score, 0.82)
        XCTAssertTrue(decoded.requiresConfirmation)
        XCTAssertEqual(
            decoded.slots,
            [
                IntentSlot(name: "destination", value: "Union Station"),
                IntentSlot(name: "origin", value: "current_location"),
            ]
        )
        XCTAssertEqual(decoded.missingSlots, [])
        XCTAssertEqual(decoded.userVisibleSummary, "准备打开路线规划")
    }

    func test_intentDraft_encodesArchitectureJSONContractShape() throws {
        let draft = IntentDraft(
            intentID: "intent-encode",
            language: "en",
            capability: CapabilityKind.placeSearch.rawValue,
            surface: SurfaceKind.maps.rawValue,
            risk: .read,
            confidence: IntentConfidence(score: 0.9),
            requiresConfirmation: false,
            slots: [
                IntentSlot(name: "query", value: "coffee"),
                IntentSlot(name: "near", value: "home"),
            ],
            missingSlots: [],
            userVisibleSummary: "Find coffee nearby"
        )

        let data = try JSONEncoder().encode(draft)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let slots = try XCTUnwrap(object["slots"] as? [String: String])

        XCTAssertEqual(object["intent_id"] as? String, "intent-encode")
        XCTAssertNil(object["intentID"])
        XCTAssertEqual(object["requires_confirmation"] as? Bool, false)
        XCTAssertNil(object["requiresConfirmation"])
        XCTAssertEqual(object["missing_slots"] as? [String], [])
        XCTAssertNil(object["missingSlots"])
        XCTAssertEqual(object["user_visible_summary"] as? String, "Find coffee nearby")
        XCTAssertNil(object["userVisibleSummary"])
        XCTAssertEqual(object["confidence"] as? Double, 0.9)
        XCTAssertEqual(slots, ["query": "coffee", "near": "home"])
    }

    // MARK: - ActionRisk confirmation classes (§2)

    func test_actionRisk_onlyReadIsExemptFromConfirmation() {
        XCTAssertFalse(ActionRisk.read.requiresConfirmation)
        for risk in [ActionRisk.write, .pay, .share, .externalOpen] {
            XCTAssertTrue(risk.requiresConfirmation, "\(risk) must require confirmation")
        }
    }

    // MARK: - Confidence threshold (§2)

    func test_confidence_lowCannotExecute_highCan() {
        XCTAssertFalse(IntentConfidence.low.canExecute)
        XCTAssertTrue(IntentConfidence.low.isLow)
        XCTAssertTrue(IntentConfidence.high.canExecute)
        XCTAssertFalse(IntentConfidence.high.isLow)
    }

    // MARK: - CapabilityRouter: capability route (acceptance)

    func test_router_resolvesKnownCapabilityToSurface() {
        let draft = Self.routePlanningDraft()   // capability "routePlanning"
        XCTAssertEqual(
            CapabilityRouter.route(draft),
            .resolved(capability: .routePlanning, surface: .maps)
        )
    }

    func test_router_resolvesEveryCapabilityKindToItsSurfaceFamily() {
        for capability in CapabilityKind.allCases {
            let draft = Self.draft(capability: capability.rawValue)
            XCTAssertEqual(
                CapabilityRouter.route(draft),
                .resolved(capability: capability, surface: capability.surfaceFamily)
            )
        }
    }

    // MARK: - CapabilityRouter: unknown intent fallback (acceptance)

    func test_router_nilCapability_isUnknownFallback() {
        let draft = Self.draft(capability: nil)
        XCTAssertEqual(CapabilityRouter.route(draft), .unresolved(reason: .unknownCapability))
    }

    func test_router_unrecognizedCapability_isUnknownFallback() {
        let draft = Self.draft(capability: "teleport")   // not a CapabilityKind
        XCTAssertEqual(CapabilityRouter.route(draft), .unresolved(reason: .unknownCapability))
        XCTAssertNil(CapabilityRouter.route(draft).capability)
    }

    // MARK: - Fixtures

    private static func routePlanningDraft() -> IntentDraft {
        draft(
            capability: CapabilityKind.routePlanning.rawValue,
            slots: [IntentSlot(name: "destination", value: "Union Station")]
        )
    }

    private static func draft(
        capability: String?,
        risk: ActionRisk = .read,
        confidence: IntentConfidence = .high,
        slots: [IntentSlot] = [],
        missingSlots: [String] = []
    ) -> IntentDraft {
        IntentDraft(
            intentID: "intent-1",
            language: "en",
            capability: capability,
            surface: nil,
            risk: risk,
            confidence: confidence,
            requiresConfirmation: risk.requiresConfirmation,
            slots: slots,
            missingSlots: missingSlots,
            userVisibleSummary: "Test intent"
        )
    }
}
