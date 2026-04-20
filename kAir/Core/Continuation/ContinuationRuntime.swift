//
//  ContinuationRuntime.swift
//  kAir
//
//  v1 runtime contract for post-return behavior.
//  Normative spec: Contracts/UX/continuation-runtime-v1.md §17
//
//  After v1 lands, no vertical (Maps / Music / Search / Video / Tools /
//  future surfaces) may define its own post-return Chat insertion rule
//  or recommendation-refresh rule outside this runtime.
//  See spec §1, §3, §13.
//
//  This file is intentionally minimal — just the protocol. Models live
//  in ContinuationModels.swift; the reference implementation lives in
//  DefaultContinuationRuntime.swift; classification and refresh
//  planning are split into ContinuationClassifier.swift and
//  RecommendationRefreshPlanner.swift per spec §19.
//

import Foundation

public protocol ContinuationRuntime: Sendable {
    func handleReturn(
        event: ExecutionReturnEvent,
        context: ContinuationContext
    ) -> ContinuationResult
}
