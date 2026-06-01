//
//  MarketCompanionCatalogTests.swift
//  kAirTests
//
//  Locks the overseas companion direction catalog against accidental drift.
//

import XCTest
@testable import kAir

final class MarketCompanionCatalogTests: XCTestCase {

    func test_catalog_hasExactlyTheEightRequestedDirections() {
        XCTAssertEqual(
            MarketCompanionCatalog.directions.map(\.id),
            [
                .celebrityFanCompanion,
                .gamingCompanion,
                .intelligenceMonitor,
                .knowledgeManager,
                .officeHelper,
                .pcButler,
                .growthAccelerator,
                .lifestyleArtist,
            ]
        )
    }

    func test_catalog_titles_matchRequestedChinesePositioning() {
        let titles = MarketCompanionCatalog.directions.map(\.localizedTitle)
        XCTAssertEqual(
            titles,
            [
                "追星好搭子",
                "游戏陪你玩",
                "情报监控器",
                "知识管理员",
                "打工好帮手",
                "电脑小管家",
                "成长加速器",
                "生活艺术家",
            ]
        )
    }

    func test_everyDirection_isOverseasFirstAndMapsToExistingCapabilities() {
        let knownSurfaces = Set(SurfaceKind.allCases)

        for direction in MarketCompanionCatalog.directions {
            XCTAssertTrue(direction.isOverseasFirst, "\(direction.id) must list overseas app/provider examples")
            XCTAssertFalse(direction.capabilities.isEmpty, "\(direction.id) must map to at least one existing capability")
            XCTAssertFalse(direction.surfaces.isEmpty, "\(direction.id) must map to at least one existing surface")
            XCTAssertTrue(Set(direction.surfaces).isSubset(of: knownSurfaces))
        }
    }

    func test_everyDirection_blocksHiddenThirdPartyAutomation() {
        for direction in MarketCompanionCatalog.directions {
            XCTAssertTrue(
                direction.boundaries.contains(.noHiddenThirdPartyAutomation),
                "\(direction.id) must not imply hidden app control"
            )
            XCTAssertTrue(
                direction.boundaries.contains(.noPurchasePostOrSystemChangeWithoutConfirmation),
                "\(direction.id) must keep purchase, posting, and system changes confirmation-gated"
            )
        }
    }

    func test_externalExecutionLanes_requireUserConfirmedHandoff() {
        let externalExecutionDirections: Set<MarketCompanionDirectionID> = [
            .celebrityFanCompanion,
            .gamingCompanion,
            .intelligenceMonitor,
            .officeHelper,
            .pcButler,
            .lifestyleArtist,
        ]

        for id in externalExecutionDirections {
            let direction = MarketCompanionCatalog.direction(id)
            XCTAssertTrue(
                direction.boundaries.contains(.userConfirmedExternalHandoff),
                "\(id) includes an external app or service action and must stay handoff-gated"
            )
        }
    }
}
