//
//  KernelPhase1ConsistencyTests.swift
//  kAir
//
//  P0 consistency tests for the Phase-1 super-kernel matching core.
//  Verifies that runtime and replay share one policy source, that canonical
//  replay artifacts serialize cleanly, that every scored candidate emits a
//  structured contribution, and that replay summary and residual ledger
//  counts are internally consistent.
//

import Foundation

struct KernelPhase1TestResult {
    let name: String
    let passed: Bool
    let detail: String

    var line: String {
        let mark = passed ? "PASS" : "FAIL"
        return "[\(mark)] \(name) — \(detail)"
    }
}

struct KernelPhase1ConsistencyTestReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum KernelPhase1ConsistencyTests {
    static func runAll() -> KernelPhase1ConsistencyTestReport {
        let results: [KernelPhase1TestResult] = [
            testPolicyVersionConsistency(),
            testLedgerSerializationRoundtrip(),
            testScoreContributionFieldsEmitted(),
            testHypothesisRegistryShippedAndClosed(),
            testReplayArtifactConsistency(),
        ]
        return KernelPhase1ConsistencyTestReport(results: results)
    }

    // MARK: - Test 1: policy version consistency

    static func testPolicyVersionConsistency() -> KernelPhase1TestResult {
        let runtime = UnifiedMatchingEngine()
        let replay = MatchingReplayStrategy.candidate.engine

        let runtimePolicy = runtime.policyVersion
        let replayPolicy = replay.policyVersion

        guard runtimePolicy == replayPolicy else {
            return KernelPhase1TestResult(
                name: "policy_version_consistency",
                passed: false,
                detail: "runtime=\(runtimePolicy.policyVersion) replay=\(replayPolicy.policyVersion)"
            )
        }

        guard runtime.scoringPolicy.versionID == replay.scoringPolicy.versionID else {
            return KernelPhase1TestResult(
                name: "policy_version_consistency",
                passed: false,
                detail: "scorerID mismatch runtime=\(runtime.scoringPolicy.versionID) replay=\(replay.scoringPolicy.versionID)"
            )
        }

        guard runtimePolicy.policyVersion == MatchingPolicyVersion.current.policyVersion else {
            return KernelPhase1TestResult(
                name: "policy_version_consistency",
                passed: false,
                detail: "runtime does not equal MatchingPolicyVersion.current"
            )
        }

        return KernelPhase1TestResult(
            name: "policy_version_consistency",
            passed: true,
            detail: "policyVersion=\(runtimePolicy.policyVersion) scorer=\(runtime.scoringPolicy.versionID)"
        )
    }

    // MARK: - Test 2: ledger serialization roundtrip

    static func testLedgerSerializationRoundtrip() -> KernelPhase1TestResult {
        let entry = LiveResidualLedgerEntry(
            caseId: "fixture-case-1",
            sessionId: UUID().uuidString,
            objectType: "place",
            surface: "maps",
            expectedCandidateId: "expected-A",
            top1CandidateId: "top1-B",
            expectedRank: 2,
            isInTopK: true,
            isDirectSlot: false,
            residualType: .nearMiss,
            rootCause: .scorer,
            dominantBucket: "prompt_lexical",
            scoreBreakdownExpected: ScoreContributionBreakdown(
                globalEligibility: 0.9,
                domainUtility: 0.7,
                nextStepValue: 0.6,
                explorationBoost: 0.1,
                retrievalLift: 0.2,
                promptDirectnessBonus: 0.05,
                diversityPenalty: 0,
                promptLexical: 0.3,
                contextLexical: 0,
                phrase: 0.1,
                suppression: 0,
                finalScore: 0.75,
                policyVersion: MatchingPolicyVersion.current.policyVersion
            ),
            scoreBreakdownTop1: nil,
            policyVersion: MatchingPolicyVersion.current.policyVersion
        )
        let ledger = LiveResidualLedger(
            baselineArtifactVersion: MatchingKernelBaseline.current.artifactVersion,
            policyVersion: .current,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            entries: [entry]
        )

        do {
            let data = try ledger.encodeJSONData()
            let decoded = try LiveResidualLedger.decode(from: data)
            guard decoded == ledger else {
                return KernelPhase1TestResult(
                    name: "ledger_serialization_roundtrip",
                    passed: false,
                    detail: "decoded ledger != original"
                )
            }
            return KernelPhase1TestResult(
                name: "ledger_serialization_roundtrip",
                passed: true,
                detail: "roundtripped \(ledger.entries.count) entry, size=\(data.count) bytes"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "ledger_serialization_roundtrip",
                passed: false,
                detail: "error: \(error)"
            )
        }
    }

