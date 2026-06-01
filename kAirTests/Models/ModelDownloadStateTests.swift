//
//  ModelDownloadStateTests.swift
//  kAirTests
//
//  A3 model download state machine (kair-ai-model-memory-v1.md §6). Coverage:
//  kind projection, the happy install path, the paid-entitlement gate (no
//  faked purchase), user-action-only download start, recoverable failures,
//  uninstall-keeps-purchase, and rejection of illegal jumps.
//

import XCTest
@testable import kAir

final class ModelDownloadStateTests: XCTestCase {

    // MARK: - kind projection

    func test_kind_projectsEveryCaseIncludingAssociatedValues() {
        XCTAssertEqual(ModelDownloadState.notInstalled.kind, .notInstalled)
        XCTAssertEqual(ModelDownloadState.eligible.kind, .eligible)
        XCTAssertEqual(ModelDownloadState.requiresPurchase.kind, .requiresPurchase)
        XCTAssertEqual(ModelDownloadState.purchasing.kind, .purchasing)
        XCTAssertEqual(ModelDownloadState.downloadQueued.kind, .downloadQueued)
        XCTAssertEqual(ModelDownloadState.downloading(progress: 0.3).kind, .downloading)
        XCTAssertEqual(ModelDownloadState.downloaded.kind, .downloaded)
        XCTAssertEqual(ModelDownloadState.verifying.kind, .verifying)
        XCTAssertEqual(ModelDownloadState.compiling.kind, .compiling)
        XCTAssertEqual(ModelDownloadState.installed.kind, .installed)
        XCTAssertEqual(ModelDownloadState.active.kind, .active)
        XCTAssertEqual(ModelDownloadState.paused.kind, .paused)
        XCTAssertEqual(ModelDownloadState.failed(reason: .compileFailed).kind, .failed)
        XCTAssertEqual(ModelDownloadState.deleting.kind, .deleting)
        XCTAssertEqual(ModelDownloadState.deleted.kind, .deleted)
        XCTAssertEqual(ModelDownloadState.unavailable(reason: .osTooOld).kind, .unavailable)
    }

    func test_isInstalled_trueOnlyForInstalledAndActive() {
        XCTAssertTrue(ModelDownloadState.installed.isInstalled)
        XCTAssertTrue(ModelDownloadState.active.isInstalled)
        for state: ModelDownloadState in [
            .notInstalled, .eligible, .requiresPurchase, .purchasing, .downloadQueued,
            .downloading(progress: 0.5), .downloaded, .verifying, .compiling, .paused,
            .failed(reason: .installFailed), .deleting, .deleted,
            .unavailable(reason: .deviceUnsupported),
        ] {
            XCTAssertFalse(state.isInstalled, "\(state.kind) is not an installed state")
        }
    }

    // MARK: - Happy install path (free model)

    func test_transitions_happyInstallPath_allLegal() {
        let path: [ModelDownloadStateKind] = [
            .notInstalled, .eligible, .downloadQueued, .downloading, .downloaded,
            .verifying, .compiling, .installed, .active,
        ]
        assertPathLegal(path)
    }

    // MARK: - User-action-only download start (§6)

