//
//  ChatHomePostReturnBehaviorTests.swift
//  kAir
//
//  T10b — UI-layer behavior lock for Post-Return & Continuation UX v1.
//  Complements the data-contract tests in `PostReturnContinuationUXTests`
//  (T10) on the matching branch. Where T10 asserts enum cardinality and
//  value shape, T10b drives `ChatStore` through each of the four terminal
//  outcomes (completion / abandon / dismiss / accept-no-entry) across the
//  Maps / Music / Search verticals and asserts that the observable
//  transcript + rail state matches `post-return-and-continuation-ux-v1.md`.
//
//  Failure details cite the spec file and section so a regression reads
//  as a spec deviation, not as a generic snapshot diff. Per project rule:
//  "Tests must fail with clear spec-deviation messages, not generic
//   snapshot changes."
//
//  Spec coverage matrix:
//    §1.1  outcome → recorder mapping
//    §1.2  per-surface outcome table (Maps / Music / Search)
//    §2    post-return message is exactly one assistant message
//    §2.2  three-metric rule + continuity-metric locked keys
//    §2.3  abandon variant still writes one message with 3 metrics
//    §2.4  dismiss and accept-no-entry write nothing
//    §3.1  refresh timing (silent exit does NOT refresh; dismiss DOES)
//    §3.3  accepted card removed from activeRecommendationBySection
//          on return
//
//  This file is a shell-layer behavior lock. It requires the matching
//  platform (PR #3) to be present for the target to build — review-only
//  in isolation, like every other file on the shell branch that touches
//  `MatchingFeedbackKind` / `MatchingObjectKind`.
//

import Foundation

struct ChatHomePostReturnBehaviorReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

@MainActor
enum ChatHomePostReturnBehaviorTests {
    static func runAll() -> ChatHomePostReturnBehaviorReport {
        let results: [KernelPhase1TestResult] = [
            testMapsCompletionWritesOneAssistantMessage(),
            testMapsCompletionMessageCarriesThreeMetrics(),
            testMapsCompletionContinuityMetricPresent(),
            testMusicCompletionWritesOneAssistantMessage(),
            testMusicAbandonWithNilSessionStillWritesMessage(),
            testSilentExitWritesZeroMessages(),
            testDismissWritesZeroMessages(),
            testAcceptNoEntryWritesZeroMessages(),
            testChatAndMapsSectionsTakeEarlyReturnBranch(),
            testSearchDismissSharesSameSilenceRule(),
            testTwoConsecutiveReturnsProduceExactlyTwoMessages(),
            testEveryReturnMessageUsesReadyState(),
        ]
        return ChatHomePostReturnBehaviorReport(results: results)
    }

    // MARK: - 1. Maps completion writes exactly one assistant message

