//
//  ModelTierRouterTests.swift
//  kAirTests
//
//  Reserved interface R2 (kair-architecture-redesign-v2.md §5.2): cost-aware
//  model-tier cascade. Coverage: the hard health/private gate before the cost
//  cascade, confident-local selection, low-confidence escalation only when
//  entitled, no-silent-paid fallback, the cost ordering, and the safety
//  invariant that health/private context never reaches a remote model.
//

import XCTest
@testable import kAir

final class ModelTierRouterTests: XCTestCase {

    // MARK: - Hard gate: health is local-only before any cost/confidence

    func test_health_routesToLocalSpecialist_evenLowConfidenceEntitledPro() {
        for capability in [CapabilityKind.healthRead, .healthWrite] {
            let decision = ModelTierRouter.route(
                ModelTierRequest(
                    capability: capability,
                    confidence: .low,
                    privacyClass: .general,
                    membershipTier: .pro,
                    paidRemoteEntitled: true
                )
            )
            XCTAssertEqual(decision.tier, .localSpecialist)
            XCTAssertEqual(decision.reason, .healthLocalOnly)
            XCTAssertFalse(decision.escalatedToPaid)
            XCTAssertFalse(decision.isRemote)
        }
    }

    // MARK: - Private (non-general) context stays local

    func test_private_staysLocal_evenLowConfidenceEntitled() {
        let decision = ModelTierRouter.route(
            ModelTierRequest(
                capability: .placeSearch,
                confidence: .low,
                privacyClass: .private,
                membershipTier: .pro,
                paidRemoteEntitled: true
            )
        )
        XCTAssertFalse(decision.isRemote)
        XCTAssertEqual(decision.tier, .localPlanner)   // placeSearch → planner
        XCTAssertEqual(decision.reason, .privateLocalOnly)
    }

    // MARK: - Confident + general → cheapest covering local tier

    func test_confidentGeneral_usesCheapestCoveringLocalTier() {
        let lookup = ModelTierRouter.route(
            ModelTierRequest(capability: .threadLookup, confidence: .high)
        )
        XCTAssertEqual(lookup.tier, .localRouter)
        XCTAssertEqual(lookup.reason, .confidentLocal)

        let planning = ModelTierRouter.route(
            ModelTierRequest(capability: .routePlanning, confidence: .high)
        )
        XCTAssertEqual(planning.tier, .localPlanner)
        XCTAssertFalse(planning.isRemote)
    }

    // MARK: - Low confidence cascade: escalate only when entitled

    func test_lowConfidenceGeneralEntitled_escalatesToPaidRemote() {
        let decision = ModelTierRouter.route(
            ModelTierRequest(
                capability: .aiCompletion,
                confidence: .low,
                privacyClass: .general,
                membershipTier: .pro,
                paidRemoteEntitled: true
            )
        )
        XCTAssertEqual(decision.tier, .paidRemote)
        XCTAssertTrue(decision.escalatedToPaid)
        XCTAssertEqual(decision.reason, .escalatedLowConfidence)
    }

    func test_lowConfidenceGeneralNotEntitled_fallsBackLocal_noSilentPaid() {
        let decision = ModelTierRouter.route(
            ModelTierRequest(
                capability: .aiCompletion,
                confidence: .low,
                privacyClass: .general,
                membershipTier: .free,
                paidRemoteEntitled: false
            )
        )
        XCTAssertFalse(decision.isRemote)
        XCTAssertFalse(decision.escalatedToPaid)
        XCTAssertEqual(decision.reason, .paidUnavailableLocalFallback)
    }

    // MARK: - Cost ordering

    func test_costRank_isMonotonicCheapToExpensive() {
        XCTAssertLessThan(ModelTier.localRouter.costRank, ModelTier.localPlanner.costRank)
        XCTAssertLessThan(ModelTier.localPlanner.costRank, ModelTier.localSpecialist.costRank)
        XCTAssertLessThan(ModelTier.localSpecialist.costRank, ModelTier.paidRemote.costRank)
        XCTAssertTrue(ModelTier.paidRemote.isRemote)
        XCTAssertFalse(ModelTier.localRouter.isRemote)
    }

    // MARK: - Safety invariant: health/private never reaches a remote model

    func test_invariant_healthOrPrivateNeverRoutesToPaidRemote() {
        for capability in CapabilityKind.allCases {
            for privacy in [ProviderPrivacyClass.general, .private, .health] {
                let decision = ModelTierRouter.route(
                    ModelTierRequest(
                        capability: capability,
                        confidence: .low,            // worst case for escalation
                        privacyClass: privacy,
                        membershipTier: .developerInternal,
                        paidRemoteEntitled: true     // maximally permissive
                    )
                )
                let isHealthCap = capability == .healthRead || capability == .healthWrite
                if isHealthCap || privacy != .general {
                    XCTAssertFalse(
                        decision.isRemote,
                        "\(capability)/\(privacy) must stay local"
                    )
                    XCTAssertNotEqual(decision.tier, .paidRemote)
                }
            }
        }
    }
}
