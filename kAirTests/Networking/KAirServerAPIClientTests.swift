//
//  KAirServerAPIClientTests.swift
//  kAirTests
//
//  Contract tests for the real kAir backend /v1 client boundary.
//

import Foundation
import XCTest
@testable import kAir

final class KAirServerAPIClientTests: XCTestCase {

    func test_loginAndMeUseContractPathsAndBearerRules() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [
            try .json([
                "accessToken": "access-token",
                "refreshToken": "refresh-token",
                "expiresIn": 900,
                "tokenType": "Bearer",
            ]),
            try .json([
                "userId": "user-1",
                "tenant": "kair",
                "email": "pro@example.com",
                "roles": ["user"],
                "membershipTier": "pro",
                "createdAt": "2026-06-01T00:00:00Z",
            ]),
        ])
        let client = client(httpClient: httpClient)

        let tokenPair = try await client.login(email: "pro@example.com", password: "correct horse")
        let me = try await client.me()

        XCTAssertEqual(tokenPair.accessToken, "access-token")
        XCTAssertEqual(tokenPair.refreshToken, "refresh-token")
        XCTAssertEqual(me.membershipTier, .pro)

        let requests = await httpClient.recordedRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertEqual(requests[0].url?.path, "/v1/auth/login")
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "X-App-Attest"), "attest-fixture")

        let loginBody = try jsonDictionary(from: requests[0])
        XCTAssertEqual(loginBody["email"] as? String, "pro@example.com")
        XCTAssertEqual(loginBody["password"] as? String, "correct horse")

        XCTAssertEqual(requests[1].httpMethod, "GET")
        XCTAssertEqual(requests[1].url?.path, "/v1/me")
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
    }

    func test_refreshUsesRefreshTokenFieldWithoutBearer() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [
            try .json([
                "accessToken": "access-2",
                "refreshToken": "refresh-2",
                "expiresIn": 900,
                "tokenType": "Bearer",
            ]),
        ])
        let client = client(httpClient: httpClient)

        let tokenPair = try await client.refresh(refreshToken: "refresh-1")

        XCTAssertEqual(tokenPair.refreshToken, "refresh-2")
        let requests = await httpClient.recordedRequests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/v1/auth/refresh")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

        let body = try jsonDictionary(from: request)
        XCTAssertEqual(body["refreshToken"] as? String, "refresh-1")
        XCTAssertNil(body["refresh"])
    }

    func test_entitlementSnapshotMapsToProviderProfileAndQuotaSnapshot() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [
            try .json([
                "membershipTier": "pro",
                "status": "active",
                "currentPeriodEnd": "2026-07-01T00:00:00Z",
                "sourceAt": "2026-06-01T00:00:00Z",
                "entitlements": [
                    [
                        "providerFamily": "googleMaps",
                        "capability": "placeSearch",
                        "allowed": true,
                        "includedQuota": 0,
                        "meteredEligible": true,
                    ],
                    [
                        "providerFamily": "searchAPI",
                        "capability": "webSearch",
                        "allowed": true,
                        "includedQuota": 25,
                        "meteredEligible": true,
                    ],
                    [
                        "providerFamily": "crawler",
                        "capability": "crawlerFetch",
                        "allowed": false,
                        "includedQuota": 0,
                        "meteredEligible": false,
                    ],
                    [
                        "providerFamily": "researchAPI",
                        "capability": "scholarlySearch",
                        "allowed": true,
                        "includedQuota": 5,
                        "meteredEligible": false,
                    ],
                ],
                "quotas": [
                    [
                        "providerFamily": "searchAPI",
                        "periodId": "2026-06",
                        "includedUnits": 25,
                        "usedUnits": 7,
                        "remainingUnits": 18,
                    ],
                    [
                        "providerFamily": "googleMaps",
                        "periodId": "2026-06",
                        "includedUnits": 0,
                        "usedUnits": 3,
                        "remainingUnits": 0,
                    ],
                ],
            ]),
        ])
        let client = client(httpClient: httpClient)

        let snapshot = try await client.entitlements()
        let profile = snapshot.providerAccessProfile(defaultRegion: .northAmerica)
        let quotaSnapshot = snapshot.providerQuotaSnapshot()

        XCTAssertEqual(snapshot.membershipTier, .pro)
        XCTAssertEqual(snapshot.entitlements.map(\.providerFamily), [.googleMaps, .searchAPI, .crawler, .researchAPI])
        XCTAssertEqual(profile.membershipTier, .pro)
        XCTAssertEqual(profile.defaultRegion, .northAmerica)
        XCTAssertEqual(profile.meteredProviderEntitlements, [.googleMaps, .searchAPI])
        XCTAssertEqual(profile.unavailableProviders, [.crawler])
        XCTAssertEqual(quotaSnapshot.allowedProviderFamilies, [.appleLocal, .cache, .googleMaps, .searchAPI])
        XCTAssertEqual(quotaSnapshot.entitledProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(quotaSnapshot.meteredEligibleProviderFamilies, [.googleMaps, .searchAPI])
        XCTAssertEqual(quotaSnapshot.disabledProviderFamilies, [.crawler])
        XCTAssertEqual(quotaSnapshot.remainingIncludedQuota[.searchAPI], 18)
    }

    func test_providerGatewayPostsTraceIdAndDecodesBlocked200AsValue() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [
            try .json([
                "result": NSNull(),
                "blocked": [
                    "reason": "blockedByPrivacy",
                    "message": "Health and private context stays on device.",
                ],
                "limitations": ["Remote providers are unavailable for this privacy class."],
                "trace": providerTrace(
                    traceId: "trace-privacy",
                    capability: "webSearch",
                    selectedProviderId: NSNull(),
                    selectedProviderFamily: NSNull(),
                    costClass: "blockedByPrivacy",
                    privacyClass: "health",
                    failureReason: "privacy.health_local_only"
                ),
            ]),
        ])
        let client = client(httpClient: httpClient)
        let envelope = KAirProviderEnvelope(
            traceId: "trace-privacy",
            capability: .webSearch,
            providerFamily: .searchAPI,
            privacyClass: .health,
            region: .northAmerica,
            membershipTier: .pro,
            costClass: .meteredPremium,
            freshness: .liveRequired,
            preferredProvider: .searchAPI,
            confirmationState: .notRequired
        )

        let response: KAirProviderResult<[FixtureSearchHit]> = try await client.postSearch(
            envelope: envelope,
            query: KAirSearchQuery(text: "private symptom query", maxResults: 3, region: .northAmerica),
            idempotencyKey: "idem-search"
        )

        XCTAssertNil(response.result)
        XCTAssertEqual(response.blocked?.reason, .blockedByPrivacy)
        XCTAssertEqual(response.trace.traceId, "trace-privacy")
        XCTAssertEqual(response.trace.selectedProviderFamily, nil)
        XCTAssertEqual(response.trace.failureReason, "privacy.health_local_only")

        let requests = await httpClient.recordedRequests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/v1/kair/search")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "idem-search")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Trace-Id"), "trace-privacy")

        let body = try jsonDictionary(from: request)
        let encodedEnvelope = try XCTUnwrap(body["envelope"] as? [String: Any])
        XCTAssertEqual(encodedEnvelope["traceId"] as? String, "trace-privacy")
        XCTAssertEqual(encodedEnvelope["capability"] as? String, "webSearch")
        XCTAssertEqual(encodedEnvelope["providerFamily"] as? String, "searchAPI")
        XCTAssertEqual(encodedEnvelope["privacyClass"] as? String, "health")
        XCTAssertEqual(encodedEnvelope["confirmationState"] as? String, "notRequired")
        XCTAssertNil(encodedEnvelope["traceID"])
        XCTAssertNil(encodedEnvelope["sourcePolicy"])
        XCTAssertNil(encodedEnvelope["meteredProviderEntitlements"])
        XCTAssertNil(encodedEnvelope["enabledExperimentalProviders"])
    }

    func test_providerGatewaySuccessDecodesResultTraceAndCitations() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [
            try .json([
                "result": [
                    [
                        "title": "kAir fixture search result",
                        "url": "https://example.com/kair",
                    ],
                ],
                "citations": [
                    [
                        "title": "Fixture source",
                        "url": "https://example.com/source",
                        "sourceId": "fixture-source",
                    ],
                ],
                "trace": providerTrace(
                    traceId: "trace-success",
                    capability: "webSearch",
                    selectedProviderId: "search-fixture",
                    selectedProviderFamily: "searchAPI",
                    costClass: "includedQuota",
                    privacyClass: "general",
                    failureReason: NSNull()
                ),
            ]),
        ])
        let client = client(httpClient: httpClient)

        let response: KAirProviderResult<[FixtureSearchHit]> = try await client.postSearch(
            envelope: KAirProviderEnvelope(
                traceId: "trace-success",
                capability: .webSearch,
                providerFamily: .searchAPI,
                region: .global,
                membershipTier: .pro,
                costClass: .includedQuota,
                freshness: .livePreferred
            ),
            query: KAirSearchQuery(text: "kAir"),
            idempotencyKey: "idem-success"
        )

        XCTAssertEqual(response.result, [FixtureSearchHit(title: "kAir fixture search result", url: URL(string: "https://example.com/kair")!)])
        XCTAssertNil(response.blocked)
        XCTAssertEqual(response.citations?.first?.sourceId, "fixture-source")
        XCTAssertEqual(response.trace.selectedProviderFamily, KAirAPIProviderFamily.searchAPI)
        XCTAssertEqual(response.trace.costClass, ProviderCostClass.includedQuota)
    }

    func test_non2xxResponseThrowsStableAPIError() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [
            try .json(
                [
                    "error": [
                        "code": "auth.token_expired",
                        "message": "Access token expired.",
                        "traceId": "trace-auth",
                    ],
                ],
                statusCode: 401
            ),
        ])
        let client = client(httpClient: httpClient)

        do {
            _ = try await client.me()
            XCTFail("Expected API error.")
        } catch KAirServerAPIClientError.api(let statusCode, let error) {
            XCTAssertEqual(statusCode, 401)
            XCTAssertEqual(error.code, "auth.token_expired")
            XCTAssertEqual(error.traceId, "trace-auth")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_authenticatedRouteRequiresAccessTokenBeforeNetwork() async throws {
        let httpClient = RecordingKAirHTTPClient(responses: [])
        let client = KAirServerAPIClient(
            baseURL: baseURL,
            httpClient: httpClient,
            credentials: { KAirServerCredentials() }
        )

        do {
            _ = try await client.me()
            XCTFail("Expected missing token.")
        } catch KAirServerAPIClientError.missingAccessToken {
            let requests = await httpClient.recordedRequests
            XCTAssertTrue(requests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private var baseURL: URL {
        URL(string: "https://api.kair.test/v1")!
    }

    private func client(httpClient: RecordingKAirHTTPClient) -> KAirServerAPIClient {
        KAirServerAPIClient(
            baseURL: baseURL,
            httpClient: httpClient,
            credentials: {
                KAirServerCredentials(
                    accessToken: "access-token",
                    appAttestAssertion: "attest-fixture"
                )
            }
        )
    }

    private static func providerTrace(
        traceId: String,
        capability: String,
        selectedProviderId: Any,
        selectedProviderFamily: Any,
        costClass: String,
        privacyClass: String,
        failureReason: Any
    ) -> [String: Any] {
        [
            "traceId": traceId,
            "capability": capability,
            "selectedProviderId": selectedProviderId,
            "selectedProviderFamily": selectedProviderFamily,
            "costClass": costClass,
            "privacyClass": privacyClass,
            "membershipTier": "pro",
            "freshness": "livePreferred",
            "latencyMs": 12,
            "resultCount": selectedProviderId is NSNull ? 0 : 1,
            "failureReason": failureReason,
        ]
    }

    private func providerTrace(
        traceId: String,
        capability: String,
        selectedProviderId: Any,
        selectedProviderFamily: Any,
        costClass: String,
        privacyClass: String,
        failureReason: Any
    ) -> [String: Any] {
        Self.providerTrace(
            traceId: traceId,
            capability: capability,
            selectedProviderId: selectedProviderId,
            selectedProviderFamily: selectedProviderFamily,
            costClass: costClass,
            privacyClass: privacyClass,
            failureReason: failureReason
        )
    }

    private func jsonDictionary(from request: URLRequest) throws -> [String: Any] {
        let body = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private struct FixtureSearchHit: Codable, Hashable, Sendable {
    let title: String
    let url: URL
}

private struct QueuedHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    static func json(
        _ object: [String: Any],
        statusCode: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) throws -> QueuedHTTPResponse {
        QueuedHTTPResponse(
            data: try JSONSerialization.data(withJSONObject: object),
            statusCode: statusCode,
            headers: headers
        )
    }
}

private actor RecordingKAirHTTPClient: KAirHTTPClient {
    private var responses: [QueuedHTTPResponse]
    private var requests: [URLRequest] = []

    init(responses: [QueuedHTTPResponse]) {
        self.responses = responses
    }

    var recordedRequests: [URLRequest] { requests }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = responses.removeFirst()

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: response.headers
        )!
        return (response.data, httpResponse)
    }
}
