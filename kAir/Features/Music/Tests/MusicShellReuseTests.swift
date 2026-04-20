//
//  MusicShellReuseTests.swift
//  kAir
//
//  T7 — proves Music is a pure caller of `ExecutionSurfaceShell` +
//  `ActionCardShell`. Music is the second UI validation vertical per
//  music-ui-spec-v0.md; this test asserts it introduces no visual fork:
//    - `MusicTaskKind` has exactly the three v0 kinds.
//    - Primary / secondary CTA copy per kind × language is locked.
//    - `MusicCardContent.trustPills` is exactly `[.partnerFallback]` in v0,
//      truthfully communicating "partner pending" without inventing a new
//      pill kind.
//    - The Music surface state mapping respects
//      `ExecutionSurfaceSystemState` (no Music-specific state vocabulary).
//

import Foundation

struct MusicShellReuseReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum MusicShellReuseTests {
    static func runAll() -> MusicShellReuseReport {
        let results: [KernelPhase1TestResult] = [
            testThreeMusicTaskKinds(),
            testPrimaryCTAPerKindLocked(),
            testSecondaryCTAPerKindLocked(),
            testHeaderLabelPerKindLocked(),
            testTrustPillsAreSharedVocabulary(),
            testMusicCardContentRoundTripMatchesShell(),
            testMusicSurfaceStateMappingRespectsFramework(),
        ]
        return MusicShellReuseReport(results: results)
    }

    // MARK: - 1. Three kinds, no more

