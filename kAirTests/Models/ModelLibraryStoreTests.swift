//
//  ModelLibraryStoreTests.swift
//  kAirTests
//
//  A7 Model Library UI truthfulness tests.
//

import XCTest
@testable import kAir

@MainActor
final class ModelLibraryStoreTests: XCTestCase {

    func test_rowsDeriveVisibleCopyAndSpecsFromCatalogEntries() throws {
        let store = ModelLibraryStore(
            catalog: [
                Self.entry(
                    id: "custom-router",
                    name: "Custom Router",
                    role: .router,
                    diskSizeBytes: 2_400_000_000,
                    estimatedMemoryBytes: 640_000_000,
                    statusCopy: "Catalog supplied row copy."
                ),
            ],
            backendStates: [
                "custom-router": .active,
            ]
        )

        let row = try XCTUnwrap(store.row(id: "custom-router"))

        XCTAssertEqual(row.title, "Custom Router")
        XCTAssertEqual(row.summary, "Catalog supplied row copy.")
        XCTAssertEqual(row.statePresentation.title, "Active")
        XCTAssertEqual(row.specs.map(\.value), [
            "Router",
            "Core ML",
            "2.4 GB",
            "640 MB",
            "1.0.0",
            "A16 / iOS 17.0",
        ])
    }

    func test_defaultEligibleRowsExposeBackendNotWiredPlaceholderActions() throws {
        let store = ModelLibraryStore()

        let bundled = try XCTUnwrap(store.row(id: ModelCatalog.localRouterID))
        XCTAssertEqual(bundled.statePresentation.title, "Bundled setup pending")
        XCTAssertFalse(bundled.actionPresentation.isEnabled)
        XCTAssertEqual(bundled.actionPresentation.title, "Download pending")
        XCTAssertTrue(bundled.actionPresentation.summary.contains("not wired"))

        let downloadable = try XCTUnwrap(store.row(id: ModelCatalog.localPlannerID))
        XCTAssertEqual(downloadable.statePresentation.title, "Download setup pending")
        XCTAssertFalse(downloadable.actionPresentation.isEnabled)
        XCTAssertEqual(downloadable.trustLine, "Signed download source")
    }

    func test_paidModelWithoutEntitlementStaysLockedAgainstBackendSnapshot() throws {
        let store = ModelLibraryStore(
            backendStates: [
                ModelCatalog.premiumMarketID: .active,
            ]
        )

        let premium = try XCTUnwrap(store.row(id: ModelCatalog.premiumMarketID))
        XCTAssertEqual(premium.downloadState, .requiresPurchase)
        XCTAssertEqual(premium.statePresentation.title, "Paid locked")
        XCTAssertEqual(premium.actionPresentation.title, "Purchase required")
        XCTAssertFalse(premium.actionPresentation.isEnabled)
    }

    func test_presentationsCoverA7RequiredStates() throws {
        let store = ModelLibraryStore(
            catalog: [
                Self.entry(id: "active", name: "Active", role: .router),
                Self.entry(id: "installed", name: "Installed", role: .planner),
                Self.entry(id: "paid", name: "Paid", role: .premium, runtime: .remoteGateway, productID: "paid.product"),
                Self.entry(id: "failed", name: "Failed", role: .embedder),
                Self.entry(id: "unavailable", name: "Unavailable", role: .health),
                Self.entry(id: "placeholder", name: "Placeholder", role: .planner, download: true),
            ],
            backendStates: [
                "active": .active,
                "installed": .installed,
                "failed": .failed(reason: .compileFailed),
                "unavailable": .unavailable(reason: .deviceUnsupported),
            ]
        )

        XCTAssertEqual(try XCTUnwrap(store.row(id: "active")).statePresentation.title, "Active")
        XCTAssertEqual(try XCTUnwrap(store.row(id: "installed")).statePresentation.title, "Installed")
        XCTAssertEqual(try XCTUnwrap(store.row(id: "paid")).statePresentation.title, "Paid locked")
        XCTAssertEqual(try XCTUnwrap(store.row(id: "failed")).statePresentation.title, "Failed")
        XCTAssertEqual(try XCTUnwrap(store.row(id: "unavailable")).statePresentation.title, "Unavailable")
        XCTAssertEqual(try XCTUnwrap(store.row(id: "placeholder")).statePresentation.title, "Download setup pending")
    }

    func test_downloadingProgressIsClampedForPresentation() throws {
        let store = ModelLibraryStore(
            catalog: [
                Self.entry(id: "progress", name: "Progress", role: .planner),
            ],
            backendStates: [
                "progress": .downloading(progress: 1.4),
            ]
        )

        let row = try XCTUnwrap(store.row(id: "progress"))
        XCTAssertEqual(row.statePresentation.title, "Downloading 100%")
        XCTAssertEqual(row.statePresentation.progress, 1.0)
    }

    func test_actionsRemainDisabledWithoutRealBackends() {
        let states: [ModelDownloadState] = [
            .eligible,
            .requiresPurchase,
            .downloadQueued,
            .downloading(progress: 0.2),
            .installed,
            .active,
            .failed(reason: .downloadInterrupted),
            .unavailable(reason: .backendNotWired),
        ]
        let catalog = states.enumerated().map { index, _ in
            Self.entry(id: "model-\(index)", name: "Model \(index)", role: .planner)
        }
        let backendStates = Dictionary(
            uniqueKeysWithValues: states.enumerated().map { index, state in
                ("model-\(index)", state)
            }
        )
        let store = ModelLibraryStore(catalog: catalog, backendStates: backendStates)

        XCTAssertTrue(store.rows.allSatisfy { $0.actionPresentation.isEnabled == false })
    }

    private static func entry(
        id: String,
        name: String,
        role: ModelRole,
        runtime: ModelRuntimeFamily = .coreML,
        diskSizeBytes: Int64 = 120_000_000,
        estimatedMemoryBytes: Int64 = 240_000_000,
        statusCopy: String = "Catalog row copy.",
        download: Bool = false,
        productID: String? = nil
    ) -> ModelCatalogEntry {
        ModelCatalogEntry(
            id: id,
            displayName: name,
            role: role,
            runtimeFamily: runtime,
            version: "1.0.0",
            diskSizeBytes: runtime == .remoteGateway ? 0 : diskSizeBytes,
            estimatedMemoryBytes: runtime == .remoteGateway ? 0 : estimatedMemoryBytes,
            minimumDeviceClass: "A16",
            minimumOS: "17.0",
            license: "test",
            statusCopy: statusCopy,
            downloadURL: download ? URL(string: "https://models.kair.local/\(id).mlpackage") : nil,
            checksum: download ? "sha256:\(id)" : nil,
            signature: download ? "ed25519:\(id)" : nil,
            priceProductID: productID,
            privacyClassAllowed: role == .health ? ["health"] : ["general"],
            supportsStructuredOutput: role != .embedder,
            supportsToolCalling: role == .router || role == .planner || role == .premium
        )
    }
}
