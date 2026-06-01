//
//  ServerProviderRenderedRuntimeStatusSource.swift
//  kAir
//
//  Pure rendered-id guard for runtime receipt provider status.
//

import Foundation

struct ServerProviderRenderedRuntimeStatusSource: ProviderStatusProviding {
    private let source: any ProviderStatusProviding
    private let renderedRecommendationIDSet: Set<String>
    let renderedRecommendationIDs: [String]

    init(
        source: any ProviderStatusProviding,
        renderedRecommendationIDs: [String]
    ) {
        var seenRecommendationIDs: Set<String> = []
        for recommendationID in renderedRecommendationIDs {
            seenRecommendationIDs.insert(recommendationID)
        }
        self.source = source
        self.renderedRecommendationIDSet = seenRecommendationIDs
        self.renderedRecommendationIDs = seenRecommendationIDs.sorted()
    }

    func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard renderedRecommendationIDSet.contains(recommendationID) else {
            return nil
        }
        return source.providerStatusPresentation(for: recommendationID)
    }
}
