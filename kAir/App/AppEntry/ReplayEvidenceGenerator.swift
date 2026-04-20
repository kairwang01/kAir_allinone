//
//  ReplayEvidenceGenerator.swift
//  kAir
//

import Foundation

@MainActor
struct ReplayEvidenceGenerator {
    static func runAndPrintEvidence(lab: MatchingReplayLab) {
        print("================= REPLAY EVIDENCE START =================")
        print("Baseline Artifact: \(MatchingKernelBaseline.current.artifactVersion)")
        print("Policy Version: \(MatchingKernelBaseline.current.policyVersion)")
        
        let now = Date()
        
        // Scenario 1: Dining (Positive)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Dining Path",
                recentPrompt: "我想吃晚餐",
                capturedAt: now,
                session: ChatSession(title: "Dining", messages: []),
                healthAvailability: .ready,
                locationState: .precise,
                motionContext: .stationary,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        // Click -> Accept -> Completion
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .click, subject: .recommendation, candidateID: "rec_dining_1", objectKind: .place, surface: .maps, rawText: nil, tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.2, completionScore: 0, wasSuccessful: true)))
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .accept, subject: .recommendation, candidateID: "rec_dining_1", objectKind: .place, surface: .maps, rawText: "我想吃晚餐", tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.2, completionScore: 0, wasSuccessful: true)))
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .completion, subject: .surface, candidateID: "rec_dining_1", objectKind: .place, surface: .maps, rawText: nil, tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.8, completionScore: 0.9, wasSuccessful: true)))
        
        // Scenario 2: Commute (Positive)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Commute Path",
                recentPrompt: "导航回家",
                capturedAt: now,
                session: ChatSession(title: "Commute", messages: []),
                healthAvailability: .ready,
                locationState: .precise,
                motionContext: .driving,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .accept, subject: .recommendation, candidateID: "rec_commute_1", objectKind: .route, surface: .maps, rawText: "导航回家", tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.2, completionScore: 0, wasSuccessful: true)))
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .completion, subject: .surface, candidateID: "rec_commute_1", objectKind: .route, surface: .maps, rawText: nil, tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.9, completionScore: 1.0, wasSuccessful: true)))
        
        // Scenario 3: Music (Positive)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Music Path",
                recentPrompt: "播放专注音乐",
                capturedAt: now,
                session: ChatSession(title: "Music", messages: []),
                healthAvailability: .ready,
                locationState: .precise,
                motionContext: .stationary,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .accept, subject: .recommendation, candidateID: "rec_music_1", objectKind: .song, surface: .music, rawText: "播放专注音乐", tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.2, completionScore: 0, wasSuccessful: true)))
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .completion, subject: .surface, candidateID: "rec_music_1", objectKind: .song, surface: .music, rawText: nil, tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.5, completionScore: 0.8, wasSuccessful: true)))
        
        // Scenario 4: Search (Positive)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Search Path",
                recentPrompt: "Apple Store 营业到几点",
                capturedAt: now,
                session: ChatSession(title: "Search", messages: []),
                healthAvailability: .ready,
                locationState: .approximate,
                motionContext: .stationary,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .accept, subject: .recommendation, candidateID: "rec_search_1", objectKind: .searchResult, surface: .store, rawText: "Apple Store 营业到几点", tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.2, completionScore: 0, wasSuccessful: true)))
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .completion, subject: .surface, candidateID: "rec_search_1", objectKind: .searchResult, surface: .store, rawText: nil, tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.4, completionScore: 0.5, wasSuccessful: true)))
        
        // Scenario 5: Tool (Positive)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Tool Path",
                recentPrompt: "开始专注",
                capturedAt: now,
                session: ChatSession(title: "Tool", messages: []),
                healthAvailability: .ready,
                locationState: .approximate,
                motionContext: .stationary,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .accept, subject: .recommendation, candidateID: "rec_tool_1", objectKind: .toolEntry, surface: .health, rawText: "开始专注", tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.2, completionScore: 0, wasSuccessful: true)))
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .completion, subject: .surface, candidateID: "rec_tool_1", objectKind: .toolEntry, surface: .health, rawText: nil, tags: [], feedback: nil, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: 0.7, completionScore: 0.9, wasSuccessful: true)))
        
        // Scenario 6: Dismiss (Negative)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Dismiss Path",
                recentPrompt: "无聊",
                capturedAt: now,
                session: ChatSession(title: "Dismiss", messages: []),
                healthAvailability: .ready,
                locationState: .approximate,
                motionContext: .stationary,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .dismiss, subject: .recommendation, candidateID: "rec_dismiss_1", objectKind: .video, surface: .video, rawText: nil, tags: [], feedback: .dismiss, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: -0.1, completionScore: 0, wasSuccessful: false)))
        
        // Scenario 7: Explicit Negative Feedback (Negative)
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Explicit Negative Path",
                recentPrompt: "下班了",
                capturedAt: now,
                session: ChatSession(title: "Neg Feedback", messages: []),
                healthAvailability: .ready,
                locationState: .precise,
                motionContext: .driving,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        lab.recordOutcomeEvent(MatchingBehaviorEvent(stage: .dismiss, subject: .recommendation, candidateID: "rec_explicit_1", objectKind: .song, surface: .music, rawText: nil, tags: [], feedback: .notInterested, timestamp: now, outcome: MatchingOutcomeMetrics(downstreamValue: -0.28, completionScore: 0, wasSuccessful: false)))
        
        // Trigger finalization
        _ = lab.beginScenario(
            snapshot: MatchingReplaySnapshot(
                label: "Finalizer",
                recentPrompt: "",
                capturedAt: now,
                session: ChatSession(title: "Final", messages: []),
                healthAvailability: .ready,
                locationState: .approximate,
                motionContext: .stationary,
                activeSurface: .chat,
                returnContextState: nil,
                behaviorLog: []
            ),
            recentEventsWindow: []
        )
        
        guard let report = lab.latestBatchReport else {
            print("Failed to generate report")
            return
        }
        
        print("Evaluated Scenarios: \(report.evaluatedScenarioCount)")
        print("\n--- BATCH REPORT METRICS ---")
        print("Candidate Completed-path Hit Rate: \(report.aggregateMetrics.candidateCompletedPathHitRate)")
        print("Baseline Completed-path Hit Rate: \(report.aggregateMetrics.baselineCompletedPathHitRate)")
        print("Average Top-K Overlap: \(report.aggregateMetrics.averageTopKOverlap)")
        
        print("\n--- SLICE GROUPS ---")
        for group in report.sliceGroups {
            print("Dimension: \(group.dimension.rawValue)")
            for row in group.rows {
                print("  - \(row.title): \(row.scenarioCount) scenarios, Candidate Hit@K: \(row.candidateCompletedPathHitRate)")
            }
        }
        
        print("\n--- TOP IMPROVEMENTS / REGRESSIONS ---")
        for diff in report.topImprovements {
            print("Improvement: \(diff.label) (\(diff.primaryObjectKind?.rawValue ?? "nil")), Verdict: \(diff.verdict.rawValue)")
        }
        for diff in report.topRegressions {
            print("Regression: \(diff.label) (\(diff.primaryObjectKind?.rawValue ?? "nil")), Verdict: \(diff.verdict.rawValue)")
        }

        print("\n--- RUNTIME-DERIVED CORPUS ---")
        do {
            let bundle = try MatchingRuntimeReplayCorpusBuilder.build(now: now)
            let urls = try bundle.write(to: MatchingRuntimeReplayCorpusBuilder.defaultArtifactDirectory())

            print("Runtime Sessions: \(bundle.corpus.sessionCount)")
            print("Near-miss: \(bundle.ledger.nearMissCount)")
            print("Weak-trace: \(bundle.ledger.weakTraceCount)")
            print("Candidate-miss: \(bundle.ledger.candidateMissCount)")
            print("Direct-slot recovery: \(bundle.ledger.directSlotRecoveryCount)/\(max(bundle.ledger.sessionCount, 1))")
            print("Terminal outcomes: \(bundle.ledger.terminalOutcomeDistribution)")
            print("Next diagnosis target: \(bundle.ledger.nextDiagnosisTarget.rawValue)")
            print("Artifacts:")
            print("  baseline: \(urls.baseline.path)")
            print("  corpus: \(urls.corpus.path)")
            print("  ledger: \(urls.ledger.path)")
        } catch {
            print("Runtime corpus generation failed: \(error)")
        }
        
        print("================= REPLAY EVIDENCE END =================")
    }

    static func printSurfaceEntryChains(lab: MatchingReplayLab) {
        let chains = lab.surfaceEntryChains
        let summary = lab.surfaceEntryInvariantSummary
        print("================= SURFACE ENTRY CHAINS =================")
        print("Total chains: \(summary.totalChains)")
        print("Invariant 1 (requested→started paired): \(summary.requestedStartedPairedCount)/\(summary.totalChains) \(summary.requestedStartedPairedPassed ? "[PASS]" : "[FAIL]")")
        print("Invariant 2 (returned links by requestId): \(summary.returnedLinkedCount)/\(summary.totalChains) \(summary.returnedLinkedPassed ? "[PASS]" : "[FAIL]")")
        print("Invariant 3 (payload consistent): \(summary.payloadConsistentCount)/\(summary.totalChains) \(summary.payloadConsistentPassed ? "[PASS]" : "[FAIL]")")
        for chain in chains.prefix(20) {
            let recTag = chain.hasRecommendation ? "rec=\(chain.sourceRecommendationId ?? "?")" : "direct"
            let payloadTag = chain.returnPayload == nil ? "" : " payload=yes"
            print(
                "  [\(chain.invariants.allPassed ? "OK" : "!!")] \(chain.surfaceType.rawValue)/\(chain.entryIntent.rawValue) req=\(chain.requestId.prefix(16)) \(recTag) outcome=\(chain.terminalOutcome.rawValue)\(payloadTag)"
            )
        }
        if chains.count > 20 {
            print("  ... (+\(chains.count - 20) more)")
        }
        print("================= SURFACE ENTRY CHAINS END =============")
    }
}
