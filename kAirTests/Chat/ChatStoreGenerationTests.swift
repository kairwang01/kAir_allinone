//
//  ChatStoreGenerationTests.swift
//  kAirTests
//
//  B6b — on-device chat reply generation wiring. Verifies the optional
//  `KAirTextGenerator` injection: no generator keeps the static baseline
//  (existing behavior), a generator replaces the reply text in place, and a
//  generation failure leaves the baseline intact.
//

import Foundation
import XCTest
@testable import kAir

final class ChatStoreGenerationTests: XCTestCase {

    @MainActor
    func test_submit_withoutGenerator_usesStaticBaseline() {
        let store = ChatStore()
        store.submitPrompt("hello there", using: nil)
        XCTAssertNil(store.pendingReplyGeneration)   // nothing kicked off
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertFalse(last?.text.isEmpty ?? true)   // static baseline reply
    }

    @MainActor
    func test_submit_withGenerator_replacesReplyText() async {
        let store = ChatStore(textGenerator: StubTextGenerator(output: "ON-DEVICE REPLY"))
        store.submitPrompt("hello there", using: nil)
        await store.pendingReplyGeneration?.value
        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertEqual(last?.text, "ON-DEVICE REPLY")
    }

    @MainActor
    func test_submit_withServerModelGenerator_replacesReplyTextWithGatewayMessage() async throws {
        let httpClient = SingleResponseKAirHTTPClient(
            object: [
                "result": [
                    "message": "SERVER MODEL REPLY",
                    "model": "deepseek-v4-flash-202605",
                    "finishReason": "stop",
                    "usage": [
                        "promptTokens": 34,
                        "completionTokens": 106,
                        "reasoningTokens": 23,
                        "totalTokens": 140,
                    ],
                ],
                "trace": [
                    "traceId": "trace-model",
                    "capability": "chatCompletion",
                    "selectedProviderId": "tokenhub:deepseek-v4-flash-202605",
                    "selectedProviderFamily": "modelGateway",
                    "costClass": "includedQuota",
                    "privacyClass": "general",
                    "membershipTier": "pro",
                    "freshness": "livePreferred",
                    "latencyMs": 12,
                    "resultCount": 1,
                    "failureReason": NSNull(),
                ],
            ]
        )
        let client = KAirServerAPIClient(
            baseURL: URL(string: "https://api.kair.test/v1")!,
            httpClient: httpClient,
            credentials: {
                KAirServerCredentials(accessToken: "access-token")
            }
        )
        let store = ChatStore(
            textGenerator: KAirServerModelTextGenerator(client: client, membershipTier: .pro)
        )

        store.submitPrompt("hello server", using: nil)
        await store.pendingReplyGeneration?.value

        let last = store.session.messages.last
        XCTAssertEqual(last?.role, .assistant)
        XCTAssertEqual(last?.text, "SERVER MODEL REPLY")

        // The server model reply attaches an "AI Runtime" card surfacing the
        // concrete model, token usage (including reasoning tokens), and latency.
        let card = try XCTUnwrap(last?.toolResults.first(where: { $0.id == "server_model_runtime" }))
        XCTAssertEqual(card.title, "AI Runtime")
        XCTAssertEqual(card.state, .ready)
        XCTAssertTrue(card.metrics.contains(.init(key: "Model", value: "deepseek-v4-flash-202605")))
        XCTAssertTrue(card.metrics.contains(.init(key: "Tokens", value: "140")))
        XCTAssertTrue(card.metrics.contains(.init(key: "Reasoning", value: "23")))
        XCTAssertTrue(card.metrics.contains(.init(key: "Latency", value: "12 ms")))

        let recordedRequest = await httpClient.recordedRequest
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.url?.path, "/v1/kair/model")
    }

    @MainActor
    func test_submit_generatorFailure_keepsBaseline() async {
        let store = ChatStore(textGenerator: StubTextGenerator(output: nil))   // throws
        store.submitPrompt("hello there", using: nil)
        let baseline = store.session.messages.last?.text
        XCTAssertNotNil(baseline)
        await store.pendingReplyGeneration?.value
        XCTAssertEqual(store.session.messages.last?.text, baseline)   // unchanged
    }
}

private struct StubTextGenerator: KAirTextGenerator {
    let output: String?   // nil → throw

    func isAvailable() async -> Bool { true }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        guard let output else { throw KAirTextGeneratorError.generationFailed }
        return output
    }
}

private actor SingleResponseKAirHTTPClient: KAirHTTPClient {
    private let data: Data
    private(set) var recordedRequest: URLRequest?

    init(object: [String: Any]) {
        self.data = try! JSONSerialization.data(withJSONObject: object)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recordedRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}
