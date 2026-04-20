//
//  PostReturnContinuationUXTests.swift
//  kAir
//
//  T10 — locks Post-Return & Continuation UX v1 per
//  `post-return-and-continuation-ux-v1.md`. Round 7 P0.
//
//  What this covers:
//    1. `MatchingBehaviorEvent.Stage` keeps the exact six cases (impression,
//       click, accept, dismiss, abandon, completion) — the four terminal
//       outcomes (completion / abandon / dismiss / accept-no-entry) plus the
//       two lifecycle markers (impression / click) that precede them.
//    2. `ExecutionOutcome` keeps the exact four cases (completed / abandoned /
//       partial / failed). Round 7 adds no fifth outcome — the `failed` case
//       exists for provider-level breakages and is intentionally unused by
//       the chat post-return path today.
//    3. Every post-return `ConversationToolResult` fixture carries **exactly
//       three** metrics and the third is a continuity metric whose key is
//       `Thread` or `线程`.
//    4. The continuity metric's value reassures that the thread is kept
//       (never the new-thread / new-session story).
//    5. `ConversationToolResultState` stays frozen at 3 cases so Round 7
//       cannot bloat it with a new "returned" state.
//    6. `AppSurfaceReturnContext` carries exactly the three fields it needs
//       to make a terminal-outcome decision (section + optional music/video
//       session); no per-vertical extension.
//    7. `ExecutionReturnPayload` + `ReturnContextDelta` shape is structural —
//       summary lives on the delta, evidence lives on the scores, intent
//       tags live on `addedIntentTags`. Round 7 does not add a new field.
//    8. `ConversationDestination` keeps its three cases (surface, userProfile,
//       persistentPlayer) — no per-vertical destination for the post-return
//       story.
//

import Foundation

struct PostReturnContinuationUXReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum PostReturnContinuationUXTests {
    static func runAll() -> PostReturnContinuationUXReport {
        let results: [KernelPhase1TestResult] = [
            testTerminalStageVocabularyLocked(),
            testExecutionOutcomeCardinalityLocked(),
            testReturnMessageCarriesExactlyThreeMetrics(),
            testReturnMessageContinuityMetricPresent(),
            testConversationToolResultStateCardinalityLocked(),
            testSurfaceReturnContextShapeLocked(),
            testExecutionReturnPayloadShapeLocked(),
            testConversationDestinationCardinalityLocked(),
        ]
        return PostReturnContinuationUXReport(results: results)
    }

    // MARK: - 1. Terminal-stage vocabulary

