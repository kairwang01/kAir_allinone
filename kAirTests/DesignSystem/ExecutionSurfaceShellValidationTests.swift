//
//  ExecutionSurfaceShellValidationTests.swift
//  kAirTests
//
//  T6 acceptance coverage for the Execution Surface shell skeleton.
//
//  Pins the target shape described by:
//    - Docs/design/execution-surface-framework-v1.md §1-§8
//    - Docs/design/super-app-visual-system-v1.md §9 / §14
//
//  Scope:
//    - This suite validates the shared shell type family introduced by
//      `Skel(ExecutionSurfaceShell)`.
//    - It does NOT migrate Maps / AI / Store / Health onto the shell.
//    - It does NOT validate Music / Search reuse; those remain T7 / T9.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class ExecutionSurfaceShellValidationTests: XCTestCase {

    // MARK: - State vocabulary

    func test_shellStateEnum_isExactlyTheFiveFrameworkStates() {
        XCTAssertEqual(
            ExecutionSurfaceSystemState.allCases,
            [.ready, .loading, .empty, .error, .permissionOrUnavailable]
        )
        XCTAssertEqual(ExecutionSurfaceSystemState.allCases.count, 5)
    }

    func test_shellStateIcons_matchVisualSystemMapping() {
        XCTAssertEqual(ExecutionSurfaceSystemState.ready.iconSystemImage, "checkmark.circle")
        XCTAssertEqual(ExecutionSurfaceSystemState.loading.iconSystemImage, "hourglass")
        XCTAssertEqual(ExecutionSurfaceSystemState.empty.iconSystemImage, "tray")
        XCTAssertEqual(ExecutionSurfaceSystemState.error.iconSystemImage, "exclamationmark.triangle.fill")
        XCTAssertEqual(ExecutionSurfaceSystemState.permissionOrUnavailable.iconSystemImage, "lock.shield")
    }

    func test_shellStateTints_matchVisualSystemMapping() {
        XCTAssertEqual(ExecutionSurfaceSystemState.ready.tint, AppTheme.Palette.success)
        XCTAssertEqual(ExecutionSurfaceSystemState.loading.tint, AppTheme.Palette.accentStrong)
        XCTAssertEqual(ExecutionSurfaceSystemState.empty.tint, AppTheme.Palette.textMuted)
        XCTAssertEqual(ExecutionSurfaceSystemState.error.tint, AppTheme.Palette.warning)
        XCTAssertEqual(ExecutionSurfaceSystemState.permissionOrUnavailable.tint, AppTheme.Palette.warning)
    }

    // MARK: - Locked copy

    func test_backToChatCopy_isLockedForEnglishAndChinese() {
        XCTAssertEqual(ExecutionSurfaceLockedCopy.backToChat(.english), "Back to chat")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.backToChat(.chinese), "返回聊天")
    }

    func test_stateTitleCopy_isLockedForEnglish() {
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.ready, .english), "Ready")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.loading, .english), "Loading")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.empty, .english), "Nothing to show")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.error, .english), "Something went wrong")
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateTitle(.permissionOrUnavailable, .english),
            "Permission or service unavailable"
        )
    }

    func test_stateTitleCopy_isLockedForChinese() {
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.ready, .chinese), "就绪")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.loading, .chinese), "正在加载")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.empty, .chinese), "暂无结果")
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateTitle(.error, .chinese), "出错了")
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateTitle(.permissionOrUnavailable, .chinese),
            "权限或服务不可用"
        )
    }

    func test_stateSummaryCopy_isLockedForEnglish() {
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateSummary(.ready, .english), "")
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.loading, .english),
            "Preparing this task — you can come back in a moment."
        )
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.empty, .english),
            "No matches this time. Return to chat and try a different phrasing."
        )
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.error, .english),
            "Something went wrong — returning to chat is safe."
        )
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.permissionOrUnavailable, .english),
            "This needs a permission or a service that is not ready. Return to chat or adjust in another card."
        )
    }

    func test_stateSummaryCopy_isLockedForChinese() {
        XCTAssertEqual(ExecutionSurfaceLockedCopy.stateSummary(.ready, .chinese), "")
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.loading, .chinese),
            "正在准备这次任务，稍后回来即可。"
        )
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.empty, .chinese),
            "这次没有匹配到内容，可以返回聊天换个说法再试。"
        )
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.error, .chinese),
            "出现了问题，可以返回聊天继续。"
        )
        XCTAssertEqual(
            ExecutionSurfaceLockedCopy.stateSummary(.permissionOrUnavailable, .chinese),
            "需要权限或服务暂不可用。可以返回聊天，或者在其他卡片中调整。"
        )
    }

    func test_errorSummaryOverride_prefersNonEmptyErrorMessage() {
        let inputs = makeInputs(
            status: ExecutionSurfaceStatus(
                statusMessage: "Provider connected.",
                errorMessage: "Routing provider timed out."
            ),
            state: .error
        )

        XCTAssertEqual(inputs.resolvedStateSummary, "Routing provider timed out.")
    }

    func test_errorSummaryOverride_fallsBackWhenErrorMessageIsEmpty() {
        let inputs = makeInputs(
            status: ExecutionSurfaceStatus(errorMessage: ""),
            state: .error
        )

        XCTAssertEqual(
            inputs.resolvedStateSummary,
            ExecutionSurfaceLockedCopy.stateSummary(.error, .english)
        )
    }

    func test_errorSummaryOverride_doesNotAffectOtherStates() {
        let inputs = makeInputs(
            status: ExecutionSurfaceStatus(errorMessage: "Should not render here."),
            state: .loading
        )

        XCTAssertEqual(
            inputs.resolvedStateSummary,
            ExecutionSurfaceLockedCopy.stateSummary(.loading, .english)
        )
    }

    // MARK: - Region input shape

    func test_shellInputs_areOneToOneWithTheDataBackedFrameworkRegions() {
        let labels = Mirror(reflecting: makeInputs()).children.compactMap(\.label)

        XCTAssertEqual(
            labels,
            ["navRail", "title", "status", "state", "terminal", "language"]
        )
    }

    func test_shellInputs_areEquatableAndHashableForCrossSurfaceParityChecks() {
        let maps = makeInputs(
            navRail: ExecutionSurfaceNavRail(trustPills: [.placeResolutionStub]),
            terminal: ExecutionSurfaceTerminal(title: "Arrived", systemImage: "flag.checkered")
        )
        let musicWithSameShellShape = makeInputs(
            navRail: ExecutionSurfaceNavRail(trustPills: [.placeResolutionStub]),
            terminal: ExecutionSurfaceTerminal(title: "Arrived", systemImage: "flag.checkered")
        )

        XCTAssertEqual(maps, musicWithSameShellShape)
        XCTAssertEqual(Set([maps, musicWithSameShellShape]).count, 1)
    }

    func test_navRailTrustPills_useSharedActionCardTrustPillVocabulary() {
        let navRail = ExecutionSurfaceNavRail(trustPills: ActionCardTrustPillKind.allCases)

        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
        XCTAssertEqual(navRail.trustPills, ActionCardTrustPillKind.allCases)
    }

    func test_backToChatAccessibilityIdentifier_isLocked() {
        XCTAssertEqual(
            executionSurfaceBackToChatAccessibilityIdentifier,
            "execution-surface-back-to-chat"
        )
    }

    // MARK: - Constructability

    func test_shellCanBeConstructedForEverySystemState() {
        for state in ExecutionSurfaceSystemState.allCases {
            _ = ExecutionSurfaceShell(
                inputs: makeInputs(state: state),
                onReturnToChat: {}
            ) {
                ActionCardShell(object: RecommendationFixtures.placeRoute)
            }
        }
    }

    func test_shellCanBeConstructedWithSupplementaryAndTerminalRegions() {
        _ = ExecutionSurfaceShell(
            inputs: makeInputs(
                state: .ready,
                terminal: ExecutionSurfaceTerminal(title: "Arrived", systemImage: "flag.checkered")
            ),
            onReturnToChat: {}
        ) {
            ActionCardShell(object: RecommendationFixtures.placeRoute)
        } supplementary: {
            Text("Supplementary route list")
        }
    }

    // MARK: - Fixture

    private func makeInputs(
        navRail: ExecutionSurfaceNavRail? = nil,
        title: ExecutionSurfaceTitle? = nil,
        status: ExecutionSurfaceStatus? = nil,
        state: ExecutionSurfaceSystemState = .ready,
        terminal: ExecutionSurfaceTerminal? = nil,
        language: ExecutionSurfaceLanguage = .english
    ) -> ExecutionSurfaceShellInputs {
        ExecutionSurfaceShellInputs(
            navRail: navRail ?? ExecutionSurfaceNavRail(),
            title: title ?? ExecutionSurfaceTitle(
                eyebrow: "Maps",
                title: "Route to Blue Bottle",
                summary: "Two candidate routes are ready."
            ),
            status: status ?? ExecutionSurfaceStatus(),
            state: state,
            terminal: terminal,
            language: language
        )
    }
}
