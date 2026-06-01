//
//  ModelCatalogTests.swift
//  kAirTests
//
//  A3 model-catalog value contracts (kair-ai-model-memory-v1.md §1/§5/§7).
//  Coverage: runtime-family on-device classification, role local-only rule,
//  catalog fixture integrity (health local-only, paid product id, trusted
//  download source), paid entitlement gating, and the `ModelLibraryStore`
//  honest-state derivation across free / installed / paid-locked / active /
//  failed / unavailable.
//

import XCTest
@testable import kAir

final class ModelCatalogTests: XCTestCase {

    // MARK: - Runtime family (§4)

    func test_runtimeFamily_onlyRemoteGatewayIsRemote() {
        for family in ModelRuntimeFamily.allCases {
            if family == .remoteGateway {
                XCTAssertFalse(family.isOnDevice, "remoteGateway is the only remote family")
            } else {
                XCTAssertTrue(family.isOnDevice, "\(family) must be on-device")
            }
        }
    }

    // MARK: - Role local-only (§1)

    func test_role_onlyHealthIsLocalOnly() {
        for role in ModelRole.allCases {
            XCTAssertEqual(role.isLocalOnly, role == .health, "\(role) local-only mismatch")
        }
    }

    // MARK: - Catalog fixture integrity (§5)

    func test_catalog_isNonEmpty_andIdsAreUnique() {
        let ids = ModelCatalog.fixtures.map(\.id)
        XCTAssertFalse(ids.isEmpty)
        XCTAssertEqual(Set(ids).count, ids.count, "catalog ids must be unique")
    }

    func test_catalog_everyHealthEntryIsLocalOnly() {
        for entry in ModelCatalog.fixtures where entry.role == .health {
            XCTAssertTrue(
                entry.runtimeFamily.isOnDevice,
                "\(entry.id): health specialist must run on-device (§1)"
            )
            XCTAssertTrue(entry.respectsHealthLocalOnly)
            XCTAssertFalse(entry.isPaid, "\(entry.id): health specialist is not a paid model")
        }
    }

    func test_catalog_everyEntryRespectsHealthLocalOnlyInvariant() {
        for entry in ModelCatalog.fixtures {
            XCTAssertTrue(entry.respectsHealthLocalOnly, "\(entry.id) violates health local-only")
        }
    }

    func test_respectsHealthLocalOnly_rejectsHealthOnRemoteGateway() {
        let illegal = ModelCatalogEntry(
            id: "health-remote-illegal",
            displayName: "Illegal Health Remote",
            role: .health,
            runtimeFamily: .remoteGateway,
            version: "1.0.0",
            diskSizeBytes: 0,
            estimatedMemoryBytes: 0,
            minimumDeviceClass: "any",
            minimumOS: "17.0",
            license: "x",
            statusCopy: "x"
        )
        XCTAssertFalse(
            illegal.respectsHealthLocalOnly,
            "a health model on the remote gateway must be flagged invalid"
        )
    }

    func test_catalog_paidEntryHasProductIdAndIsRemote() {
        let premium = ModelCatalog.entry(id: ModelCatalog.premiumMarketID)
        XCTAssertNotNil(premium)
        XCTAssertTrue(premium?.isPaid == true)
        XCTAssertNotNil(premium?.priceProductID)
        XCTAssertEqual(premium?.runtimeFamily, .remoteGateway)
    }

    func test_catalog_bundledFreeEntryHasNoProductIdAndTrustedSource() {
        let router = ModelCatalog.entry(id: ModelCatalog.localRouterID)
        XCTAssertNotNil(router)
        XCTAssertFalse(router?.isPaid == true)
        XCTAssertNil(router?.priceProductID)
        // No download URL → bundled → trivially trusted.
        XCTAssertNil(router?.downloadURL)
        XCTAssertTrue(router?.hasTrustedDownloadSource == true)
    }

    func test_catalog_downloadableEntriesCarryChecksumAndSignature() {
        for entry in ModelCatalog.fixtures where entry.downloadURL != nil {
            XCTAssertTrue(
                entry.hasTrustedDownloadSource,
                "\(entry.id): a download URL needs checksum + signature (§5)"
            )
        }
    }