    // MARK: - Test 3: every scored candidate emits a contribution

    static func testScoreContributionFieldsEmitted() -> KernelPhase1TestResult {
        let snapshot = makeTrivialSnapshot()
        let engine = UnifiedMatchingEngine()
        let evaluation = engine.evaluate(snapshot: snapshot, limit: 5)

        guard evaluation.scoredCandidates.isEmpty == false else {
            return KernelPhase1TestResult(
                name: "score_contribution_fields_emitted",
                passed: false,
                detail: "engine returned zero scored candidates for fixture"
            )
        }

        let expectedPolicy = MatchingPolicyVersion.current.scorerBaselineID
        for scored in evaluation.scoredCandidates {
            let c = scored.breakdown.contribution
            guard c.policyVersion == expectedPolicy else {
                return KernelPhase1TestResult(
                    name: "score_contribution_fields_emitted",
                    passed: false,
                    detail: "candidate \(scored.candidate.id) policy=\(c.policyVersion) expected=\(expectedPolicy)"
                )
            }
            guard c.finalScore == scored.breakdown.finalScore else {
                return KernelPhase1TestResult(
                    name: "score_contribution_fields_emitted",
                    passed: false,
                    detail: "contribution.finalScore mismatch for \(scored.candidate.id)"
                )
            }
            guard c.globalEligibility >= 0, c.domainUtility >= 0, c.nextStepValue >= 0 else {
                return KernelPhase1TestResult(
                    name: "score_contribution_fields_emitted",
                    passed: false,
                    detail: "negative component for \(scored.candidate.id)"
                )
            }
        }

        let anyWithPromptDirectness = evaluation.scoredCandidates.contains { scored in
            scored.breakdown.contribution.promptDirectnessBonus > 0 ||
            scored.breakdown.contribution.retrievalLift > 0
        }
        guard anyWithPromptDirectness else {
            return KernelPhase1TestResult(
                name: "score_contribution_fields_emitted",
                passed: false,
                detail: "no candidate emitted retrievalLift or promptDirectnessBonus > 0; shipped scorer should produce at least one"
            )
        }

        return KernelPhase1TestResult(
            name: "score_contribution_fields_emitted",
            passed: true,
            detail: "\(evaluation.scoredCandidates.count) candidates with full contribution"
        )
    }

    // MARK: - Test 4: hypothesis registry

    static func testHypothesisRegistryShippedAndClosed() -> KernelPhase1TestResult {
        guard MatchingHypothesisRegistry.shipped.isEmpty == false else {
            return KernelPhase1TestResult(
                name: "hypothesis_registry_shipped_and_closed",
                passed: false,
                detail: "registry has no shipped hypotheses"
            )
        }
        guard MatchingHypothesisRegistry.closed.isEmpty == false else {
            return KernelPhase1TestResult(
                name: "hypothesis_registry_shipped_and_closed",
                passed: false,
                detail: "registry has no closed hypotheses"
            )
        }
        guard MatchingHypothesisRegistry.hypothesis(withID: "prompt_directness_bonus")?.isShipped == true else {
            return KernelPhase1TestResult(
                name: "hypothesis_registry_shipped_and_closed",
                passed: false,
                detail: "prompt_directness_bonus must be shipped"
            )
        }
        guard MatchingHypothesisRegistry.hypothesis(withID: "context_lexical_patch")?.isClosed == true else {
            return KernelPhase1TestResult(
                name: "hypothesis_registry_shipped_and_closed",
                passed: false,
                detail: "context_lexical_patch must be closed"
            )
        }
        return KernelPhase1TestResult(
            name: "hypothesis_registry_shipped_and_closed",
            passed: true,
            detail: "shipped=\(MatchingHypothesisRegistry.shipped.count) closed=\(MatchingHypothesisRegistry.closed.count)"
        )
    }

    // MARK: - Test 5: replay summary and ledger are internally consistent