    func test_transitions_downloadStartsOnlyFromAUserQueue() {
        // The only edges into `downloading` are from a queue or a resumed pause
        // — never a direct jump from a freshly-eligible / not-installed state.
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .downloadQueued, to: .downloading))
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .paused, to: .downloading))
        XCTAssertFalse(ModelDownloadMachine.canTransition(from: .eligible, to: .downloading))
        XCTAssertFalse(ModelDownloadMachine.canTransition(from: .notInstalled, to: .downloading))
        // The user-initiated start edge itself is eligible → queued.
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .eligible, to: .downloadQueued))
    }

    // MARK: - Paid entitlement gate (§6/§7) — no faked purchase

    func test_transitions_paidModelMustPassThroughEntitlement() {
        // Locked → cannot queue or download directly; must purchase first.
        XCTAssertFalse(ModelDownloadMachine.canTransition(from: .requiresPurchase, to: .downloadQueued))
        XCTAssertFalse(ModelDownloadMachine.canTransition(from: .requiresPurchase, to: .downloading))
        // The legal paid path: locked → purchasing → eligible → queued → downloading.
        assertPathLegal([
            .requiresPurchase, .purchasing, .eligible, .downloadQueued, .downloading,
        ])
    }

    func test_transitions_purchaseCanCancelBackToLocked() {
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .purchasing, to: .requiresPurchase))
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .purchasing, to: .failed))
    }

    // MARK: - Recoverable, visible failures (§6)

    func test_transitions_failureIsReachableFromEveryActiveStep() {
        for from: ModelDownloadStateKind in [
            .purchasing, .downloadQueued, .downloading, .downloaded,
            .verifying, .compiling, .paused, .deleting,
        ] {
            XCTAssertTrue(
                ModelDownloadMachine.canTransition(from: from, to: .failed),
                "\(from) must be able to fail visibly (§6)"
            )
        }
    }

    func test_transitions_failedCanRetryToQueue() {
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .failed, to: .downloadQueued))
    }

    func test_transitions_compileFailureRecovers() {
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .compiling, to: .failed))
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .failed, to: .downloadQueued))
    }

    func test_transitions_downloadIsPausableAndResumable() {
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .downloading, to: .paused))
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .paused, to: .downloading))
    }

    // MARK: - Uninstall keeps purchase entitlement (§6)

    func test_transitions_uninstallPathAndKeepsEntitlement() {
        assertPathLegal([.active, .deleting, .deleted])
        assertPathLegal([.installed, .deleting, .deleted])
        // A deleted (still-entitled) paid model can return to eligible, not only
        // back to a locked state — the purchase survives uninstall (§6).
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .deleted, to: .eligible))
    }

    // MARK: - Activate / deactivate

    func test_transitions_installedActivatesAndDeactivates() {
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .installed, to: .active))
        XCTAssertTrue(ModelDownloadMachine.canTransition(from: .active, to: .installed))
    }

    // MARK: - Illegal jumps are rejected

    func test_transitions_illegalShortcutsAreRejected() {
        let illegal: [(ModelDownloadStateKind, ModelDownloadStateKind)] = [
            (.notInstalled, .active),       // can't appear installed from nothing
            (.notInstalled, .installed),
            (.notInstalled, .downloading),
            (.eligible, .installed),        // must download/verify/compile first
            (.eligible, .active),
            (.requiresPurchase, .downloading), // paid gate
            (.downloading, .active),        // must verify + compile first
            (.downloaded, .installed),      // verify + compile are mandatory
            (.verifying, .installed),
            (.installed, .downloading),     // no backward re-download without delete
        ]
        for (from, to) in illegal {
            XCTAssertFalse(
                ModelDownloadMachine.canTransition(from: from, to: to),
                "\(from) → \(to) must be illegal"
            )
        }
    }

    func test_transitions_fullStateConvenienceMatchesKindGraph() {
        // The full-state convenience must agree with the kind-level graph.
        XCTAssertTrue(
            ModelDownloadState.downloading(progress: 0.9).canTransition(to: .downloaded)
        )
        XCTAssertFalse(
            ModelDownloadState.unavailable(reason: .deviceUnsupported).canTransition(to: .active)
        )
    }

    // MARK: - Every node has an explicit (possibly terminal) edge set

    func test_machine_everyKindHasATransitionEntry() {
        for kind in ModelDownloadStateKind.allCases {
            XCTAssertNotNil(
                ModelDownloadMachine.allowedTransitions[kind],
                "\(kind) must have an explicit transition set (even if empty)"
            )
        }
    }

    // MARK: - Helpers

    /// Assert every consecutive pair in `path` is a legal transition.
    private func assertPathLegal(
        _ path: [ModelDownloadStateKind],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for index in 1..<path.count {
            let from = path[index - 1]
            let to = path[index]
            XCTAssertTrue(
                ModelDownloadMachine.canTransition(from: from, to: to),
                "\(from) → \(to) should be legal",
                file: file,
                line: line
            )
        }
    }
}
