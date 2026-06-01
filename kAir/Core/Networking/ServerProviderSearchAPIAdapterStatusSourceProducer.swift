//
//  ServerProviderSearchAPIAdapterStatusSourceProducer.swift
//  kAir
//
//  Pure rendered-id guarded status-source projection for Search API adapter
//  request decisions and result receipts.
//

import Foundation

@MainActor
struct ServerProviderSearchAPIAdapterStatusSourceProducer {
    struct RequestDecisionInput: Hashable, Sendable {
        let recommendationID: String
        let decision: ServerProviderSearchAPIAdapterRequestDecision
    }

    struct ResultReceiptInput: Hashable, Sendable {
        let recommendationID: String
        let receipt: ServerProviderSearchAPIAdapterResultReceipt
    }

    enum Input: Hashable, Sendable {
        case requestDecision(RequestDecisionInput)
        case resultReceipt(ResultReceiptInput)

        var recommendationID: String {
            switch self {
            case .requestDecision(let input):
                return input.recommendationID
            case .resultReceipt(let input):
                return input.recommendationID
            }
        }

        var statusValue: SearchAPIAdapterProviderStatusValue {
            switch self {
            case .requestDecision(let input):
                return .requestDecision(input.decision)
            case .resultReceipt(let input):
                return .resultReceipt(input.receipt)
            }
        }
    }

    func statusSource(
        inputs: [Input],
        renderedRecommendationIDs: [String]
    ) -> ServerProviderRenderedRuntimeStatusSource {
        ServerProviderRenderedRuntimeStatusSource(
            source: SearchAPIAdapterProviderStatusStore(
                values: inputs.map { input in
                    (
                        recommendationID: input.recommendationID,
                        value: input.statusValue
                    )
                }
            ),
            renderedRecommendationIDs: renderedRecommendationIDs
        )
    }
}
