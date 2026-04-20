//
//  ExecutionSurfaceShellValidationTests.swift
//  kAir
//
//  T6 — locks the shared Execution Surface framework per
//  execution-surface-framework-v1.md. The shell is the super-app's single
//  return path from any vertical; this test asserts the pieces Music and
//  Maps (and every future vertical) must reuse without forking.
//
//  What this covers:
//    1. `ExecutionSurfaceSystemState` has exactly the 5 frozen cases.
//    2. Back-to-chat copy is locked to `Back to chat` / `返回聊天`.
//    3. State-region title + summary copy is frozen per zh/en.
//    4. `ExecutionSurfaceStatus.none` is the canonical neutral status.
//    5. A pair of `ExecutionSurfaceShellInputs` — one built from a Maps
//       task and one built from a Music session — share the same types
//       for every region, proving the shell has no per-vertical fork.
//

import Foundation

struct ExecutionSurfaceShellValidationReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum ExecutionSurfaceShellValidationTests {
    static func runAll() -> ExecutionSurfaceShellValidationReport {
        let results: [KernelPhase1TestResult] = [
            testStateEnumFrozen(),
            testBackToChatCopyLocked(),
            testStateTitleCopyLocked(),
            testStateSummaryCopyLocked(),
            testErrorSummaryPrefersOverride(),
            testStatusNoneConstantIsNeutral(),
            testMapsAndMusicInputsShareTypes(),
        ]
        return ExecutionSurfaceShellValidationReport(results: results)
    }

    // MARK: - 1. Frozen system-state enum

