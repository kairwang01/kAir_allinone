//
//  ServerProviderSearchAPIVendorPolicyStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for Search API vendor
//  policy decisions.
//

import Foundation

@MainActor
struct ServerProviderSearchAPIVendorPolicyStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPIVendorPolicyDecision
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: SearchAPIVendorPolicyProviderStatusStore(
                decisions: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        decision: input.decision
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}
