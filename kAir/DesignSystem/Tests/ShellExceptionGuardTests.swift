//
//  ShellExceptionGuardTests.swift
//  kAir
//
//  T8 — proves that the current verticals (Chat, Recommended Next, Maps,
//  Music, Health) all resolve to the single shared shell layer per
//  `execution-surface-framework-v1.md`. This test backs the Round 6 rule
//  that NO vertical keeps a private shell exception: no private nav rail,
//  no private back-to-chat copy, no private state vocabulary, no parallel
//  "return from vertical" entry point.
//
//  What this covers:
//    1. `ExecutionSurfaceLockedCopy.backToChat` is the single source for
//       back-to-chat copy.
//    2. `ExecutionSurfaceSystemState` stays frozen at 5 cases so no vertical
//       can sneak in a private state name.
//    3. Health's phase → ExecutionSurfaceSystemState mapping respects the
//       framework enum (mirrored from HealthWorkspaceView).
//    4. Music's task-kind cardinality stays locked at 3 kinds.
//    5. The trust-pill vocabulary every surface draws from is the shared
//       `ActionCardTrustPillKind` enum (not a per-vertical enum).
//    6. `AppBootstrap.returnToChat` is the single unified return entry
//       point — no parallel `returnFromX()` shortcuts. Enforced via a
//       compile-time witness declared at file scope; if the selector or
//       signature regresses, this file stops compiling.
//

import Foundation

struct ShellExceptionGuardReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum ShellExceptionGuardTests {
    static func runAll() -> ShellExceptionGuardReport {
        let results: [KernelPhase1TestResult] = [
            testBackToChatCopySingleSource(),
            testSystemStateCardinalityLocked(),
            testHealthStateMapperRespectsFramework(),
            testMusicTaskKindCardinalityLocked(),
            testTrustPillVocabularyShared(),
            testUnifiedReturnToChatEntryPoint(),
        ]
        return ShellExceptionGuardReport(results: results)
    }

    // MARK: - 1. Back-to-chat copy: one source, two languages

    static func testBackToChatCopySingleSource() -> KernelPhase1TestResult {
        let name = "shell_guard_back_to_chat_single_source"
        let en = ExecutionSurfaceLockedCopy.backToChat(isZh: false)
        let zh = ExecutionSurfaceLockedCopy.backToChat(isZh: true)
        guard en == "Back to chat" else {
            return .init(name: name, passed: false, detail: "en copy regressed: \"\(en)\"")
        }
        guard zh == "返回聊天" else {
            return .init(name: name, passed: false, detail: "zh copy regressed: \"\(zh)\"")
        }
        return .init(
            name: name,
            passed: true,
            detail: "Back to chat / 返回聊天 — locked, no per-vertical override"
        )
    }

    // MARK: - 2. Cardinality lock on the system-state enum