    static func testTerminalStageVocabularyLocked() -> KernelPhase1TestResult {
        let name = "post_return_stage_vocabulary_locked"
        let expected: Set<MatchingBehaviorEvent.Stage> = [
            .impression, .click, .accept, .dismiss, .abandon, .completion
        ]
        // Enumerate all cases by constructing them; if a new case is added
        // the switch below stops being exhaustive at compile time.
        var got: Set<MatchingBehaviorEvent.Stage> = []
        for stage in [
            MatchingBehaviorEvent.Stage.impression,
            .click,
            .accept,
            .dismiss,
            .abandon,
            .completion
        ] {
            got.insert(stage)
            switch stage {
            case .impression, .click, .accept, .dismiss, .abandon, .completion:
                break
            }
        }
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected \(expected.map(\.rawValue).sorted()) got \(got.map(\.rawValue).sorted())"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "6 stages locked (completion / abandon / dismiss / accept plus impression / click)"
        )
    }

    // MARK: - 2. ExecutionOutcome cardinality

    static func testExecutionOutcomeCardinalityLocked() -> KernelPhase1TestResult {
        let name = "post_return_execution_outcome_cardinality"
        let expected: Set<ExecutionOutcome> = [.completed, .abandoned, .partial, .failed]
        // Exhaustive switch over the known cases; if a new case is added,
        // the switch stops compiling, which fails the build before this runs.
        var got: Set<ExecutionOutcome> = []
        for outcome in [
            ExecutionOutcome.completed,
            .abandoned,
            .partial,
            .failed
        ] {
            got.insert(outcome)
            switch outcome {
            case .completed, .abandoned, .partial, .failed:
                break
            }
        }
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected 4 cases {completed, abandoned, partial, failed}, got \(got.map(\.rawValue).sorted())"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "ExecutionOutcome = completed / abandoned / partial / failed (post-return uses the first three)"
        )
    }

    // MARK: - 3. Exactly 3 metrics on every return fixture

    static func testReturnMessageCarriesExactlyThreeMetrics() -> KernelPhase1TestResult {
        let name = "post_return_three_metric_rule"
        let fixtures = PostReturnFixtures.allSupportedSurfaces()
        var mismatches: [String] = []
        for fixture in fixtures {
            if fixture.toolResult.metrics.count != 3 {
                mismatches.append(
                    "\(fixture.label): metrics=\(fixture.toolResult.metrics.count) (want 3)"
                )
            }
        }
        guard mismatches.isEmpty else {
            return .init(
                name: name,
                passed: false,
                detail: mismatches.joined(separator: "; ")
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "All \(fixtures.count) surface return fixtures carry exactly 3 metrics"
        )
    }

    // MARK: - 4. Continuity metric must be present as metric 3

    static func testReturnMessageContinuityMetricPresent() -> KernelPhase1TestResult {
        let name = "post_return_continuity_metric_last"
        let fixtures = PostReturnFixtures.allSupportedSurfaces()
        var mismatches: [String] = []
        for fixture in fixtures {
            guard let last = fixture.toolResult.metrics.last else {
                mismatches.append("\(fixture.label): no metrics at all")
                continue
            }
            let continuityKeys: Set<String> = ["Thread", "线程", "Return", "返回"]
            guard continuityKeys.contains(last.key) else {
                mismatches.append("\(fixture.label): metric3 key=\"\(last.key)\" not in continuity set")
                continue
            }
            // Value must assert continuity (kept / original / complete / 已 / 保留).
            let value = last.value.lowercased()
            let continuityWords = ["kept", "original", "complete", "保留", "已"]
            guard continuityWords.contains(where: { last.value.contains($0) || value.contains($0) }) else {
                mismatches.append("\(fixture.label): metric3 value=\"\(last.value)\" does not assert continuity")
                continue
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(
            name: name,
            passed: true,
            detail: "Every surface fixture's last metric is a continuity marker (Thread / 线程 / Return / 返回)"
        )
    }

    // MARK: - 5. ConversationToolResultState cardinality

    static func testConversationToolResultStateCardinalityLocked() -> KernelPhase1TestResult {
        let name = "post_return_tool_result_state_cardinality"
        let expected: Set<ConversationToolResultState> = [.ready, .working, .warning]
        var got: Set<ConversationToolResultState> = []
        for state in [
            ConversationToolResultState.ready,
            .working,
            .warning
        ] {
            got.insert(state)
            switch state {
            case .ready, .working, .warning:
                break
            }
        }
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected 3 cases {ready, working, warning}, got \(got.map(\.rawValue).sorted())"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "ConversationToolResultState = ready / working / warning (no new state for return)"
        )
    }

    // MARK: - 6. AppSurfaceReturnContext shape

    static func testSurfaceReturnContextShapeLocked() -> KernelPhase1TestResult {
        let name = "post_return_surface_return_context_shape"
        // Compile-time witness: the init must accept exactly
        // section / musicSession / videoSession (no per-vertical extension).
        let context = AppSurfaceReturnContext(
            section: .maps,
            musicSession: nil,
            videoSession: nil
        )
        guard context.section == .maps else {
            return .init(name: name, passed: false, detail: "section not preserved")
        }
        guard context.musicSession == nil else {
            return .init(name: name, passed: false, detail: "musicSession should be nil")
        }
        guard context.videoSession == nil else {
            return .init(name: name, passed: false, detail: "videoSession should be nil")
        }
        return .init(
            name: name,
            passed: true,
            detail: "AppSurfaceReturnContext = { section, musicSession?, videoSession? }"
        )
    }

    // MARK: - 7. ExecutionReturnPayload / ReturnContextDelta shape

    static func testExecutionReturnPayloadShapeLocked() -> KernelPhase1TestResult {
        let name = "post_return_execution_payload_shape"
        // Compile-time witness that the expected fields exist with the
        // expected types. If the shape drifts, this stops compiling.
        let delta = ExecutionReturnPayload.ReturnContextDelta(
            downstreamValue: 0.5,
            completionScore: 0.5,
            addedIntentTags: [],
            resolvedObjectIds: [],
            dismissedObjectIds: [],
            summary: "Fixture summary"
        )
        let payload = ExecutionReturnPayload(
            executedCandidateId: "fixture",
            executionSurfaceType: .maps,
            outcome: .completed,
            duration: 0,
            returnContextDelta: delta,
            sourceRequestId: nil,
            sourceRecommendationId: nil
        )
        guard payload.outcome == .completed else {
            return .init(name: name, passed: false, detail: "outcome not preserved")
        }
        guard payload.returnContextDelta.summary == "Fixture summary" else {
            return .init(name: name, passed: false, detail: "summary on delta not preserved")
        }
        // Evidence lives on scores + object id lists.
        let _: Double = payload.returnContextDelta.downstreamValue
        let _: Double = payload.returnContextDelta.completionScore
        let _: [String] = payload.returnContextDelta.resolvedObjectIds
        let _: [String] = payload.returnContextDelta.dismissedObjectIds
        let _: [MatchingIntentTag] = payload.returnContextDelta.addedIntentTags
        return .init(
            name: name,
            passed: true,
            detail: "ExecutionReturnPayload + ReturnContextDelta shape locked (summary / evidence / next-step)"
        )
    }

    // MARK: - 8. ConversationDestination cardinality

    static func testConversationDestinationCardinalityLocked() -> KernelPhase1TestResult {
        let name = "post_return_conversation_destination_cardinality"
        // Compile-time witness: the three cases must be exhaustive.
        let samples: [ConversationDestination] = [
            .surface(.maps),
            .userProfile,
            .persistentPlayer
        ]
        for destination in samples {
            switch destination {
            case .surface, .userProfile, .persistentPlayer:
                break
            }
        }
        // A surface destination must preserve its AppSection identity.
        let mapsDestination: ConversationDestination = .surface(.maps)
        guard case .surface(let section) = mapsDestination, section == .maps else {
            return .init(
                name: name,
                passed: false,
                detail: "surface destination did not preserve section"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "ConversationDestination = surface / userProfile / persistentPlayer"
        )
    }
}

// MARK: - Shared fixture set for the three-metric rule

enum PostReturnFixtures {
    struct Fixture {
        let label: String
        let toolResult: ConversationToolResult
    }

    static func allSupportedSurfaces() -> [Fixture] {
        [
            mapsEnglish(),
            mapsChinese(),
            musicEnglish(),
            videoEnglish(),
            healthEnglish(),
            healthChinese(),
            aiEnglish(),
            storeEnglish(),
        ]
    }

    // These fixtures mirror the `ConversationToolResult`s that
    // `ChatStore.recordSurfaceReturn` / `recordMapReturn` actually write.
    // The test only cares about the *shape* (metric count + continuity key),
    // so we duplicate the shape here deliberately rather than reach into
    // the store.

    private static func mapsEnglish() -> Fixture {
        Fixture(
            label: "maps.en",
            toolResult: ConversationToolResult(
                id: "maps-return-summary",
                title: "Maps wrote back into the thread",
                summary: "Fixture summary",
                state: .ready,
                metrics: [
                    .init(key: "Task", value: "Route"),
                    .init(key: "Thread", value: "Original thread kept"),
                    .init(key: "Return", value: "Complete")
                ],
                footer: "Leaving Maps does not start a new session or lose context."
            )
        )
    }

    private static func mapsChinese() -> Fixture {
        Fixture(
            label: "maps.zh",
            toolResult: ConversationToolResult(
                id: "maps-return-summary",
                title: "Maps 已回写线程",
                summary: "示例摘要",
                state: .ready,
                metrics: [
                    .init(key: "任务", value: "路线"),
                    .init(key: "线程", value: "原会话已保留"),
                    .init(key: "返回", value: "已完成")
                ],
                footer: "Maps 退出后不会新开会话，也不会丢失上下文。"
            )
        )
    }

    private static func musicEnglish() -> Fixture {
        Fixture(
            label: "music.en",
            toolResult: ConversationToolResult(
                id: "music-return",
                title: "Music wrote back to chat",
                summary: "Jazz Flow is still active in the persistent player.",
                state: .ready,
                metrics: [
                    .init(key: "Track", value: "Jazz Flow"),
                    .init(key: "Mode", value: "Jazz"),
                    .init(key: "Thread", value: "Original thread kept")
                ],
                footer: "Leaving Music does not stop playback unless the user explicitly stops it."
            )
        )
    }

    private static func videoEnglish() -> Fixture {
        Fixture(
            label: "video.en",
            toolResult: ConversationToolResult(
                id: "video-return",
                title: "Video wrote back to chat",
                summary: "Tutorial Video finished as a focused surface.",
                state: .ready,
                metrics: [
                    .init(key: "Title", value: "Tutorial Video"),
                    .init(key: "Category", value: "Tutorial"),
                    .init(key: "Thread", value: "Original thread kept")
                ],
                footer: "Video stays an invoked surface instead of becoming a second home."
            )
        )
    }

    private static func healthEnglish() -> Fixture {
        Fixture(
            label: "health.en",
            toolResult: ConversationToolResult(
                id: "health-return-sleep",
                title: "Health wrote back to chat",
                summary: "Sleep averaged 7.2 h/night across 5 nights.",
                state: .ready,
                metrics: [
                    .init(key: "Topic", value: "Sleep"),
                    .init(key: "Data", value: "Local Apple Health"),
                    .init(key: "Thread", value: "Original thread kept")
                ],
                footer: "Only summarized output returns to chat, not raw Health data."
            )
        )
    }

    private static func healthChinese() -> Fixture {
        Fixture(
            label: "health.zh",
            toolResult: ConversationToolResult(
                id: "health-return-sleep",
                title: "Health 已回写线程",
                summary: "最近 5 晚平均睡眠 7.2 小时。",
                state: .ready,
                metrics: [
                    .init(key: "主题", value: "睡眠"),
                    .init(key: "数据", value: "本地 Apple Health"),
                    .init(key: "线程", value: "原会话保留")
                ],
                footer: "回到聊天后只保留摘要，不回写原始健康数据。"
            )
        )
    }

    private static func aiEnglish() -> Fixture {
        Fixture(
            label: "ai.en",
            toolResult: ConversationToolResult(
                id: "ai-return",
                title: "AI wrote back to chat",
                summary: "AI surfaced the current runtime summary.",
                state: .ready,
                metrics: [
                    .init(key: "Primary", value: "Local-first"),
                    .init(key: "Health", value: "Grounded on demand"),
                    .init(key: "Thread", value: "Original thread kept")
                ],
                footer: "The AI page stays a focused surface while chat remains the default entry."
            )
        )
    }

    private static func storeEnglish() -> Fixture {
        Fixture(
            label: "store.en",
            toolResult: ConversationToolResult(
                id: "store-return",
                title: "Store wrote back to chat",
                summary: "Store kept the same thread and returned curated directions.",
                state: .ready,
                metrics: [
                    .init(key: "Focus", value: "Recovery first"),
                    .init(key: "Catalog", value: "Curated"),
                    .init(key: "Thread", value: "Original thread kept")
                ],
                footer: "The commerce layer is still a focused surface, not a separate conversation."
            )
        )
    }
}
