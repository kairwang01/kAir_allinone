//
//  SearchRenderedDryRunStatusSource.swift
//  kAir
//
//  Pure rendered-id guard for precomputed Search dry-run provider status.
//

import Foundation

struct SearchRenderedDryRunStatusSource: ProviderStatusProviding {
    private let source: SearchDryRunProviderStatusStore
    private let renderedRecommendationIDSet: Set<String>
    let renderedRecommendationIDs: [String]

    init(
        source: SearchDryRunProviderStatusStore,
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
