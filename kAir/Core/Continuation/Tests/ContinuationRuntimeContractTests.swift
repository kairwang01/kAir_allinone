//
//  ContinuationRuntimeContractTests.swift
//  kAir
//
//  T13 — Continuation Runtime v1 contract tests.
//  Normative spec: Contracts/UX/continuation-runtime-v1.md §18
//
//  This suite does pure-value contract validation: it builds
//  ExecutionReturnEvent / ContinuationContext fixtures, calls
//  DefaultContinuationRuntime, and asserts §7.1, §11.2, §15.2 rules
//  plus cardinality witnesses for §5.2, §5.5, §11.1 / §16.1.
//
//  Failure format (v1 frozen):
//    spec-deviation: continuation-runtime-v1.md §X — <what failed>
//
//  No ChatStore, no UI, no flag gate. This is a contract lock, not a
//  rollout experiment — it runs at every startup alongside T10–T12b.
//

import Foundation

public struct ContinuationRuntimeContractReport {
    public let results: [KernelPhase1TestResult]
    public var passedCount: Int { results.filter(\.passed).count }
    public var failedCount: Int { results.filter { !$0.passed }.count }
}

public enum ContinuationRuntimeContractTests {

    public static func runAll() -> ContinuationRuntimeContractReport {
        let results: [KernelPhase1TestResult] = [
            // §7 — outcome behavior
            testCompletionEmitsSummaryAndNeverDefaultsToNewTask(),
            testAbandonNeverFabricatesEvidence(),
            testDismissSuppressesSourceRecommendation(),
            testAcceptNoEntryNeverMapsToCompletion(),
            // §15 — safe fallback
            testInvalidInputReturnsSafeFallback(),
            // §6.1 / §16.1 — transcript block set
            testTranscriptBlockTypesFrozenAtThree(),
            // §11.2 — refresh default table
            testRefreshModeDefaultTableHoldsForAllOutcomes(),
            // §13.1 / §13.3 — no payload-to-prose bypass
            testVerticalsCannotBypassRuntimeViaPayloadProse(),
            // §5.2 / §5.5 / §11.1 / §16.1 — cardinality witnesses
            testContinuationOutcomeEnumCardinalityIsFour(),
            testContinuationStateEnumCardinalityIsThree(),
            testRefreshModeEnumCardinalityIsFive(),
            // §15.2 — safe fallback is a single constant
            testSafeFallbackIsIdempotentConstant(),
        ]
        return ContinuationRuntimeContractReport(results: results)
    }

    // MARK: - §7.1.A

    static func testCompletionEmitsSummaryAndNeverDefaultsToNewTask() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()
        let event = ExecutionReturnEvent(
            sourceSurface: .maps,
            sourceRequestId: "req-completion",
            sourceRecommendationId: "rec-1",
            outcome: .completion,
            payload: ReturnPayload(
                taskFamily: "navigation",
                objectType: .route,
                title: "Home → Office",
                structuredEvidence: [
                    ReturnEvidenceItem(key: "eta", value: "22m"),
                    ReturnEvidenceItem(key: "distance", value: "12.4km"),
                ]
            ),
            returnedAt: .fixture
        )
        let ctx = ContinuationContext(
            threadId: "thread-1",
            latestObjectTypes: [.route]
        )
        let result = runtime.handleReturn(event: event, context: ctx)

        let hasSummary = result.transcriptInsertions.contains { event in
            if case .systemSummary = event { return true }
            return false
        }
        let isNewTask = result.continuationState == .newTask
        let validRefresh = result.recommendationRefreshPlan.mode == .refreshSameFamily
            || result.recommendationRefreshPlan.mode == .refreshAdjacentFamily