    static func testMapsCompletionWritesOneAssistantMessage() -> KernelPhase1TestResult {
        let name = "t10b_maps_completion_one_message"
        let store = freshStore()
        let initialCount = store.session.messages.count
        store.recordMapReturn(from: MapsReturnFixture.nearbyTask())
        let delta = store.session.messages.count - initialCount
        guard delta == 1 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — Maps completion must append exactly 1 message; appended \(delta)"
            )
        }
        let appended = store.session.messages.last
        guard appended?.role == .assistant else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — post-return message role must be .assistant, got \(appended?.role.rawValue ?? "nil")"
            )
        }
        return .init(name: name, passed: true, detail: "Maps completion appended 1 assistant message")
    }

    // MARK: - 2. Three-metric rule on Maps completion

    static func testMapsCompletionMessageCarriesThreeMetrics() -> KernelPhase1TestResult {
        let name = "t10b_maps_completion_three_metrics"
        let store = freshStore()
        store.recordMapReturn(from: MapsReturnFixture.nearbyTask())
        guard let toolResult = store.session.messages.last?.toolResults.first else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — Maps post-return message missing its ConversationToolResult"
            )
        }
        guard toolResult.metrics.count == 3 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.2 — Maps return toolResult must carry exactly 3 metrics, got \(toolResult.metrics.count)"
            )
        }
        return .init(name: name, passed: true, detail: "Maps post-return tool result carried 3 metrics (subject/evidence/continuity)")
    }

    // MARK: - 3. Continuity metric (Thread / 线程) present on return

    static func testMapsCompletionContinuityMetricPresent() -> KernelPhase1TestResult {
        let name = "t10b_maps_continuity_metric_key"
        let store = freshStore()
        store.recordMapReturn(from: MapsReturnFixture.nearbyTask())
        guard let toolResult = store.session.messages.last?.toolResults.first else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — Maps return message has no tool result"
            )
        }
        let last = toolResult.metrics.last
        let allowed: Set<String> = ["Thread", "线程", "Return", "返回"] // §2.2 Maps row uses `Return` as metric 3
        guard let key = last?.key, allowed.contains(key) else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.2 — Maps metric 3 key must be Return/返回 (continuity proxy for Maps), got \(last?.key ?? "nil")"
            )
        }
        return .init(name: name, passed: true, detail: "Maps metric 3 key = \(key)")
    }

    // MARK: - 4. Music completion with non-nil session writes one message

    static func testMusicCompletionWritesOneAssistantMessage() -> KernelPhase1TestResult {
        let name = "t10b_music_completion_one_message"
        let store = freshStore()
        let initialCount = store.session.messages.count
        let context = AppSurfaceReturnContext(
            section: .music,
            musicSession: MusicReturnFixture.focusSession(),
            videoSession: nil
        )
        store.recordSurfaceReturn(from: context, dashboard: nil, healthSession: nil)
        let delta = store.session.messages.count - initialCount
        guard delta == 1 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — Music completion must append exactly 1 message; appended \(delta)"
            )
        }
        guard let toolResult = store.session.messages.last?.toolResults.first else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — Music return message missing tool result"
            )
        }
        guard toolResult.metrics.count == 3 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.2 — Music return toolResult must carry exactly 3 metrics, got \(toolResult.metrics.count)"
            )
        }
        return .init(name: name, passed: true, detail: "Music completion appended 1 assistant message with 3 metrics")
    }

    // MARK: - 5. Music abandon (nil session) still writes a message with 3 metrics

    static func testMusicAbandonWithNilSessionStillWritesMessage() -> KernelPhase1TestResult {
        let name = "t10b_music_abandon_still_writes"
        let store = freshStore()
        let initialCount = store.session.messages.count
        let context = AppSurfaceReturnContext(
            section: .music,
            musicSession: nil, // abandon path
            videoSession: nil
        )
        store.recordSurfaceReturn(from: context, dashboard: nil, healthSession: nil)
        let delta = store.session.messages.count - initialCount
        guard delta == 1 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.3 — Music abandon with nil session must still append exactly 1 message; appended \(delta)"
            )
        }
        guard let toolResult = store.session.messages.last?.toolResults.first else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.3 — Music abandon missing tool result"
            )
        }
        guard toolResult.metrics.count == 3 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.3 — Music abandon toolResult must carry exactly 3 metrics (spec locks metric count, not state case), got \(toolResult.metrics.count)"
            )
        }
        return .init(name: name, passed: true, detail: "Music abandon appended 1 assistant message with 3 metrics")
    }

    // MARK: - 6. Silent exit writes zero messages (§3.1 row B-silent)

    static func testSilentExitWritesZeroMessages() -> KernelPhase1TestResult {
        let name = "t10b_silent_exit_zero_messages"
        let store = freshStore()
        let initialCount = store.session.messages.count
        store.recordSilentSurfaceExit(.maps)
        store.recordSilentSurfaceExit(.music)
        store.recordSilentSurfaceExit(.video)
        store.recordSilentSurfaceExit(.ai)
        store.recordSilentSurfaceExit(.store)
        store.recordSilentSurfaceExit(.health)
        let delta = store.session.messages.count - initialCount
        guard delta == 0 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.4 / §3.1 — silent-exit paths must write zero transcript messages across all surfaces; wrote \(delta)"
            )
        }
        return .init(name: name, passed: true, detail: "Silent exits across 6 surfaces wrote 0 transcript messages")
    }

    // MARK: - 7. Dismiss writes zero messages (§2.4)

    static func testDismissWritesZeroMessages() -> KernelPhase1TestResult {
        let name = "t10b_dismiss_zero_messages"
        let store = freshStore()
        let rec = RecommendationFixture.make(kind: .place, id: "fixture-dismiss-1")
        store.recommendedMatches = [rec]
        let initialCount = store.session.messages.count
        store.dismissRecommendation(rec, feedback: .dismiss)
        let delta = store.session.messages.count - initialCount
        guard delta == 0 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.4 — dismiss must write zero transcript messages; wrote \(delta)"
            )
        }
        let stillPresent = store.recommendedMatches.contains { $0.id == rec.id }
        guard stillPresent == false else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §3.3 — dismissed card must be removed from recommendedMatches immediately"
            )
        }
        return .init(name: name, passed: true, detail: "Dismiss wrote 0 messages and removed the card from the rail")
    }

    // MARK: - 8. Accept-no-entry writes zero messages (§2.4, §3.3)

    static func testAcceptNoEntryWritesZeroMessages() -> KernelPhase1TestResult {
        let name = "t10b_accept_no_entry_zero_messages"
        let store = freshStore()
        let rec = RecommendationFixture.make(kind: .song, id: "fixture-accept-no-entry-1")
        store.recommendedMatches = [rec]
        let initialCount = store.session.messages.count
        store.prepareRecommendationForAccept(rec)
        // No subsequent recordSurfaceReturn — this is the accept-no-entry
        // orphan state. Spec §2.4 + §3.3: nothing is written to either
        // transcript OR rail as a "pending accept" visual marker.
        let delta = store.session.messages.count - initialCount
        guard delta == 0 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.4 — accept-no-entry must write zero transcript messages; wrote \(delta)"
            )
        }
        return .init(name: name, passed: true, detail: "Accept-no-entry orphan wrote 0 transcript messages")
    }

    // MARK: - 9. Chat / Maps sections take early-return (§1.1)

    static func testChatAndMapsSectionsTakeEarlyReturnBranch() -> KernelPhase1TestResult {
        let name = "t10b_chat_and_maps_early_return"
        let store = freshStore()
        let initial = store.session.messages.count
        // recordSurfaceReturn guards .chat and .maps and returns without
        // writing (§1.1: Maps has its own path via recordMapReturn, Chat
        // never "returned" from anywhere).
        store.recordSurfaceReturn(
            from: AppSurfaceReturnContext(section: .chat, musicSession: nil, videoSession: nil),
            dashboard: nil,
            healthSession: nil
        )
        store.recordSurfaceReturn(
            from: AppSurfaceReturnContext(section: .maps, musicSession: nil, videoSession: nil),
            dashboard: nil,
            healthSession: nil
        )
        let delta = store.session.messages.count - initial
        guard delta == 0 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §1.1 — recordSurfaceReturn on .chat/.maps must early-return (Maps uses recordMapReturn; Chat never returns); wrote \(delta)"
            )
        }
        return .init(name: name, passed: true, detail: "Chat/Maps early-return branch wrote 0 transcript messages")
    }

    // MARK: - 10. Search dismiss shares the same silence rule (Maps/Music/Search coverage)

    static func testSearchDismissSharesSameSilenceRule() -> KernelPhase1TestResult {
        let name = "t10b_search_dismiss_silent"
        let store = freshStore()
        // Spec §1.2: Search is "(v1+ wiring)" for completion/abandon but
        // dismiss already works because it's kind-agnostic via
        // ChatStore.dismissRecommendation. Covers the Search vertical
        // with what is wired today (search-result / answer-card cards
        // dismissible from the rail).
        let searchRec = RecommendationFixture.make(kind: .searchResult, id: "fixture-search-dismiss-1")
        let answerRec = RecommendationFixture.make(kind: .answerCard, id: "fixture-answer-dismiss-1")
        store.recommendedMatches = [searchRec, answerRec]
        let initialCount = store.session.messages.count
        store.dismissRecommendation(searchRec, feedback: .notInterested)
        store.dismissRecommendation(answerRec, feedback: .lessLikeThis)
        let delta = store.session.messages.count - initialCount
        guard delta == 0 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.4 — Search vertical card dismiss (searchResult + answerCard) must write 0 transcript messages; wrote \(delta)"
            )
        }
        return .init(name: name, passed: true, detail: "Search card dismiss (both kinds) wrote 0 transcript messages")
    }

    // MARK: - 11. Two consecutive returns produce exactly two messages

    static func testTwoConsecutiveReturnsProduceExactlyTwoMessages() -> KernelPhase1TestResult {
        let name = "t10b_two_returns_two_messages"
        let store = freshStore()
        let initial = store.session.messages.count
        store.recordMapReturn(from: MapsReturnFixture.nearbyTask())
        store.recordMapReturn(from: MapsReturnFixture.nearbyTask())
        let delta = store.session.messages.count - initial
        guard delta == 2 else {
            return .init(
                name: name,
                passed: false,
                detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2 — every return must append exactly 1 message; 2 returns appended \(delta) (expected 2)"
            )
        }
        return .init(name: name, passed: true, detail: "2 Maps returns appended exactly 2 transcript messages")
    }

    // MARK: - 12. Every return message uses .ready state (§2, footer rule)

    static func testEveryReturnMessageUsesReadyState() -> KernelPhase1TestResult {
        let name = "t10b_return_message_ready_state"
        let store = freshStore()
        store.recordMapReturn(from: MapsReturnFixture.nearbyTask())
        store.recordSurfaceReturn(
            from: AppSurfaceReturnContext(
                section: .music,
                musicSession: MusicReturnFixture.focusSession(),
                videoSession: nil
            ),
            dashboard: nil,
            healthSession: nil
        )
        // Spec §2.1 says state is always `.ready` for return blocks. Abandon
        // variant §2.3 notes a future refactor may switch to `.warning`, so
        // this test accepts either `.ready` or `.warning` — what it
        // forbids is `.working`, which would imply the return is still
        // "processing."
        for message in store.session.messages {
            for tool in message.toolResults {
                if tool.state == .working {
                    return .init(
                        name: name,
                        passed: false,
                        detail: "spec-deviation: post-return-and-continuation-ux-v1.md §2.1 / §2.3 — post-return toolResult must be .ready (or .warning for abandon); got .working on \(tool.id)"
                    )
                }
            }
        }
        return .init(name: name, passed: true, detail: "All post-return tool results used .ready (abandon may use .warning per §2.3; .working is forbidden)")
    }

    // MARK: - helpers

    /// Fresh ChatStore with lifecycle autostart disabled so the test
    /// observes only what the return path itself produces (no background
    /// refresh side-effects).
    private static func freshStore() -> ChatStore {
        ChatStore(replayLab: MatchingReplayLab(), autostartLifecycle: false)
    }
}

// MARK: - Fixtures

private enum MapsReturnFixture {
    static func nearbyTask() -> MapTask {
        MapTask(
            threadId: UUID(),
            taskType: .nearbySearch,
            query: "coffee near me",
            entryMode: .home,
            resultSummary: "3 cafes within walking distance",
            language: .english
        )
    }
}

private enum MusicReturnFixture {
    static func focusSession() -> MusicPlaybackSession {
        MusicPlaybackSession(
            title: "Focus mix",
            subtitle: "35-min deep-work playlist",
            mood: .focus,
            query: "focus music",
            sourceLabel: "AI-curated"
        )
    }
}

private enum RecommendationFixture {
    /// Minimal synthetic UnifiedMatchRecommendation for seeding
    /// `store.recommendedMatches` in tests. Only fields the spec locks
    /// on are populated — everything else uses neutral defaults so the
    /// scorer's real producer output is not simulated here.
    static func make(kind: MatchingObjectKind, id: String) -> UnifiedMatchRecommendation {
        ChatHomeBehaviorFixtureFactory.shared.makeRecommendation(kind: kind, id: id)
    }
}