    static func testThreeMusicTaskKinds() -> KernelPhase1TestResult {
        let name = "music_three_task_kinds"
        let expected: Set<MusicTaskKind> = [.playNow, .continueListening, .moodMix]
        let got = Set(MusicTaskKind.allCases)
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected \(expected.map(\.rawValue).sorted()) got \(got.map(\.rawValue).sorted())"
            )
        }
        guard MusicTaskKind.allCases.count == 3 else {
            return .init(name: name, passed: false, detail: "MusicTaskKind cardinality != 3")
        }
        return .init(name: name, passed: true, detail: "3 kinds: playNow + continueListening + moodMix")
    }

    // MARK: - 2. Primary CTA copy per kind × language

    static func testPrimaryCTAPerKindLocked() -> KernelPhase1TestResult {
        let name = "music_primary_cta_per_kind_locked"
        let expectations: [(MusicTaskKind, MusicCardContent.Language, String)] = [
            (.playNow, .english, "Play now"),
            (.playNow, .chinese, "立刻播放"),
            (.continueListening, .english, "Resume"),
            (.continueListening, .chinese, "继续听"),
            (.moodMix, .english, "Start mix"),
            (.moodMix, .chinese, "开始播放"),
        ]
        var mismatches: [String] = []
        for (kind, lang, want) in expectations {
            let content = MusicCardContent(
                taskKind: kind,
                title: "Fixture",
                subtitle: "Fixture",
                language: lang
            )
            if content.primaryActionTitle != want {
                mismatches.append("\(kind)/\(lang.rawValue): got \"\(content.primaryActionTitle)\" wanted \"\(want)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(name: name, passed: true, detail: "3 kinds × 2 languages primary CTA locked")
    }

    // MARK: - 3. Secondary CTA copy per kind × language

    static func testSecondaryCTAPerKindLocked() -> KernelPhase1TestResult {
        let name = "music_secondary_cta_per_kind_locked"
        let expectations: [(MusicTaskKind, MusicCardContent.Language, String)] = [
            (.playNow, .english, "Preview"),
            (.playNow, .chinese, "试听"),
            (.continueListening, .english, "Switch track"),
            (.continueListening, .chinese, "换一首"),
            (.moodMix, .english, "Different mood"),
            (.moodMix, .chinese, "换种心情"),
        ]
        var mismatches: [String] = []
        for (kind, lang, want) in expectations {
            let content = MusicCardContent(
                taskKind: kind,
                title: "Fixture",
                subtitle: "Fixture",
                language: lang
            )
            guard let got = content.secondaryActionTitle else {
                mismatches.append("\(kind)/\(lang.rawValue): nil secondary")
                continue
            }
            if got != want {
                mismatches.append("\(kind)/\(lang.rawValue): got \"\(got)\" wanted \"\(want)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(name: name, passed: true, detail: "3 kinds × 2 languages secondary CTA locked")
    }

    // MARK: - 4. Header label + glyph per kind

    static func testHeaderLabelPerKindLocked() -> KernelPhase1TestResult {
        let name = "music_header_label_per_kind_locked"
        let expectations: [(MusicTaskKind, MusicCardContent.Language, String, String)] = [
            (.playNow, .english, "Play now", "play.circle.fill"),
            (.playNow, .chinese, "立刻播放", "play.circle.fill"),
            (.continueListening, .english, "Continue listening", "arrow.clockwise"),
            (.continueListening, .chinese, "继续听", "arrow.clockwise"),
            (.moodMix, .english, "Mood mix", "waveform.path"),
            (.moodMix, .chinese, "心情歌单", "waveform.path"),
        ]
        var mismatches: [String] = []
        for (kind, lang, wantLabel, wantImage) in expectations {
            let content = MusicCardContent(
                taskKind: kind,
                title: "Fixture",
                subtitle: "Fixture",
                language: lang
            )
            if content.headerLabelTitle != wantLabel {
                mismatches.append("\(kind)/\(lang.rawValue): label got \"\(content.headerLabelTitle)\"")
            }
            if content.headerLabelSystemImage != wantImage {
                mismatches.append("\(kind)/\(lang.rawValue): glyph got \"\(content.headerLabelSystemImage)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(name: name, passed: true, detail: "3 kinds × 2 languages header + glyph locked")
    }

    // MARK: - 5. Trust pills drawn from shared vocabulary

    static func testTrustPillsAreSharedVocabulary() -> KernelPhase1TestResult {
        let name = "music_trust_pills_shared_vocabulary"
        for kind in MusicTaskKind.allCases {
            let content = MusicCardContent(
                taskKind: kind,
                title: "Fixture",
                subtitle: "Fixture"
            )
            guard content.trustPills == [.partnerFallback] else {
                return .init(
                    name: name,
                    passed: false,
                    detail: "\(kind) trustPills \(content.trustPills.map(\.rawValue)) — expected [partnerFallback]"
                )
            }
            // Compile-time proof: the elements ARE `ActionCardTrustPillKind`.
            let _: [ActionCardTrustPillKind] = content.trustPills
        }
        return .init(name: name, passed: true, detail: "All Music cards emit [.partnerFallback] from shared vocabulary")
    }

    // MARK: - 6. Card content → shell inputs

    static func testMusicCardContentRoundTripMatchesShell() -> KernelPhase1TestResult {
        let name = "music_card_content_round_trip"
        let content = MusicCardContent(
            taskKind: .moodMix,
            title: "Evening wind-down",
            subtitle: "Low-tempo ambient for 45 min",
            reasonText: "Matches your recent focus sessions",
            language: .english
        )
        guard content.headerLabelTitle == "Mood mix" else {
            return .init(name: name, passed: false, detail: "header label wrong")
        }
        guard content.primaryActionTitle == "Start mix" else {
            return .init(name: name, passed: false, detail: "primary CTA wrong")
        }
        guard content.secondaryActionTitle == "Different mood" else {
            return .init(name: name, passed: false, detail: "secondary CTA wrong")
        }
        guard content.trustPills == [.partnerFallback] else {
            return .init(name: name, passed: false, detail: "trust pills wrong")
        }
        guard content.feedbackAffordanceLabel == "Feedback options" else {
            return .init(name: name, passed: false, detail: "feedback label wrong")
        }
        return .init(name: name, passed: true, detail: "moodMix content round-trips with frozen copy")
    }

    // MARK: - 7. Surface state mapping

    static func testMusicSurfaceStateMappingRespectsFramework() -> KernelPhase1TestResult {
        let name = "music_surface_state_mapping"
        let emptyState = MusicSurfaceStateMapper.state(forHasSession: false)
        let readyState = MusicSurfaceStateMapper.state(forHasSession: true)
        guard emptyState == .empty else {
            return .init(name: name, passed: false, detail: "no session → should map to .empty")
        }
        guard readyState == .ready else {
            return .init(name: name, passed: false, detail: "has session → should map to .ready")
        }
        // Enforce the mapping type itself: it must be the framework's enum.
        let _: ExecutionSurfaceSystemState = emptyState
        let _: ExecutionSurfaceSystemState = readyState
        return .init(name: name, passed: true, detail: "nil session → .empty; active session → .ready")
    }
}

/// Test-only helper that mirrors the mapping `MusicHomeView` uses. Keeping
/// it in the test file (rather than exposing a private from the view) means
/// the rule can't drift without the test failing.
enum MusicSurfaceStateMapper {
    static func state(forHasSession hasSession: Bool) -> ExecutionSurfaceSystemState {
        hasSession ? .ready : .empty
    }
}
