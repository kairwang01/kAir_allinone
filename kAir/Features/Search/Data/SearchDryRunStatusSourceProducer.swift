//
//  SearchDryRunStatusSourceProducer.swift
//  kAir
//
//  Pure producer for precomputed Search dry-run provider status sources.
//

import Foundation

@MainActor
struct SearchDryRunStatusSourceProducer {
    struct PresentationInput: Hashable, Sendable {
        let recommendationID: String
        let presentation: ServerProviderDryRunPresentation
    }

    struct ReportInput: Hashable, Sendable {
        let recommendationID: String
        let report: ServerProviderDryRunReport
    }

    func statusSource(
        adapter: SearchCapabilityAdapter,
        presentations inputs: [PresentationInput]
    ) -> SearchDryRunProviderStatusStore {
        adapter.dryRunProviderStatusSource(
            presentations: inputs.map { input in
                (
                    recommendationID: input.recommendationID,
                    presentation: input.presentation
                )
            }
        )
    }

    func statusSource(
        adapter: SearchCapabilityAdapter,
        reports inputs: [ReportInput]
    ) -> SearchDryRunProviderStatusStore {
        adapter.dryRunProviderStatusSource(
            reports: inputs.map { input in
                (
                    recommendationID: input.recommendationID,
                    report: input.report
                )
            }
        )
    }
}
