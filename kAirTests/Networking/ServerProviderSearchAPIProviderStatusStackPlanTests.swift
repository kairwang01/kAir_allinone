//
//  ServerProviderSearchAPIProviderStatusStackPlanTests.swift
//  kAirTests
//
//  A169 Search API provider-status stack plan tests.
//

import XCTest
@testable import kAir

final class ServerProviderSearchAPIProviderStatusStackPlanTests: XCTestCase {

    func test_defaultPlanFreezesStageOrderRanksAndExtensionSlots() {
        let plan = ServerProviderSearchAPIProviderStatusStackPlan.defaultPlan()
        let expectedStages: [ServerProviderSearchAPIProviderStatusStackStage] = [
            .envelope,
            .invocationPreflight,
            .adapterInterface,
            .liveVendorSelection,
            .readiness,
            .meteredEntitlement,
            .vendorPolicy,
            .dispatchAuthorization,
            .lease,
            .request,
            .response,
            .transportPreflight,
            .audit,
            .fallback,
        ]
        let expectedStageIDs = [
            "search-api-status-envelope",
            "search-api-status-invocation-preflight",
            "search-api-status-adapter-interface",
            "search-api-status-live-vendor-selection",
            "search-api-status-readiness",
            "search-api-status-metered-entitlement",
            "search-api-status-vendor-policy",
            "search-api-status-dispatch-authorization",
            "search-api-status-lease",
            "search-api-status-request",
            "search-api-status-response",
            "search-api-status-transport-preflight",
            "search-api-status-audit",
            "search-api-status-fallback",
        ]

        assertSendable(plan)
        assertSendable(plan.safeCopy)
        XCTAssertEqual(plan.id, "a169-search-api-provider-status-stack-plan")
        XCTAssertNil(plan.runtimeEntryPointName)
        XCTAssertFalse(plan.isRuntimeCallable)
        XCTAssertEqual(plan.stages.map(\.stage), expectedStages)
        XCTAssertEqual(plan.stages.map(\.rank), Array(1...expectedStages.count))
        XCTAssertEqual(plan.stages.map(\.id), expectedStageIDs)
        XCTAssertEqual(
            plan.stages.map(\.debugLabel),
            zip(1...expectedStages.count, expectedStageIDs).map { "\($0.0).\($0.1)" }
        )
        XCTAssertEqual(plan.validation.state, .accepted)
        XCTAssertTrue(plan.validation.isAccepted)
        XCTAssertEqual(plan.validation.reasons, [])
        XCTAssertEqual(plan.safeCopy.stageIDs, expectedStageIDs)
        XCTAssertEqual(plan.safeCopy.stageRanks, Array(1...expectedStages.count))
        XCTAssertFalse(plan.safeCopy.isRuntimeCallable)
        XCTAssertTrue(plan.safeCopy.envelopeStageRequiresNonExecutableCopy)
        XCTAssertEqual(plan.safeCopy.validationState, .accepted)
        XCTAssertEqual(plan.safeCopy.validationReasons, [])
        XCTAssertEqual(
            plan.extensionSlots.map(\.slot),
            ServerProviderSearchAPIProviderStatusStackExtensionSlot.defaultSlots
        )
        XCTAssertEqual(
            plan.safeCopy.extensionSlotIDs,
            [
                "search-api-slot-cost-based-provider-selection",
                "search-api-slot-membership-tier-routing",
                "search-api-slot-quota-class-selection",
                "search-api-slot-regional-policy-routing",
            ]
        )
    }

    func test_validationRejectsDuplicateAndMisorderedPlans() {
        let defaultStages = ServerProviderSearchAPIProviderStatusStackPlan.defaultPlan().stages

        var duplicateID = defaultStages
        duplicateID[1] = replacementStage(
            from: duplicateID[1],
            id: duplicateID[0].id
        )
        let duplicateIDResult = ServerProviderSearchAPIProviderStatusStackPlan.validate(
            stages: duplicateID
        )
        XCTAssertEqual(duplicateIDResult.state, .rejected)
        XCTAssertTrue(duplicateIDResult.reasons.contains(.duplicateStageID))

        var duplicateKind = defaultStages
        duplicateKind[1] = replacementStage(
            from: duplicateKind[1],
            stage: .envelope,
            id: "search-api-status-envelope-shadow"
        )
        let duplicateKindResult = ServerProviderSearchAPIProviderStatusStackPlan.validate(
            stages: duplicateKind
        )
        XCTAssertEqual(duplicateKindResult.state, .rejected)
        XCTAssertTrue(duplicateKindResult.reasons.contains(.duplicateStageKind))
        XCTAssertTrue(duplicateKindResult.reasons.contains(.stageOrderMismatch))
        XCTAssertTrue(duplicateKindResult.reasons.contains(.rankStageMismatch))

        var duplicateRank = defaultStages
        duplicateRank[1] = replacementStage(
            from: duplicateRank[1],
            rank: duplicateRank[0].rank
        )
        let duplicateRankResult = ServerProviderSearchAPIProviderStatusStackPlan.validate(
            stages: duplicateRank
        )
        XCTAssertEqual(duplicateRankResult.state, .rejected)
        XCTAssertTrue(duplicateRankResult.reasons.contains(.duplicateRank))
        XCTAssertTrue(duplicateRankResult.reasons.contains(.nonContiguousRanks))
        XCTAssertTrue(duplicateRankResult.reasons.contains(.rankStageMismatch))

        var swapped = defaultStages
        swapped.swapAt(1, 2)
        let swappedResult = ServerProviderSearchAPIProviderStatusStackPlan.validate(
            stages: swapped
        )
        XCTAssertEqual(swappedResult.state, .rejected)
        XCTAssertTrue(swappedResult.reasons.contains(.stageOrderMismatch))
        XCTAssertTrue(swappedResult.reasons.contains(.nonContiguousRanks))

        var fallbackEarly = defaultStages
        fallbackEarly.swapAt(12, 13)
        let fallbackEarlyResult = ServerProviderSearchAPIProviderStatusStackPlan.validate(
            stages: fallbackEarly
        )
        XCTAssertEqual(fallbackEarlyResult.state, .rejected)
        XCTAssertTrue(fallbackEarlyResult.reasons.contains(.fallbackNotLast))
        XCTAssertTrue(fallbackEarlyResult.reasons.contains(.stageOrderMismatch))
        XCTAssertTrue(fallbackEarlyResult.reasons.contains(.nonContiguousRanks))

        let emptyResult = ServerProviderSearchAPIProviderStatusStackPlan.validate(stages: [])
        XCTAssertEqual(emptyResult.state, .rejected)
        XCTAssertTrue(emptyResult.reasons.contains(.emptyStages))
        XCTAssertTrue(emptyResult.reasons.contains(.envelopeNotFirst))
        XCTAssertTrue(emptyResult.reasons.contains(.fallbackNotLast))
    }