    static func testReplayArtifactConsistency() -> KernelPhase1TestResult {
        let scenarios = makeFixtureScenarios()
        let engine = MatchingReplayEngine()
        let bundle = engine.buildArtifactBundle(
            scenarios: scenarios,
            limit: 5,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let ledger = bundle.ledger
        let summary = bundle.summary

        guard summary.policyVersion.policyVersion == MatchingPolicyVersion.current.policyVersion else {
            return KernelPhase1TestResult(
                name: "replay_artifact_consistency",
                passed: false,
                detail: "summary policyVersion mismatch"
            )
        }

        guard ledger.entries.count == scenarios.count else {
            return KernelPhase1TestResult(
                name: "replay_artifact_consistency",
                passed: false,
                detail: "ledger entries=\(ledger.entries.count) scenarios=\(scenarios.count)"
            )
        }

        guard summary.aggregate.scenarioCount == scenarios.count else {
            return KernelPhase1TestResult(
                name: "replay_artifact_consistency",
                passed: false,
                detail: "summary scenarioCount=\(summary.aggregate.scenarioCount) scenarios=\(scenarios.count)"
            )
        }

        let internalTotal = ledger.nearMissCount + ledger.candidateMissCount + ledger.weakTraceCount + ledger.recoveredCount + ledger.directMatchCount
        guard internalTotal == ledger.entries.count else {
            return KernelPhase1TestResult(
                name: "replay_artifact_consistency",
                passed: false,
                detail: "residual bucket sum \(internalTotal) != entries \(ledger.entries.count)"
            )
        }

        do {
            let summaryData = try summary.encodeJSONData()
            let decodedSummary = try MatchingReplaySummary.decode(from: summaryData)
            guard decodedSummary.policyVersion.policyVersion == summary.policyVersion.policyVersion else {
                return KernelPhase1TestResult(
                    name: "replay_artifact_consistency",
                    passed: false,
                    detail: "summary roundtrip policyVersion mismatch"
                )
            }
            let ledgerData = try ledger.encodeJSONData()
            let decodedLedger = try LiveResidualLedger.decode(from: ledgerData)
            guard decodedLedger.entries.count == ledger.entries.count else {
                return KernelPhase1TestResult(
                    name: "replay_artifact_consistency",
                    passed: false,
                    detail: "ledger roundtrip entry count mismatch"
                )
            }
        } catch {
            return KernelPhase1TestResult(
                name: "replay_artifact_consistency",
                passed: false,
                detail: "artifact serialization error: \(error)"
            )
        }

        return KernelPhase1TestResult(
            name: "replay_artifact_consistency",
            passed: true,
            detail: "scenarios=\(scenarios.count) entries=\(ledger.entries.count) direct=\(ledger.directMatchCount) near=\(ledger.nearMissCount) cand=\(ledger.candidateMissCount) weak=\(ledger.weakTraceCount)"
        )
    }

    // MARK: - Fixture helpers

    private static func makeTrivialSnapshot() -> MatchingReplaySnapshot {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = ChatSession(
            title: "Kernel P0 fixture",
            messages: [
                .user(text: "导航回家", timestamp: capturedAt.addingTimeInterval(-30)),
            ]
        )
        return MatchingReplaySnapshot(
            label: "kernel-p0-fixture-trivial",
            recentPrompt: "导航回家",
            capturedAt: capturedAt,
            session: session,
            healthAvailability: .ready,
            locationState: .precise,
            motionContext: .driving,
            activeSurface: .chat,
            returnContextState: nil,
            behaviorLog: []
        )
    }

    private static func makeFixtureScenarios() -> [MatchingReplayScenario] {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let blueprints: [(String, String, AppSection, MatchingMotionContext)] = [
            ("kernel-p0-commute", "导航回家", .chat, .driving),
            ("kernel-p0-music-focus", "放一点专注音乐", .chat, .stationary),
            ("kernel-p0-local-dinner", "今晚附近吃什么", .chat, .stationary),
        ]
        return blueprints.map { label, prompt, surface, motion in
            let session = ChatSession(
                title: label,
                messages: [.user(text: prompt, timestamp: capturedAt.addingTimeInterval(-45))]
            )
            let snapshot = MatchingReplaySnapshot(
                label: label,
                recentPrompt: prompt,
                capturedAt: capturedAt,
                session: session,
                healthAvailability: .ready,
                locationState: .precise,
                motionContext: motion,
                activeSurface: surface,
                returnContextState: nil,
                behaviorLog: []
            )
            return MatchingReplayScenario(
                label: label,
                snapshot: snapshot,
                recentEventsWindow: [],
                groundTruthEvents: [],
                createdAt: capturedAt
            )
        }
    }
}