    func test_hasTrustedDownloadSource_rejectsUrlWithoutChecksumOrSignature() {
        let untrusted = ModelCatalogEntry(
            id: "untrusted",
            displayName: "Untrusted",
            role: .planner,
            runtimeFamily: .coreML,
            version: "1.0.0",
            diskSizeBytes: 1,
            estimatedMemoryBytes: 1,
            minimumDeviceClass: "any",
            minimumOS: "17.0",
            license: "x",
            statusCopy: "x",
            downloadURL: URL(string: "https://example.com/m.bin"),
            checksum: nil,
            signature: nil
        )
        XCTAssertFalse(untrusted.hasTrustedDownloadSource)
    }

    func test_catalog_metadataCarriesNoApiKey() {
        // Defense of the "no API key in metadata" constraint: the paid remote
        // entry exposes only a StoreKit product id, never a secret.
        let premium = ModelCatalog.entry(id: ModelCatalog.premiumMarketID)
        XCTAssertEqual(premium?.priceProductID, "com.kair.model.market_large_model")
    }

    // MARK: - Entitlement policy: paid gating (§6/§7)

    func test_entitlement_freeModelIsAlwaysDownloadable() throws {
        let router = try XCTUnwrap(ModelCatalog.entry(id: ModelCatalog.localRouterID))
        XCTAssertEqual(
            ModelEntitlementPolicy.eligibility(for: router, entitlement: .notEntitled),
            .free
        )
        XCTAssertTrue(ModelEntitlementPolicy.canStartDownload(for: router, entitlement: .notEntitled))
        XCTAssertEqual(
            ModelEntitlementPolicy.initialDownloadState(for: router, entitlement: .notEntitled),
            .eligible
        )
    }

    func test_entitlement_paidModelWithoutEntitlementIsLockedAndCannotDownload() throws {
        let premium = try XCTUnwrap(ModelCatalog.entry(id: ModelCatalog.premiumMarketID))
        XCTAssertEqual(
            ModelEntitlementPolicy.eligibility(for: premium, entitlement: .notEntitled),
            .requiresPurchase
        )
        XCTAssertFalse(
            ModelEntitlementPolicy.canStartDownload(for: premium, entitlement: .notEntitled),
            "a paid, unentitled model must not be downloadable (no faked unlock)"
        )
        XCTAssertEqual(
            ModelEntitlementPolicy.initialDownloadState(for: premium, entitlement: .notEntitled),
            .requiresPurchase
        )
    }

    func test_entitlement_paidModelWithEntitlementBecomesEligible() throws {
        let premium = try XCTUnwrap(ModelCatalog.entry(id: ModelCatalog.premiumMarketID))
        XCTAssertEqual(
            ModelEntitlementPolicy.eligibility(for: premium, entitlement: .entitled),
            .entitled
        )
        XCTAssertTrue(ModelEntitlementPolicy.canStartDownload(for: premium, entitlement: .entitled))
        XCTAssertEqual(
            ModelEntitlementPolicy.initialDownloadState(for: premium, entitlement: .entitled),
            .eligible
        )
    }

    func test_entitlement_initialStateNeverFabricatesInstall() {
        // The policy must only ever yield eligible / requiresPurchase — never a
        // completed/active install (those require real backend progress).
        for entry in ModelCatalog.fixtures {
            for entitlement in ModelEntitlement.allCases {
                let state = ModelEntitlementPolicy.initialDownloadState(
                    for: entry,
                    entitlement: entitlement
                )
                XCTAssertTrue(
                    state.kind == .eligible || state.kind == .requiresPurchase,
                    "\(entry.id)/\(entitlement): initial state must not fabricate install, got \(state.kind)"
                )
            }
        }
    }

    // MARK: - ModelLibraryStore: honest state derivation