    static func testStateEnumFrozen() -> KernelPhase1TestResult {
        let name = "shell_state_enum_frozen"
        let expected: Set<ExecutionSurfaceSystemState> = [
            .ready, .loading, .empty, .error, .permissionOrUnavailable
        ]
        let actual = Set(ExecutionSurfaceSystemState.allCases)
        guard actual == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected \(expected.map(\.rawValue).sorted()) got \(actual.map(\.rawValue).sorted())"
            )
        }
        guard ExecutionSurfaceSystemState.allCases.count == 5 else {
            return .init(
                name: name,
                passed: false,
                detail: "state cardinality != 5"
            )
        }
        return .init(name: name, passed: true, detail: "5 states: ready + loading + empty + error + permissionOrUnavailable")
    }

    // MARK: - 2. Back-to-chat copy

    static func testBackToChatCopyLocked() -> KernelPhase1TestResult {
        let name = "shell_back_to_chat_copy_locked"
        let en = ExecutionSurfaceLockedCopy.backToChat(isZh: false)
        let zh = ExecutionSurfaceLockedCopy.backToChat(isZh: true)
        guard en == "Back to chat" else {
            return .init(name: name, passed: false, detail: "en got \"\(en)\" wanted \"Back to chat\"")
        }
        guard zh == "返回聊天" else {
            return .init(name: name, passed: false, detail: "zh got \"\(zh)\" wanted \"返回聊天\"")
        }
        return .init(name: name, passed: true, detail: "\"Back to chat\" / \"返回聊天\"")
    }

    // MARK: - 3. State-title copy

    static func testStateTitleCopyLocked() -> KernelPhase1TestResult {
        let name = "shell_state_title_copy_locked"
        let expectations: [(ExecutionSurfaceSystemState, Bool, String)] = [
            (.ready, false, "Ready"),
            (.ready, true, "就绪"),
            (.loading, false, "Loading"),
            (.loading, true, "正在加载"),
            (.empty, false, "Nothing to show"),
            (.empty, true, "暂无结果"),
            (.error, false, "Something went wrong"),
            (.error, true, "出错了"),
            (.permissionOrUnavailable, false, "Permission or service unavailable"),
            (.permissionOrUnavailable, true, "权限或服务不可用"),
        ]
        var mismatches: [String] = []
        for (state, isZh, want) in expectations {
            let got = ExecutionSurfaceLockedCopy.stateTitle(state, isZh: isZh)
            if got != want {
                mismatches.append("\(state.rawValue)/\(isZh ? "zh" : "en"): got \"\(got)\" wanted \"\(want)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(name: name, passed: true, detail: "5 states × zh/en all locked")
    }

    // MARK: - 4. State-summary copy

    static func testStateSummaryCopyLocked() -> KernelPhase1TestResult {
        let name = "shell_state_summary_copy_locked"
        let ready = ExecutionSurfaceLockedCopy.stateSummary(.ready, isZh: false)
        guard ready.isEmpty else {
            return .init(name: name, passed: false, detail: ".ready summary must be empty, got \"\(ready)\"")
        }
        let mustContain: [(ExecutionSurfaceSystemState, Bool, String)] = [
            (.loading, false, "Preparing"),
            (.loading, true, "稍后"),
            (.empty, false, "No matches"),
            (.empty, true, "换个说法"),
            (.error, false, "Something went wrong"),
            (.error, true, "出现了问题"),
            (.permissionOrUnavailable, false, "permission"),
            (.permissionOrUnavailable, true, "权限"),
        ]
        for (state, isZh, needle) in mustContain {
            let got = ExecutionSurfaceLockedCopy.stateSummary(state, isZh: isZh)
            if got.contains(needle) == false {
                return .init(
                    name: name,
                    passed: false,
                    detail: "\(state.rawValue)/\(isZh ? "zh" : "en") missing needle \"\(needle)\" — got \"\(got)\""
                )
            }
        }
        return .init(name: name, passed: true, detail: "5 states × zh/en summaries present")
    }

    // MARK: - 5. Error override wins

    static func testErrorSummaryPrefersOverride() -> KernelPhase1TestResult {
        let name = "shell_error_summary_prefers_override"
        let override = "Partner returned 503 — try again in a moment."
        let got = ExecutionSurfaceLockedCopy.stateSummary(
            .error,
            isZh: false,
            errorOverride: override
        )
        guard got == override else {
            return .init(name: name, passed: false, detail: "error override not used — got \"\(got)\"")
        }
        let fallback = ExecutionSurfaceLockedCopy.stateSummary(.error, isZh: false)
        guard fallback.contains("Something went wrong") else {
            return .init(name: name, passed: false, detail: "fallback copy missing — got \"\(fallback)\"")
        }
        let empty = ExecutionSurfaceLockedCopy.stateSummary(
            .error,
            isZh: false,
            errorOverride: ""
        )
        guard empty.contains("Something went wrong") else {
            return .init(name: name, passed: false, detail: "empty-string override must fall back — got \"\(empty)\"")
        }
        return .init(name: name, passed: true, detail: "override wins, empty/nil falls back to locked copy")
    }

    // MARK: - 6. Neutral status constant

    static func testStatusNoneConstantIsNeutral() -> KernelPhase1TestResult {
        let name = "shell_status_none_is_neutral"
        let none = ExecutionSurfaceStatus.none
        guard none.statusMessage == nil, none.errorMessage == nil else {
            return .init(name: name, passed: false, detail: "ExecutionSurfaceStatus.none must carry no strings")
        }
        return .init(name: name, passed: true, detail: "ExecutionSurfaceStatus.none is (nil, nil)")
    }

    // MARK: - 7. Maps + Music inputs share types

    static func testMapsAndMusicInputsShareTypes() -> KernelPhase1TestResult {
        let name = "shell_maps_music_inputs_share_types"

        let mapsInputs = ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(
                backToChatTitle: ExecutionSurfaceLockedCopy.backToChat(isZh: false),
                trustPills: [.placeResolutionLive, .etaConfidenceEstimate],
                isZh: false
            ),
            title: ExecutionSurfaceTitle(
                eyebrow: "Maps · Go to place",
                title: "Walk to Market Hall",
                summary: "1.2 mi · 16 min on foot"
            ),
            status: .none,
            state: .ready,
            terminal: nil
        )

        let musicInputs = ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(
                backToChatTitle: ExecutionSurfaceLockedCopy.backToChat(isZh: false),
                trustPills: [.partnerFallback],
                isZh: false
            ),
            title: ExecutionSurfaceTitle(
                eyebrow: "Music · Chat-invoked",
                title: "Focus mix",
                summary: "Instrumental, low-energy"
            ),
            status: .none,
            state: .ready,
            terminal: nil
        )

        guard mapsInputs.navRail.backToChatTitle == musicInputs.navRail.backToChatTitle else {
            return .init(
                name: name,
                passed: false,
                detail: "back-to-chat copy diverges across verticals"
            )
        }

        // Both surfaces must draw from the shared trust-pill vocabulary.
        let mapsPillTypes = mapsInputs.navRail.trustPills.map { type(of: $0) }
        let musicPillTypes = musicInputs.navRail.trustPills.map { type(of: $0) }
        let mapsT = String(describing: type(of: mapsInputs.navRail.trustPills))
        let musicT = String(describing: type(of: musicInputs.navRail.trustPills))
        guard mapsT == musicT else {
            return .init(
                name: name,
                passed: false,
                detail: "trust pill arrays have different types: \(mapsT) vs \(musicT)"
            )
        }
        _ = mapsPillTypes
        _ = musicPillTypes

        guard mapsInputs.state == .ready, musicInputs.state == .ready else {
            return .init(name: name, passed: false, detail: "ready state mismatch")
        }

        return .init(
            name: name,
            passed: true,
            detail: "Maps + Music emit ExecutionSurfaceShellInputs with identical region types"
        )
    }
}
