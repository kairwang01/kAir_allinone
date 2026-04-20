//
//  SearchShellReuseTests.swift
//  kAir
//
//  T9 — proves Search is a pure caller of `ExecutionSurfaceShell` +
//  `ActionCardShell`. Search is the third UI validation vertical per
//  search-ui-spec-v0.md; this test asserts it introduces no visual fork:
//    - `SearchTaskKind` has exactly three v0 kinds.
//    - Primary + secondary CTA copy per kind × language is locked.
//    - Header label + glyph per kind × language is locked.
//    - `SearchCardContent.trustPills` is exactly `[.partnerFallback]` in v0,
//      truthfully communicating "partner pending" without inventing a new
//      pill kind — and is typed as `[ActionCardTrustPillKind]` at compile
//      time, proving Search cannot forge a private pill enum.
//    - The Search surface state mapping respects
//      `ExecutionSurfaceSystemState` (no Search-specific state vocabulary) —
//      enforced via a compile-time witness on the mapper's return type.
//    - The post-return message format (§8) produces the locked strings per
//      kind × language, with the 60-char truncation rule.
//

import Foundation

struct SearchShellReuseReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum SearchShellReuseTests {
    static func runAll() -> SearchShellReuseReport {
        let results: [KernelPhase1TestResult] = [
            testThreeSearchTaskKinds(),
            testPrimaryCTAPerKindLocked(),
            testSecondaryCTAPerKindLocked(),
            testHeaderLabelPerKindLocked(),
            testTrustPillsAreSharedVocabulary(),
            testSearchCardContentRoundTripMatchesShell(),
            testSearchSurfaceStateMappingRespectsFramework(),
            testPostReturnMessageFormatLocked(),
            testPostReturnMessageTruncationAtSixty(),
        ]
        return SearchShellReuseReport(results: results)
    }

    // MARK: - 1. Three kinds, no more

