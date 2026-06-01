//
//  ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id scoped provider-status projection for Search API vendor
//  dispatch authorization results.
//

import Foundation

@MainActor
struct ServerProviderSearchAPIVendorPolicyDispatchAuthorizationStatusSourceProducer {
    struct Input: Hashable, Sendable {
        let recommendationID: String
        let authorization: ServerProviderSearchAPIVendorPolicyDispatchAuthorization
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: SearchAPIVendorDispatchAuthorizationProviderStatusStore(
                authorizations: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        authorization: input.authorization
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}
