//
//  ServerProviderRuntimeStatusSourceProducer.swift
//  kAir
//
//  Pure producer for runtime receipt provider status sources.
//

import Foundation

@MainActor
struct ServerProviderRuntimeStatusSourceProducer {
    struct ReceiptInput: Hashable, Sendable {
        let recommendationID: String
        let receipt: ServerProviderRuntimeReceipt
    }

    struct PipelineInput: Hashable, Sendable {
        let recommendationID: String
        let readinessDecision: ServerProviderExecutionReadinessDecision
    }

    struct ManifestBackedPipelineInput: Hashable, Sendable {
        let recommendationID: String
        let readinessDecision: ServerProviderExecutionReadinessDecision
        let authorization: ServerProviderRuntimeAdapterManifestSetUseAuthorization
    }

    func statusSource(
        receipts inputs: [ReceiptInput]
    ) -> RuntimeReceiptProviderStatusStore {
        RuntimeReceiptProviderStatusStore(
            receipts: inputs.map { input in
                (
                    recommendationID: input.recommendationID,
                    receipt: input.receipt
                )
            }
        )
    }

    func statusSource(
        readinessDecisions inputs: [PipelineInput],
        adapterSet: ServerProviderRuntimeAdapterSet
    ) -> RuntimeReceiptProviderStatusStore {
        statusSource(
            receipts: inputs.map { input in
                ReceiptInput(
                    recommendationID: input.recommendationID,
                    receipt: ServerProviderRuntimePipeline.run(
                        readinessDecision: input.readinessDecision,
                        adapterSet: adapterSet
                    )
                )
            }
        )
    }

    func statusSource(
        readinessDecisions inputs: [PipelineInput],
        adapterSet: ServerProviderRuntimeAdapterSet,
        validation: ServerProviderRuntimeAdapterSetReadinessValidation
    ) -> RuntimeReceiptProviderStatusStore {
        statusSource(
            receipts: inputs.map { input in
                ReceiptInput(
                    recommendationID: input.recommendationID,
                    receipt: ServerProviderRuntimePipeline.run(
                        readinessDecision: input.readinessDecision,
                        adapterSet: adapterSet,
                        validation: validation
                    )
                )
            }
        )
    }

    func statusSource(
        manifestBackedReadinessDecisions inputs: [ManifestBackedPipelineInput],
        adapterSet: ServerProviderRuntimeAdapterSet
    ) -> RuntimeReceiptProviderStatusStore {
        statusSource(
            receipts: inputs.map { input in
                ReceiptInput(
                    recommendationID: input.recommendationID,
                    receipt: ServerProviderRuntimePipeline.run(
                        readinessDecision: input.readinessDecision,
                        adapterSet: adapterSet,
                        authorization: input.authorization
                    )
                )
            }
        )
    }
}