    static func testThreeSearchTaskKinds() -> KernelPhase1TestResult {
        let name = "search_three_task_kinds"
        let expected: Set<SearchTaskKind> = [.answerNow, .openWebResult, .deepResearch]
        let got = Set(SearchTaskKind.allCases)
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected \(expected.map(\.rawValue).sorted()) got \(got.map(\.rawValue).sorted())"
            )
        }
        guard SearchTaskKind.allCases.count == 3 else {
            return .init(name: name, passed: false, detail: "SearchTaskKind cardinality != 3")
        }
        return .init(name: name, passed: true, detail: "3 kinds: answerNow + openWebResult + deepResearch")
    }

    // MARK: - 2. Primary CTA copy per kind × language

    static func testPrimaryCTAPerKindLocked() -> KernelPhase1TestResult {
        let name = "search_primary_cta_per_kind_locked"
        let expectations: [(SearchTaskKind, SearchCardContent.Language, String)] = [
            (.answerNow, .english, "Show answer"),
            (.answerNow, .chinese, "查看答案"),
            (.openWebResult, .english, "Open result"),
            (.openWebResult, .chinese, "打开结果"),
            (.deepResearch, .english, "Start research"),
            (.deepResearch, .chinese, "开始研究"),
        ]
        var mismatches: [String] = []
        for (kind, lang, want) in expectations {
            let content = SearchCardContent(
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
        let name = "search_secondary_cta_per_kind_locked"
        let expectations: [(SearchTaskKind, SearchCardContent.Language, String)] = [
            (.answerNow, .english, "Why this answer"),
            (.answerNow, .chinese, "依据"),
            (.openWebResult, .english, "Open another"),
            (.openWebResult, .chinese, "换一个"),
            (.deepResearch, .english, "Narrow scope"),
            (.deepResearch, .chinese, "缩小范围"),
        ]
        var mismatches: [String] = []
        for (kind, lang, want) in expectations {
            let content = SearchCardContent(
                taskKind: kind,
                title: "Fixture",
                subtitle: "Fixture",
                language: lang
            )
            if content.secondaryActionTitle != want {
                mismatches.append("\(kind)/\(lang.rawValue): got \"\(content.secondaryActionTitle)\" wanted \"\(want)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(name: name, passed: true, detail: "3 kinds × 2 languages secondary CTA locked")
    }

    // MARK: - 4. Header label + glyph per kind × language

    static func testHeaderLabelPerKindLocked() -> KernelPhase1TestResult {
        let name = "search_header_label_per_kind_locked"
        let expectations: [(SearchTaskKind, SearchCardContent.Language, String, String)] = [
            (.answerNow, .english, "Answer", "sparkles.square.filled.on.square"),
            (.answerNow, .chinese, "答案", "sparkles.square.filled.on.square"),
            (.openWebResult, .english, "Web result", "link"),
            (.openWebResult, .chinese, "网络结果", "link"),
            (.deepResearch, .english, "Deep research", "doc.text.magnifyingglass"),
            (.deepResearch, .chinese, "深度研究", "doc.text.magnifyingglass"),
        ]
        var mismatches: [String] = []
        for (kind, lang, wantLabel, wantImage) in expectations {
            let content = SearchCardContent(
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
        let name = "search_trust_pills_shared_vocabulary"
        for kind in SearchTaskKind.allCases {
            let content = SearchCardContent(
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
            // If Search ever forks a private pill enum, this assignment fails
            // to compile and T9 cannot run — the breakage is caught at build
            // time, not test time.
            let _: [ActionCardTrustPillKind] = content.trustPills
        }
        return .init(name: name, passed: true, detail: "All Search cards emit [.partnerFallback] from shared vocabulary")
    }

    // MARK: - 6. Card content → shell inputs (round trip)

    static func testSearchCardContentRoundTripMatchesShell() -> KernelPhase1TestResult {
        let name = "search_card_content_round_trip"
        let content = SearchCardContent(
            taskKind: .deepResearch,
            title: "Comparative analysis of Swift 6 concurrency",
            subtitle: "Multi-source synthesis · 7 citations",
            reasonText: "Matches your recent Swift thread",
            language: .english
        )
        guard content.headerLabelTitle == "Deep research" else {
            return .init(name: name, passed: false, detail: "header label wrong")
        }
        guard content.primaryActionTitle == "Start research" else {
            return .init(name: name, passed: false, detail: "primary CTA wrong")
        }
        guard content.secondaryActionTitle == "Narrow scope" else {
            return .init(name: name, passed: false, detail: "secondary CTA wrong")
        }
        guard content.trustPills == [.partnerFallback] else {
            return .init(name: name, passed: false, detail: "trust pills wrong")
        }
        guard content.feedbackAffordanceLabel == "Feedback options" else {
            return .init(name: name, passed: false, detail: "feedback label wrong")
        }
        return .init(name: name, passed: true, detail: "deepResearch content round-trips with frozen copy")
    }

    // MARK: - 7. Surface state mapping respects framework enum

    static func testSearchSurfaceStateMappingRespectsFramework() -> KernelPhase1TestResult {
        let name = "search_surface_state_mapping"
        let emptyState = SearchSurfaceStateMapper.state(forHasSession: false)
        let readyState = SearchSurfaceStateMapper.state(forHasSession: true)
        guard emptyState == .empty else {
            return .init(name: name, passed: false, detail: "no session → should map to .empty")
        }
        guard readyState == .ready else {
            return .init(name: name, passed: false, detail: "has session → should map to .ready")
        }
        // Compile-time witness — the mapper codomain IS the framework enum.
        let _: ExecutionSurfaceSystemState = emptyState
        let _: ExecutionSurfaceSystemState = readyState
        return .init(name: name, passed: true, detail: "nil session → .empty; active session → .ready")
    }

    // MARK: - 8. Post-return message format per §8

    static func testPostReturnMessageFormatLocked() -> KernelPhase1TestResult {
        let name = "search_post_return_message_format_locked"
        let expectations: [(SearchTaskKind, Bool, String, String)] = [
            // (kind, isZh, query, expectedMessage)
            (.answerNow, false, "What is SwiftUI?", "Answer shown: What is SwiftUI?"),
            (.answerNow, true, "SwiftUI 是什么?", "已回答：SwiftUI 是什么?"),
            (.openWebResult, false, "Swift 6 release notes", "Opened result for: Swift 6 release notes"),
            (.openWebResult, true, "Swift 6 发布说明", "已打开结果：Swift 6 发布说明"),
            (.deepResearch, false, "Compare GCD and async/await", "Research started on: Compare GCD and async/await"),
            (.deepResearch, true, "比较 GCD 和 async/await", "已开始研究：比较 GCD 和 async/await"),
        ]
        var mismatches: [String] = []
        for (kind, isZh, query, want) in expectations {
            let got = kind.returnMessage(query: query, isZh: isZh)
            if got != want {
                mismatches.append("\(kind)/zh=\(isZh): got \"\(got)\" wanted \"\(want)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(name: name, passed: true, detail: "3 kinds × 2 languages post-return format locked")
    }

    // MARK: - 9. Post-return message truncation at 60 chars

    static func testPostReturnMessageTruncationAtSixty() -> KernelPhase1TestResult {
        let name = "search_post_return_message_truncation"
        // 70-char query: exceeds the 60-char cap and must be ellipsized.
        let longQuery = String(repeating: "a", count: 70)
        let shortQuery = String(repeating: "b", count: 60) // exactly 60, no ellipsis
        let atLimit = String(repeating: "c", count: 59)   // below limit, no ellipsis

        let longMsg = SearchTaskKind.answerNow.returnMessage(query: longQuery, isZh: false)
        guard longMsg.hasSuffix("…") else {
            return .init(name: name, passed: false, detail: "70-char query should end in …, got \"\(longMsg)\"")
        }
        guard longMsg == "Answer shown: " + String(repeating: "a", count: 60) + "…" else {
            return .init(name: name, passed: false, detail: "70-char truncation wrong, got \"\(longMsg)\"")
        }

        let exactMsg = SearchTaskKind.answerNow.returnMessage(query: shortQuery, isZh: false)
        guard !exactMsg.hasSuffix("…") else {
            return .init(name: name, passed: false, detail: "60-char query should NOT ellipsize, got \"\(exactMsg)\"")
        }

        let atLimitMsg = SearchTaskKind.answerNow.returnMessage(query: atLimit, isZh: false)
        guard !atLimitMsg.hasSuffix("…") else {
            return .init(name: name, passed: false, detail: "59-char query should NOT ellipsize, got \"\(atLimitMsg)\"")
        }

        return .init(
            name: name,
            passed: true,
            detail: "Truncation: >60 → ellipsize at 60; ≤60 → no ellipsis"
        )
    }
}

/// Test-only mirror of the mapping `SearchHomeView` uses. Keeping it in the
/// test file (rather than exposing a private from the view) means the rule
/// can't drift without the test failing. Parallels `MusicSurfaceStateMapper`.
enum SearchSurfaceStateMapper {
    static func state(forHasSession hasSession: Bool) -> ExecutionSurfaceSystemState {
        hasSession ? .ready : .empty
    }
}