        let passed = hasSummary && !isNewTask && validRefresh
        let message = passed
            ? "completion emits summary, avoids newTask, refreshes same/adjacent family"
            : "spec-deviation: continuation-runtime-v1.md §7.1.A — completion must emit summary, must not default to newTask, must refresh same or adjacent family"
        return KernelPhase1TestResult(
            name: "testCompletionEmitsSummaryAndNeverDefaultsToNewTask",
            passed: passed,
            message: message
        )
    }

    // MARK: - §7.1.B / §8.2

    static func testAbandonNeverFabricatesEvidence() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()
        let event = ExecutionReturnEvent(
            sourceSurface: .music,
            sourceRequestId: "req-abandon",
            sourceRecommendationId: nil,
            outcome: .abandon,
            payload: nil,
            returnedAt: .fixture
        )
        let ctx = ContinuationContext(threadId: "thread-2")
        let result = runtime.handleReturn(event: event, context: ctx)

        let hasSummary = result.transcriptInsertions.contains { event in
            if case .systemSummary = event { return true }
            return false
        }
        let hasEvidence = result.transcriptInsertions.contains { event in
            if case .systemEvidence = event { return true }
            return false
        }

        let passed = hasSummary && !hasEvidence
        let message = passed
            ? "abandon emits summary without fabricating evidence"
            : "spec-deviation: continuation-runtime-v1.md §7.1.B / §8.2 — abandon without structured evidence must not emit systemEvidence"
        return KernelPhase1TestResult(
            name: "testAbandonNeverFabricatesEvidence",
            passed: passed,
            message: message
        )
    }

    // MARK: - §7.1.C / §12.2

    static func testDismissSuppressesSourceRecommendation() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()
        let event = ExecutionReturnEvent(
            sourceSurface: .search,
            sourceRequestId: "req-dismiss",
            sourceRecommendationId: "rec-42",
            outcome: .dismiss,
            payload: nil,
            returnedAt: .fixture
        )
        let ctx = ContinuationContext(
            threadId: "thread-3",
            currentRecommendationIds: ["rec-42", "rec-43", "rec-44"]
        )
        let result = runtime.handleReturn(event: event, context: ctx)

        let suppressed = result.recommendationRefreshPlan.suppressSourceRecommendationId == "rec-42"
        let notPreserved = result.recommendationRefreshPlan.preserveAcceptedCard == false

        let passed = suppressed && notPreserved
        let message = passed
            ? "dismiss suppresses source rec and does not preserve it"
            : "spec-deviation: continuation-runtime-v1.md §7.1.C / §12.2 — dismiss must suppress the source recommendation and must not preserve it"
        return KernelPhase1TestResult(
            name: "testDismissSuppressesSourceRecommendation",
            passed: passed,
            message: message
        )
    }

    // MARK: - §7.1.D

    static func testAcceptNoEntryNeverMapsToCompletion() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()
        let event = ExecutionReturnEvent(
            sourceSurface: .maps,
            sourceRequestId: "req-accept-noentry",
            sourceRecommendationId: "rec-7",
            outcome: .acceptNoEntry,
            payload: nil,
            returnedAt: .fixture
        )
        let ctx = ContinuationContext(threadId: "thread-4")
        let result = runtime.handleReturn(event: event, context: ctx)

        let transcriptCount = result.transcriptInsertions.count
        let hasEvidence = result.transcriptInsertions.contains { event in
            if case .systemEvidence = event { return true }
            return false
        }
        // Continuation v1 has no dedicated "completion" state — what
        // §7.1.D forbids is behaviorally emitting evidence or a summary
        // that reads as success. We lock: <=1 insertion, no evidence,
        // refresh mode cannot be .refreshNewTask (which would imply
        // the task loop closed like a completion).
        let refreshNotNewTask = result.recommendationRefreshPlan.mode != .refreshNewTask

        let passed = transcriptCount <= 1 && !hasEvidence && refreshNotNewTask
        let message = passed
            ? "acceptNoEntry stays lightweight and never reads as completion"
            : "spec-deviation: continuation-runtime-v1.md §7.1.D — acceptNoEntry must be at most one lightweight summary, must not emit evidence, must not close the task loop like completion"
        return KernelPhase1TestResult(
            name: "testAcceptNoEntryNeverMapsToCompletion",
            passed: passed,
            message: message
        )
    }

    // MARK: - §15.1 / §15.2

    static func testInvalidInputReturnsSafeFallback() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()
        let event = ExecutionReturnEvent(
            sourceSurface: .chat,
            sourceRequestId: "", // invalid
            sourceRecommendationId: nil,
            outcome: .completion,
            payload: nil,
            returnedAt: .fixture
        )
        let ctx = ContinuationContext(threadId: "") // invalid
        let result = runtime.handleReturn(event: event, context: ctx)

        let passed = result == .safeFallback
        let message = passed
            ? "invalid input returns the single safeFallback constant"
            : "spec-deviation: continuation-runtime-v1.md §15.2 — invalid input must return ContinuationResult.safeFallback"
        return KernelPhase1TestResult(
            name: "testInvalidInputReturnsSafeFallback",
            passed: passed,
            message: message
        )
    }

    // MARK: - §6.1 / §16.1

    static func testTranscriptBlockTypesFrozenAtThree() -> KernelPhase1TestResult {
        // Compile-time exhaustiveness witness: this switch has no
        // default; adding a 4th case to ChatContinuationEvent breaks
        // the build rather than silently expanding the v1 block set.
        func witness(_ event: ChatContinuationEvent) -> Int {
            switch event {
            case .systemSummary: return 0
            case .systemEvidence: return 1
            case .nextStepPrompt: return 2
            }
        }
        let summary = ChatContinuationEvent.systemSummary(
            ContinuationSummaryBlock(
                sourceSurface: .chat,
                outcome: .completion,
                summaryText: "s",
                sourceRequestId: "r"
            )
        )
        let evidence = ChatContinuationEvent.systemEvidence(
            ContinuationEvidenceBlock(items: [])
        )
        let prompt = ChatContinuationEvent.nextStepPrompt(
            ContinuationPromptBlock(prompt: "p")
        )
        let indices = [witness(summary), witness(evidence), witness(prompt)]
        let passed = indices == [0, 1, 2]
        let message = passed
            ? "ChatContinuationEvent frozen at 3 cases"
            : "spec-deviation: continuation-runtime-v1.md §6.1 / §16.1 — transcript block types must stay at 3"
        return KernelPhase1TestResult(
            name: "testTranscriptBlockTypesFrozenAtThree",
            passed: passed,
            message: message
        )
    }

    // MARK: - §11.2

    static func testRefreshModeDefaultTableHoldsForAllOutcomes() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()

        // completion → refreshSameFamily (or refreshAdjacentFamily),
        // preserveAcceptedCard=true when sourceRecId present, no suppression.
        let completion = runtime.handleReturn(
            event: ExecutionReturnEvent(
                sourceSurface: .maps,
                sourceRequestId: "req-c",
                sourceRecommendationId: "rec-c",
                outcome: .completion,
                payload: nil,
                returnedAt: .fixture
            ),
            context: ContinuationContext(threadId: "t")
        )
        let completionOK = (
            completion.recommendationRefreshPlan.mode == .refreshSameFamily
            || completion.recommendationRefreshPlan.mode == .refreshAdjacentFamily
        )
            && completion.recommendationRefreshPlan.preserveAcceptedCard == true
            && completion.recommendationRefreshPlan.suppressSourceRecommendationId == nil

        // abandon → refreshSameFamily, no suppression.
        let abandon = runtime.handleReturn(
            event: ExecutionReturnEvent(
                sourceSurface: .music,
                sourceRequestId: "req-a",
                sourceRecommendationId: nil,
                outcome: .abandon,
                payload: nil,
                returnedAt: .fixture
            ),
            context: ContinuationContext(threadId: "t")
        )
        let abandonOK = abandon.recommendationRefreshPlan.mode == .refreshSameFamily
            && abandon.recommendationRefreshPlan.suppressSourceRecommendationId == nil

        // dismiss → refreshAdjacentFamily or clear, preserve=false,
        // suppress=<sourceRecId>.
        let dismiss = runtime.handleReturn(
            event: ExecutionReturnEvent(
                sourceSurface: .search,
                sourceRequestId: "req-d",
                sourceRecommendationId: "rec-d",
                outcome: .dismiss,
                payload: nil,
                returnedAt: .fixture
            ),
            context: ContinuationContext(
                threadId: "t",
                currentRecommendationIds: ["rec-d", "rec-e", "rec-f"]
            )
        )
        let dismissOK = (
            dismiss.recommendationRefreshPlan.mode == .refreshAdjacentFamily
            || dismiss.recommendationRefreshPlan.mode == .clear
        )
            && dismiss.recommendationRefreshPlan.preserveAcceptedCard == false
            && dismiss.recommendationRefreshPlan.suppressSourceRecommendationId == "rec-d"

        // acceptNoEntry → preserve or refreshSameFamily, no suppression.
        let accept = runtime.handleReturn(
            event: ExecutionReturnEvent(
                sourceSurface: .maps,
                sourceRequestId: "req-n",
                sourceRecommendationId: "rec-n",
                outcome: .acceptNoEntry,
                payload: nil,
                returnedAt: .fixture
            ),
            context: ContinuationContext(threadId: "t")
        )
        let acceptOK = (
            accept.recommendationRefreshPlan.mode == .preserve
            || accept.recommendationRefreshPlan.mode == .refreshSameFamily
        )
            && accept.recommendationRefreshPlan.suppressSourceRecommendationId == nil

        let passed = completionOK && abandonOK && dismissOK && acceptOK
        let message = passed
            ? "refresh default table holds for all four outcomes"
            : "spec-deviation: continuation-runtime-v1.md §11.2 — outcome-to-refresh default table violated (completion=\(completionOK), abandon=\(abandonOK), dismiss=\(dismissOK), acceptNoEntry=\(acceptOK))"
        return KernelPhase1TestResult(
            name: "testRefreshModeDefaultTableHoldsForAllOutcomes",
            passed: passed,
            message: message
        )
    }

    // MARK: - §13.1 / §13.3

    static func testVerticalsCannotBypassRuntimeViaPayloadProse() -> KernelPhase1TestResult {
        let runtime = DefaultContinuationRuntime()
        let forbiddenMarker = "FORBIDDEN_BYPASS_MARKER_XYZ"
        let event = ExecutionReturnEvent(
            sourceSurface: .maps,
            sourceRequestId: "req-bypass",
            sourceRecommendationId: "rec-b",
            outcome: .completion,
            payload: ReturnPayload(
                taskFamily: "navigation",
                objectType: .route,
                title: forbiddenMarker,
                subtitle: forbiddenMarker,
                structuredEvidence: [
                    ReturnEvidenceItem(key: "note", value: forbiddenMarker)
                ],
                downstreamValueHint: forbiddenMarker
            ),
            returnedAt: .fixture
        )
        let ctx = ContinuationContext(threadId: "t")
        let result = runtime.handleReturn(event: event, context: ctx)

        // The runtime is allowed to pass structuredEvidence items
        // through as structured data (§8.2). It is NOT allowed to echo
        // payload strings into the summary text or the prompt text,
        // because those are prose surfaces owned by the runtime
        // (§13.1, §13.3).
        let summaryContainsMarker = result.transcriptInsertions.contains { event in
            if case let .systemSummary(block) = event {
                return block.summaryText.contains(forbiddenMarker)
            }
            return false
        }
        let promptContainsMarker = result.transcriptInsertions.contains { event in
            if case let .nextStepPrompt(block) = event {
                return block.prompt.contains(forbiddenMarker)
            }
            return false
        }

        let passed = !summaryContainsMarker && !promptContainsMarker
        let message = passed
            ? "runtime-authored prose never echoes payload strings"
            : "spec-deviation: continuation-runtime-v1.md §13.1 / §13.3 — runtime must author summary and prompt prose; verticals cannot inject text via payload"
        return KernelPhase1TestResult(
            name: "testVerticalsCannotBypassRuntimeViaPayloadProse",
            passed: passed,
            message: message
        )
    }

    // MARK: - §5.2 / §16.1

    static func testContinuationOutcomeEnumCardinalityIsFour() -> KernelPhase1TestResult {
        let count = ContinuationOutcome.allCases.count
        let passed = count == 4
        let message = passed
            ? "ContinuationOutcome cardinality is 4"
            : "spec-deviation: continuation-runtime-v1.md §5.2 / §16.1 — ContinuationOutcome must stay at 4 cases, saw \(count)"
        return KernelPhase1TestResult(
            name: "testContinuationOutcomeEnumCardinalityIsFour",
            passed: passed,
            message: message
        )
    }

    // MARK: - §5.5 / §16.1

    static func testContinuationStateEnumCardinalityIsThree() -> KernelPhase1TestResult {
        let count = ContinuationState.allCases.count
        let passed = count == 3
        let message = passed
            ? "ContinuationState cardinality is 3"
            : "spec-deviation: continuation-runtime-v1.md §5.5 / §16.1 — ContinuationState must stay at 3 cases, saw \(count)"
        return KernelPhase1TestResult(
            name: "testContinuationStateEnumCardinalityIsThree",
            passed: passed,
            message: message
        )
    }

    // MARK: - §11.1 / §16.1

    static func testRefreshModeEnumCardinalityIsFive() -> KernelPhase1TestResult {
        let count = RefreshMode.allCases.count
        let passed = count == 5
        let message = passed
            ? "RefreshMode cardinality is 5"
            : "spec-deviation: continuation-runtime-v1.md §11.1 / §16.1 — RefreshMode must stay at 5 cases, saw \(count)"
        return KernelPhase1TestResult(
            name: "testRefreshModeEnumCardinalityIsFive",
            passed: passed,
            message: message
        )
    }

    // MARK: - §15.2

    static func testSafeFallbackIsIdempotentConstant() -> KernelPhase1TestResult {
        let a = ContinuationResult.safeFallback
        let b = ContinuationResult.safeFallback

        let equal = a == b
        let shape = a.transcriptInsertions.isEmpty
            && a.recommendationRefreshPlan.mode == .preserve
            && a.recommendationRefreshPlan.preserveAcceptedCard == false
            && a.recommendationRefreshPlan.suppressSourceRecommendationId == nil
            && a.recommendationRefreshPlan.preferredTaskFamily == nil
            && a.continuationState == .sameTask

        let passed = equal && shape
        let message = passed
            ? "ContinuationResult.safeFallback is a single frozen value"
            : "spec-deviation: continuation-runtime-v1.md §15.2 — safeFallback must be a single constant with mode=preserve, empty transcript, state=sameTask"
        return KernelPhase1TestResult(
            name: "testSafeFallbackIsIdempotentConstant",
            passed: passed,
            message: message
        )
    }
}

// MARK: - Fixtures

private extension Date {
    /// A fixed date so tests are deterministic and don't interact
    /// with system clock drift. Chosen arbitrarily; contract does not
    /// depend on specific timestamp values.
    static let fixture = Date(timeIntervalSince1970: 1_800_000_000)
}
