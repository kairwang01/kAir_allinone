//
//  DefaultContinuationRuntime.swift
//  kAir
//
//  v1 reference implementation of ContinuationRuntime.
//  Normative spec: Contracts/UX/continuation-runtime-v1.md §7, §8, §15
//
//  The implementation is split into three stages so no single function
//  owns more than one responsibility:
//
//    1. Validate input → early exit with .safeFallback on structural
//       invalidity (§15.1 / §15.2).
//    2. Classify + plan refresh via ContinuationClassifier and
//       RecommendationRefreshPlanner (§19 ownership split).
//    3. Build transcript blocks from outcome + payload per §7.1 and
//       §8.
//
//  Transcript prose is generated here, not echoed from payload —
//  §13.1: "Chat layer MUST NOT rewrite runtime outputs into vertical-
//  specific prose" and §13.3: surfaces only emit normalized data, they
//  do not decide transcript rules. The planner-less reading is: the
//  runtime owns wording.
//

import Foundation

public struct DefaultContinuationRuntime: ContinuationRuntime {
    private let classifier: ContinuationClassifier
    private let refreshPlanner: RecommendationRefreshPlanner

    public init(
        classifier: ContinuationClassifier = ContinuationClassifier(),
        refreshPlanner: RecommendationRefreshPlanner = RecommendationRefreshPlanner()
    ) {
        self.classifier = classifier
        self.refreshPlanner = refreshPlanner
    }

    public func handleReturn(
        event: ExecutionReturnEvent,
        context: ContinuationContext
    ) -> ContinuationResult {
        // §15.1 — structural validity guard. No crash, no UI damage.
        guard isStructurallyValid(event: event, context: context) else {
            return .safeFallback
        }

        let state = classifier.classify(event: event, context: context)
        let plan = refreshPlanner.plan(
            event: event,
            context: context,
            continuationState: state
        )
        let transcript = buildTranscript(
            event: event,
            context: context,
            continuationState: state
        )

        return ContinuationResult(
            transcriptInsertions: transcript,
            recommendationRefreshPlan: plan,
            continuationState: state
        )
    }

    // MARK: - Input validation

    private func isStructurallyValid(
        event: ExecutionReturnEvent,
        context: ContinuationContext
    ) -> Bool {
        !event.sourceRequestId.isEmpty && !context.threadId.isEmpty
    }

    // MARK: - Transcript

    private func buildTranscript(
        event: ExecutionReturnEvent,
        context: ContinuationContext,
        continuationState: ContinuationState
    ) -> [ChatContinuationEvent] {
        switch event.outcome {
        case .completion:
            return buildCompletionTranscript(
                event: event,
                continuationState: continuationState
            )
        case .abandon:
            return buildAbandonTranscript(event: event)
        case .dismiss:
            return buildDismissTranscript(event: event)
        case .acceptNoEntry:
            return buildAcceptNoEntryTranscript(event: event)
        }
    }

    // §7.1.A — MUST summary; MAY evidence (only if payload has it);
    // SHOULD prompt when adjacent step exists.
    private func buildCompletionTranscript(
        event: ExecutionReturnEvent,
        continuationState: ContinuationState
    ) -> [ChatContinuationEvent] {
        var events: [ChatContinuationEvent] = []

        events.append(
            .systemSummary(
                ContinuationSummaryBlock(
                    sourceSurface: event.sourceSurface,
                    outcome: .completion,
                    summaryText: defaultSummary(
                        for: event.sourceSurface,
                        outcome: .completion
                    ),
                    sourceRequestId: event.sourceRequestId,
                    sourceRecommendationId: event.sourceRecommendationId
                )
            )
        )

        if let evidence = buildEvidence(payload: event.payload) {
            events.append(.systemEvidence(evidence))
        }

        if let prompt = buildNextStepPrompt(
            event: event,
            continuationState: continuationState
        ) {
            events.append(.nextStepPrompt(prompt))
        }

        return events
    }

    // §7.1.B — MUST summary; MUST NOT fabricate evidence.
    private func buildAbandonTranscript(
        event: ExecutionReturnEvent
    ) -> [ChatContinuationEvent] {
        [
            .systemSummary(
                ContinuationSummaryBlock(
                    sourceSurface: event.sourceSurface,
                    outcome: .abandon,
                    summaryText: defaultSummary(
                        for: event.sourceSurface,
                        outcome: .abandon
                    ),
                    sourceRequestId: event.sourceRequestId,
                    sourceRecommendationId: event.sourceRecommendationId
                )
            )
        ]
    }

    // §7.1.C — MAY short summary; MUST suppress source (handled in
    // RecommendationRefreshPlanner). No evidence, no prompt by default.
    private func buildDismissTranscript(
        event: ExecutionReturnEvent
    ) -> [ChatContinuationEvent] {
        [
            .systemSummary(
                ContinuationSummaryBlock(
                    sourceSurface: event.sourceSurface,
                    outcome: .dismiss,
                    summaryText: defaultSummary(
                        for: event.sourceSurface,
                        outcome: .dismiss
                    ),
                    sourceRequestId: event.sourceRequestId,
                    sourceRecommendationId: event.sourceRecommendationId
                )
            )
        ]
    }

    // §7.1.D — MUST at most one lightweight summary; MUST NOT evidence.
    private func buildAcceptNoEntryTranscript(
        event: ExecutionReturnEvent
    ) -> [ChatContinuationEvent] {
        [
            .systemSummary(
                ContinuationSummaryBlock(
                    sourceSurface: event.sourceSurface,
                    outcome: .acceptNoEntry,
                    summaryText: defaultSummary(
                        for: event.sourceSurface,
                        outcome: .acceptNoEntry
                    ),
                    sourceRequestId: event.sourceRequestId,
                    sourceRecommendationId: event.sourceRecommendationId
                )
            )
        ]
    }

    // §8.2 — evidence only when payload has normalized fields.
    private func buildEvidence(
        payload: ReturnPayload?
    ) -> ContinuationEvidenceBlock? {
        guard let payload,
              !payload.structuredEvidence.isEmpty else {
            return nil
        }
        return ContinuationEvidenceBlock(
            title: payload.title,
            items: payload.structuredEvidence
        )
    }

    // §8.3 — system continuation cue, not a forced answer. Generated
    // here; never echoes payload.downstreamValueHint verbatim (§13.1,
    // §13.3).
    private func buildNextStepPrompt(
        event: ExecutionReturnEvent,
        continuationState: ContinuationState
    ) -> ContinuationPromptBlock? {
        guard continuationState != .newTask else { return nil }
        let phrasing: String
        switch continuationState {
        case .sameTask:
            phrasing = "Ready to continue with this task?"
        case .adjacentTask:
            phrasing = "Want to pick up on the next step?"
        case .newTask:
            return nil
        }
        return ContinuationPromptBlock(
            prompt: phrasing,
            taskFamily: event.payload?.taskFamily
        )
    }

    // Neutral, system-authored phrasing. v1 rule: no provider-specific
    // claims, no marketing tone, no implied success when outcome isn't
    // completion (§8.1).
    private func defaultSummary(
        for surface: SurfaceKind,
        outcome: ContinuationOutcome
    ) -> String {
        let surfaceLabel = surface.rawValue
        switch outcome {
        case .completion:
            return "Finished in \(surfaceLabel)."
        case .abandon:
            return "Returned from \(surfaceLabel) without finishing."
        case .dismiss:
            return "Closed the \(surfaceLabel) suggestion."
        case .acceptNoEntry:
            return "Saved for later in \(surfaceLabel)."
        }
    }
}