    @MainActor
    func test_store_derivesEligibleAndPaidLockedFromEntitlements() {
        let store = ModelLibraryStore(
            entitlements: [:]   // nothing entitled
        )
        // Free router → eligible.
        XCTAssertEqual(store.row(id: ModelCatalog.localRouterID)?.downloadState, .eligible)
        XCTAssertTrue(store.canStartDownload(id: ModelCatalog.localRouterID))
        // Paid premium, no entitlement → paid locked, cannot download.
        let premiumRow = store.row(id: ModelCatalog.premiumMarketID)
        XCTAssertEqual(premiumRow?.downloadState, .requiresPurchase)
        XCTAssertEqual(premiumRow?.isPaidLocked, true)
        XCTAssertFalse(store.canStartDownload(id: ModelCatalog.premiumMarketID))
    }

    @MainActor
    func test_store_paidModelUnlocksWithEntitlement() {
        let store = ModelLibraryStore(
            entitlements: [ModelCatalog.premiumMarketID: .entitled]
        )
        XCTAssertEqual(store.row(id: ModelCatalog.premiumMarketID)?.downloadState, .eligible)
        XCTAssertTrue(store.canStartDownload(id: ModelCatalog.premiumMarketID))
    }

    @MainActor
    func test_store_paidLockOutranksBackendSnapshotWithoutEntitlement() {
        let store = ModelLibraryStore(
            entitlements: [:],
            backendStates: [
                ModelCatalog.premiumMarketID: .active,
            ]
        )

        XCTAssertEqual(store.row(id: ModelCatalog.premiumMarketID)?.downloadState, .requiresPurchase)
        XCTAssertEqual(store.row(id: ModelCatalog.premiumMarketID)?.isPaidLocked, true)
        XCTAssertFalse(store.canStartDownload(id: ModelCatalog.premiumMarketID))
    }

    @MainActor
    func test_store_reflectsBackendStatesWithoutFabrication() {
        // installed / active / failed / unavailable come ONLY from a backend
        // snapshot — the store surfaces them truthfully, never invents them.
        let store = ModelLibraryStore(
            entitlements: [ModelCatalog.premiumMarketID: .entitled],
            backendStates: [
                ModelCatalog.localRouterID: .active,
                ModelCatalog.localPlannerID: .installed,
                ModelCatalog.localEmbedderID: .failed(reason: .compileFailed),
                ModelCatalog.premiumMarketID: .unavailable(reason: .backendNotWired),
            ]
        )
        XCTAssertEqual(store.row(id: ModelCatalog.localRouterID)?.downloadState, .active)
        XCTAssertEqual(store.row(id: ModelCatalog.localPlannerID)?.downloadState, .installed)
        XCTAssertEqual(
            store.row(id: ModelCatalog.localEmbedderID)?.downloadState,
            .failed(reason: .compileFailed)
        )
        XCTAssertEqual(
            store.row(id: ModelCatalog.premiumMarketID)?.downloadState,
            .unavailable(reason: .backendNotWired)
        )
    }

    @MainActor
    func test_store_unknownIdCannotDownload() {
        let store = ModelLibraryStore()
        XCTAssertNil(store.row(id: "nope"))
        XCTAssertFalse(store.canStartDownload(id: "nope"))
    }

    // MARK: - Acceptance: all nine required states are representable

    func test_acceptance_allRequiredStatesAreRepresentable() {
        // free / installed / paid locked / downloading / verifying / compiling
        // / active / failed / unavailable (the round's acceptance list).
        let required: [ModelDownloadState] = [
            .eligible,                          // free
            .installed,                         // installed
            .requiresPurchase,                  // paid locked
            .downloading(progress: 0.5),        // downloading
            .verifying,                         // verifying
            .compiling,                         // compiling
            .active,                            // active
            .failed(reason: .downloadInterrupted), // failed
            .unavailable(reason: .deviceUnsupported), // unavailable
        ]
        let kinds = Set(required.map(\.kind))
        XCTAssertEqual(kinds.count, required.count, "each required state is a distinct kind")
        for state in required {
            XCTAssertTrue(
                ModelDownloadStateKind.allCases.contains(state.kind),
                "\(state.kind) must be a known state-machine node"
            )
        }
    }
}
