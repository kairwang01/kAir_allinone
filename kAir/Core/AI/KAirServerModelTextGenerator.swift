//
//  KAirServerModelTextGenerator.swift
//  kAir
//
//  Server-backed chat generation adapter for staging and paid-remote model
//  experiments.
//

import Foundation

/// Bridges the chat generation seam to `/v1/kair/model`.
///
/// This adapter is intentionally not the default local-first path. It is a
/// drop-in `KAirTextGenerator` so staging builds can replace the baseline chat
/// reply with a server model result while keeping the same `ChatStore`
/// replacement behavior. Private and Health prompts must stay on-device; callers
/// should only use this adapter for `.general` chat requests.
struct KAirServerModelTextGenerator: KAirTextGenerator {
    let client: KAirServerAPIClient
    let region: ProviderRegion
    let membershipTier: MembershipTier?
    let costClass: ProviderCostClass

    init(
        client: KAirServerAPIClient,
        region: ProviderRegion = .northAmerica,
        membershipTier: MembershipTier? = nil,
        costClass: ProviderCostClass = .includedQuota
    ) {
        self.client = client
        self.region = region
        self.membershipTier = membershipTier
        self.costClass = costClass
    }

    func isAvailable() async -> Bool { true }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        let response = try await fetch(request)
        return try Self.message(from: response)
    }

    func generateReply(_ request: KAirGenerationRequest) async throws -> KAirGeneratedReply {
        let response = try await fetch(request)
        let message = try Self.message(from: response)
        return KAirGeneratedReply(
            text: message,
            serverModelInfo: Self.modelInfo(from: response)
        )
    }

    private func fetch(
        _ request: KAirGenerationRequest
    ) async throws -> KAirProviderResult<KAirModelCompletion> {
        let traceID = "ios-model-\(UUID().uuidString)"
        let envelope = KAirProviderEnvelope(
            traceId: traceID,
            capability: .chatCompletion,
            providerFamily: .modelGateway,
            privacyClass: .general,
            region: region,
            membershipTier: membershipTier,
            costClass: costClass,
            freshness: .livePreferred,
            preferredProvider: .modelGateway,
            confirmationState: .notRequired
        )
        let prompt = Self.composePrompt(from: request)
        return try await client.postModel(
            envelope: envelope,
            query: KAirModelQuery(text: prompt, region: region),
            idempotencyKey: traceID
        )
    }

    private static func message(
        from response: KAirProviderResult<KAirModelCompletion>
    ) throws -> String {
        if response.blocked != nil {
            throw KAirTextGeneratorError.unavailable
        }
        guard let message = response.result?.message.trimmingCharacters(in: .whitespacesAndNewlines),
              message.isEmpty == false else {
            throw KAirTextGeneratorError.generationFailed
        }
        return message
    }

    private static func modelInfo(
        from response: KAirProviderResult<KAirModelCompletion>
    ) -> KAirServerModelInfo {
        let usage = response.result?.usage
        return KAirServerModelInfo(
            model: response.result?.model,
            finishReason: response.result?.finishReason,
            promptTokens: usage?.promptTokens,
            completionTokens: usage?.completionTokens,
            reasoningTokens: usage?.reasoningTokens,
            totalTokens: usage?.totalTokens,
            latencyMs: response.trace.latencyMs,
            citationCount: response.citations?.count ?? 0,
            selectedProviderId: response.trace.selectedProviderId
        )
    }

    private static func composePrompt(from request: KAirGenerationRequest) -> String {
        """
        System:
        \(request.systemInstructions)

        User:
        \(request.prompt)
        """
    }
}
