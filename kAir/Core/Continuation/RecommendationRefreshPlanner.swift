//
//  RecommendationRefreshPlanner.swift
//  kAir
//
//  outcome + context → RecommendationRefreshPlan
//  Normative spec: Contracts/UX/continuation-runtime-v1.md §11, §7.1
//
//  The planner implements the §11.2 default table literally. Per-
//  vertical override is forbidden (§11.2, §13.2): any behavior that
//  context cannot express through this runtime's inputs MUST be
//  promoted into the contract itself in a future version, not patched
//  in vertical code.
//

import Foundation

public struct RecommendationRefreshPlanner: Sendable {
    public init() {}

    public func plan(
        event: ExecutionReturnEvent,
        context: ContinuationContext,
        continuationState: ContinuationState
    ) -> RecommendationRefreshPlan {
        switch event.outcome {
        case .completion:
            // §11.2 row 1: refreshSameFamily, preserve accepted card,
            // no suppression. Upgrade to refreshAdjacentFamily when
            // classifier says adjacentTask (§7.1.A: "refreshSameFamily
            // or refreshAdjacentFamily").
            return RecommendationRefreshPlan(
                mode: continuationState == .adjacentTask
                    ? .refreshAdjacentFamily
                    : .refreshSameFamily,
                preserveAcceptedCard: event.sourceRecommendationId != nil,
                suppressSourceRecommendationId: nil,
                preferredTaskFamily: inferFamilyBias(
                    event: event,
                    strength: 0.75
                )
            )

        case .abandon:
            // §11.2 row 2: refreshSameFamily, preserve optional,
            // suppression no. v1 policy: preserve accepted card only
            // when the abandoned surface had a real accepted rec to
            // come back to.
            return RecommendationRefreshPlan(
                mode: .refreshSameFamily,
                preserveAcceptedCard: context.acceptedRecommendationId != nil,
                suppressSourceRecommendationId: nil,
                preferredTaskFamily: inferFamilyBias(
                    event: event,
                    strength: 0.5
                )
            )

        case .dismiss:
            // §11.2 row 3: refreshAdjacentFamily, preserve=false,
            // suppress=<sourceRecId>. §7.1.C also permits .clear
            // — v1 uses .clear only when there's literally nothing
            // else in the current rail to adjacent-refresh against.
            let useClear = context.currentRecommendationIds.count <= 1
            return RecommendationRefreshPlan(
                mode: useClear ? .clear : .refreshAdjacentFamily,
                preserveAcceptedCard: false,
                suppressSourceRecommendationId: event.sourceRecommendationId,
                preferredTaskFamily: nil
            )

        case .acceptNoEntry:
            // §11.2 row 4: preserve, preserve accepted card yes if
            // retryable, no suppression. §7.1.D permits preserve or
            // refreshSameFamily; we default to preserve.
            return RecommendationRefreshPlan(
                mode: .preserve,
                preserveAcceptedCard: event.sourceRecommendationId != nil,
                suppressSourceRecommendationId: nil,
                preferredTaskFamily: nil
            )
        }
    }

    private func inferFamilyBias(
        event: ExecutionReturnEvent,
        strength: Double
    ) -> TaskFamilyBias? {
        guard let family = event.payload?.taskFamily,
              !family.isEmpty else {
            return nil
        }
        return TaskFamilyBias(family: family, strength: strength)
    }
}