    func test_planCopyIsCodableDeterministicAndValueOnly() throws {
        let plan = ServerProviderSearchAPIProviderStatusStackPlan.defaultPlan()
        let repeatedPlan = ServerProviderSearchAPIProviderStatusStackPlan.defaultPlan()

        XCTAssertEqual(plan, repeatedPlan)
        XCTAssertEqual(plan.safeCopy, repeatedPlan.safeCopy)

        let encodedPlan = try JSONEncoder().encode(plan)
        let decodedPlan = try JSONDecoder().decode(
            ServerProviderSearchAPIProviderStatusStackPlan.self,
            from: encodedPlan
        )
        XCTAssertEqual(decodedPlan, plan)
        XCTAssertEqual(decodedPlan.safeCopy, plan.safeCopy)

        let encodedSafeCopy = try JSONEncoder().encode(plan.safeCopy)
        let decodedSafeCopy = try JSONDecoder().decode(
            ServerProviderSearchAPIProviderStatusStackPlanSafeCopy.self,
            from: encodedSafeCopy
        )
        XCTAssertEqual(decodedSafeCopy, plan.safeCopy)

        let encodedPlanText = try XCTUnwrap(String(data: encodedPlan, encoding: .utf8))
        let encodedSafeCopyText = try XCTUnwrap(String(data: encodedSafeCopy, encoding: .utf8))
        let reviewerText = (
            [
                plan.description,
                plan.safeCopy.description,
            ]
            + plan.stages.flatMap { stage in
                [
                    stage.id,
                    stage.displayLabel,
                    stage.debugLabel,
                    stage.contractNote,
                ]
            }
            + plan.extensionSlots.flatMap { slot in
                [
                    slot.id,
                    slot.reviewerNote,
                ]
            }
        )
        .joined(separator: "\n")
        let joined = [encodedPlanText, encodedSafeCopyText, reviewerText]
            .joined(separator: "\n")

        for fragment in forbiddenLiveMaterialFragments() {
            XCTAssertFalse(
                joined.localizedCaseInsensitiveContains(fragment),
                "Stack plan copy leaked value-only fragment: \(fragment)"
            )
        }
    }

    private func replacementStage(
        from stage: ServerProviderSearchAPIProviderStatusStackPlanStage,
        stage replacementKind: ServerProviderSearchAPIProviderStatusStackStage? = nil,
        id replacementID: String? = nil,
        rank replacementRank: Int? = nil
    ) -> ServerProviderSearchAPIProviderStatusStackPlanStage {
        let kind = replacementKind ?? stage.stage
        return ServerProviderSearchAPIProviderStatusStackPlanStage(
            stage: kind,
            id: replacementID ?? stage.id,
            rank: replacementRank ?? stage.rank,
            displayLabel: stage.displayLabel,
            debugLabel: stage.debugLabel,
            contractNote: stage.contractNote
        )
    }

    private func forbiddenLiveMaterialFragments() -> [String] {
        [
            "http" + "://",
            "https" + "://",
            "end" + "point",
            "api" + "Key",
            "api" + " key",
            "O" + "Auth",
            "bear" + "er",
            "tok" + "en",
            "URL" + "Session",
            "URL" + "Request",
            "S" + "DK",
            "cred" + "ential",
            "client" + "Handle",
            "raw" + "Query",
            "raw" + "Page",
            "provider" + "Payload",
            "crawl" + "er",
            "M" + "CP",
            "Ga" + "ode",
            "Goo" + "gle",
            "Store" + "Kit",
            "pay" + "ment",
            "ord" + "er",
            "book" + "ing",
            "hidden app" + "-control",
            "provider" + " call",
            "exec" + "ution",
            "exec" + "ute",
            "com" + "pleted",
            "comple" + "tion",
            "succ" + "ess",
            "do" + "ne",
            "call" + "ed",
            "fetch" + "ed",
            "crawl" + "ed",
            "pa" + "id",
        ]
    }

    private func assertSendable<T: Sendable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        _ = value
        XCTAssertTrue(true, file: file, line: line)
    }
}