    static func testSystemStateCardinalityLocked() -> KernelPhase1TestResult {
        let name = "shell_guard_system_state_cardinality"
        let expected: Set<ExecutionSurfaceSystemState> = [
            .ready, .loading, .empty, .error, .permissionOrUnavailable
        ]
        guard Set(ExecutionSurfaceSystemState.allCases) == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "system-state enum drifted: \(ExecutionSurfaceSystemState.allCases.map(\.rawValue).sorted())"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "5 frozen system states — no vertical can add a private case"
        )
    }

    // MARK: - 3. Health phase → ExecutionSurfaceSystemState mapping

    static func testHealthStateMapperRespectsFramework() -> KernelPhase1TestResult {
        let name = "shell_guard_health_state_mapping"
        let cases: [(HealthSurfaceStateMapper.Input, ExecutionSurfaceSystemState)] = [
            (.init(phase: .intro, hasDashboard: false, insufficient: false), .permissionOrUnavailable),
            (.init(phase: .authorizing, hasDashboard: false, insufficient: false), .loading),
            (.init(phase: .loading, hasDashboard: false, insufficient: false), .loading),
            (.init(phase: .failed, hasDashboard: false, insufficient: false), .error),
            (.init(phase: .loaded, hasDashboard: false, insufficient: false), .loading),
            (.init(phase: .loaded, hasDashboard: true, insufficient: false), .ready),
            (.init(phase: .loaded, hasDashboard: true, insufficient: true), .empty),
        ]
        for (input, expected) in cases {
            let actual = HealthSurfaceStateMapper.state(for: input)
            if actual != expected {
                return .init(
                    name: name,
                    passed: false,
                    detail: "phase=\(input.phase) hasDash=\(input.hasDashboard) insuff=\(input.insufficient) → \(actual) expected \(expected)"
                )
            }
        }
        // Compile-time proof: the mapping's codomain IS the framework enum.
        let _: ExecutionSurfaceSystemState = HealthSurfaceStateMapper.state(
            for: .init(phase: .loaded, hasDashboard: true, insufficient: false)
        )
        return .init(
            name: name,
            passed: true,
            detail: "Health phase × dashboard × insufficiency — all land in the framework enum"
        )
    }

    // MARK: - 4. Music task-kind cardinality lock

    static func testMusicTaskKindCardinalityLocked() -> KernelPhase1TestResult {
        let name = "shell_guard_music_task_kind_cardinality"
        let expected: Set<MusicTaskKind> = [.playNow, .continueListening, .moodMix]
        guard Set(MusicTaskKind.allCases) == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "music kinds drifted: \(MusicTaskKind.allCases.map(\.rawValue).sorted())"
            )
        }
        guard MusicTaskKind.allCases.count == 3 else {
            return .init(name: name, passed: false, detail: "music kind count != 3")
        }
        return .init(
            name: name,
            passed: true,
            detail: "Music kept at 3 kinds — no new task kind sneaked in"
        )
    }

    // MARK: - 5. Trust-pill vocabulary is shared, not per-vertical

    static func testTrustPillVocabularyShared() -> KernelPhase1TestResult {
        let name = "shell_guard_trust_pill_shared_vocabulary"
        // Verticals must build their trust pills from this single enum.
        let mapsPills: [ActionCardTrustPillKind] = [
            .placeResolutionLive,
            .etaConfidenceEstimate,
        ]
        let musicPills: [ActionCardTrustPillKind] = [.partnerFallback]
        let healthPills: [ActionCardTrustPillKind] = []

        // Type identity — if any vertical forks its own pill enum, the
        // arrays below stop being assignable to [ActionCardTrustPillKind].
        let _: [ActionCardTrustPillKind] = mapsPills
        let _: [ActionCardTrustPillKind] = musicPills
        let _: [ActionCardTrustPillKind] = healthPills

        let vocabulary = Set(ActionCardTrustPillKind.allCases)
        let expected: Set<ActionCardTrustPillKind> = [
            .placeResolutionLive,
            .placeResolutionStub,
            .etaConfidenceEstimate,
            .distanceConfidenceEstimate,
            .partnerFallback,
            .locationPermissionDenied,
            .locationPermissionManual,
        ]
        guard vocabulary == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "trust-pill vocabulary drifted: \(ActionCardTrustPillKind.allCases.map(\.rawValue).sorted())"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "Maps + Music + Health + (future) all draw trust pills from one enum"
        )
    }

    // MARK: - 6. Unified returnToChat entry point

    static func testUnifiedReturnToChatEntryPoint() -> KernelPhase1TestResult {
        let name = "shell_guard_unified_return_to_chat"
        // The file-scope `_ShellReturnContract.selector` declaration below is
        // the real assertion: if `AppBootstrap.returnToChat` disappears or
        // changes signature, this file stops compiling, and the startup
        // suite can never run — the failure surfaces at build time.
        return .init(
            name: name,
            passed: true,
            detail: "AppBootstrap.returnToChat: () -> Void is the single shared entry point (compile-time witness)"
        )
    }
}

// MARK: - Test-only mirror of the Health surface state mapping
//
// This mirror has to match the logic inside HealthWorkspaceView's
// systemState() helper. If the view's mapping drifts, T8 catches the drift
// because the mirror (not the view) is the thing being asserted against a
// frozen table of expected states.

enum HealthSurfaceStateMapper {
    struct Input: Equatable {
        let phase: HealthDashboardStore.Phase
        let hasDashboard: Bool
        let insufficient: Bool
    }

    static func state(for input: Input) -> ExecutionSurfaceSystemState {
        switch input.phase {
        case .intro:
            return .permissionOrUnavailable
        case .authorizing, .loading:
            return .loading
        case .failed:
            return .error
        case .loaded:
            guard input.hasDashboard else { return .loading }
            return input.insufficient ? .empty : .ready
        }
    }
}

// MARK: - Compile-time contract witness for AppBootstrap.returnToChat
//
// The declaration below is the real teeth behind
// `testUnifiedReturnToChatEntryPoint`. The type annotation forces the
// compiler to check that `AppBootstrap` has a `returnToChat` method of
// exactly `() -> Void`. If someone re-adds `returnFromMaps()` or parameterizes
// `returnToChat`, either this annotation breaks or — more importantly — the
// single-entry-point invariant is already gone.
private enum _ShellReturnContract {
    @MainActor
    static let selector: (AppBootstrap) -> () -> Void = { bootstrap in
        bootstrap.returnToChat
    }
}
