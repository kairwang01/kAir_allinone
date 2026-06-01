//
//  KAirAuthSessionTests.swift
//  kAirTests
//
//  Door 2 — auth session + token store + 401-refresh-retry. Pure logic with
//  an in-memory store + a stub HTTP client; no Keychain/network in tests.
//

import XCTest
@testable import kAir

final class KAirAuthSessionTests: XCTestCase {

    // MARK: - In-memory store

    func test_store_roundTripAndClear() throws {
        let store = InMemoryKAirSessionStore()
        XCTAssertNil(try store.load())
        let session = Self.stored("a", "r")
        try store.save(session)
        XCTAssertEqual(try store.load(), session)
        try store.clear()
        XCTAssertNil(try store.load())
    }

    // MARK: - Init reflects stored state

    @MainActor
    func test_init_signedInWhenStored() {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(session: Self.stored("a", "r")))
        XCTAssertEqual(manager.state, .signedIn)
        XCTAssertTrue(manager.isSignedIn)
        XCTAssertEqual(manager.accessToken(), "a")
    }

    @MainActor
    func test_init_signedOutWhenEmpty() {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore())
        XCTAssertEqual(manager.state, .signedOut)
        XCTAssertNil(manager.accessToken())
    }

    // MARK: - apply / signOut

    @MainActor
    func test_apply_signsInAndPersistsWithExpiry() throws {
        let store = InMemoryKAirSessionStore()
        let manager = KAirAuthSessionManager(store: store, now: { Self.fixedNow })
        manager.apply(Self.pair("a", "r", expiresIn: 900))
        XCTAssertEqual(manager.state, .signedIn)
        XCTAssertEqual(manager.accessToken(), "a")
        XCTAssertEqual(try store.load()?.accessToken, "a")
        XCTAssertEqual(try store.load()?.accessTokenExpiresAt, Self.fixedNow.addingTimeInterval(900))
    }

    @MainActor
    func test_signOut_clearsStateAndStore() throws {
        let store = InMemoryKAirSessionStore(session: Self.stored("a", "r"))
        let manager = KAirAuthSessionManager(store: store)
        manager.signOut()
        XCTAssertEqual(manager.state, .signedOut)
        XCTAssertNil(manager.accessToken())
        XCTAssertNil(try store.load())
    }

    @MainActor
    func test_isAccessTokenExpired() {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(), now: { Self.fixedNow })
        XCTAssertTrue(manager.isAccessTokenExpired)   // no token
        manager.apply(Self.pair("a", "r", expiresIn: 100))
        XCTAssertFalse(manager.isAccessTokenExpired)   // fixedNow + 100 in the future
    }

    // MARK: - Credentials provider

    @MainActor
    func test_credentialsProvider_returnsCurrentTokenNoAttestation() async {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(session: Self.stored("a", "r")))
        let credentials = await manager.credentialsProvider()()
        XCTAssertEqual(credentials.accessToken, "a")
        XCTAssertNil(credentials.appAttestAssertion)   // Noop provider
    }

    // MARK: - Refresh

    @MainActor
    func test_refresh_success_appliesNewTokens() async throws {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(session: Self.stored("old", "oldR")))
        try await manager.refresh(using: Self.clientReturningTokenPair("new", "newR"))
        XCTAssertEqual(manager.accessToken(), "new")
        XCTAssertEqual(manager.refreshToken, "newR")
        XCTAssertEqual(manager.state, .signedIn)
    }

    @MainActor
    func test_refresh_failure_signsOut() async {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(session: Self.stored("old", "oldR")))
        do {
            try await manager.refresh(using: Self.clientReturningStatus(401))
            XCTFail("refresh should throw")
        } catch {
            // expected
        }
        XCTAssertEqual(manager.state, .signedOut)
        XCTAssertNil(manager.accessToken())
    }

    @MainActor
    func test_refresh_noRefreshToken_signsOut() async {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore())
        do {
            try await manager.refresh(using: Self.clientReturningTokenPair("new", "newR"))
            XCTFail("refresh without a token should throw")
        } catch {
            // expected
        }
        XCTAssertEqual(manager.state, .signedOut)
    }

    // MARK: - withAutoRefresh (401 → refresh → retry once)

    @MainActor
    func test_withAutoRefresh_retriesAfter401() async throws {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(session: Self.stored("old", "oldR")))
        var attempts = 0
        let result: String = try await manager.withAutoRefresh(client: Self.clientReturningTokenPair("new", "newR")) {
            attempts += 1
            if attempts == 1 {
                throw KAirServerAPIClientError.api(
                    statusCode: 401,
                    error: KAirAPIError(code: "auth.token_expired", message: "", traceId: "")
                )
            }
            return "ok"
        }
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(manager.accessToken(), "new")   // refreshed between attempts
    }

    @MainActor
    func test_withAutoRefresh_refreshFailurePropagatesNoRetry() async {
        let manager = KAirAuthSessionManager(store: InMemoryKAirSessionStore(session: Self.stored("old", "oldR")))
        var attempts = 0
        do {
            _ = try await manager.withAutoRefresh(client: Self.clientReturningStatus(401)) {
                attempts += 1
                throw KAirServerAPIClientError.api(
                    statusCode: 401,
                    error: KAirAPIError(code: "x", message: "", traceId: "")
                )
            }
            XCTFail("should propagate the refresh failure")
        } catch {
            // expected
        }
        XCTAssertEqual(attempts, 1)   // op once; refresh failed → no second attempt
        XCTAssertEqual(manager.state, .signedOut)
    }

    // MARK: - Account deletion (App Store 5.1.1(v))

    @MainActor
    func test_deleteAccount_callsServerThenSignsOut() async throws {
        let store = InMemoryKAirSessionStore(session: Self.stored("tok", "ref"))
        let manager = KAirAuthSessionManager(store: store)
        let client = KAirServerAPIClient(
            baseURL: URL(string: "https://example.invalid/v1")!,
            httpClient: StubKAirHTTPClient(status: 202, body: Data()),
            credentials: { KAirServerCredentials(accessToken: "tok") }
        )
        try await manager.deleteAccount(using: client)
        XCTAssertEqual(manager.state, .signedOut)
        XCTAssertNil(try store.load())
    }

    @MainActor
    func test_client_deleteAccount_withoutToken_throws() async {
        let client = KAirServerAPIClient(
            baseURL: URL(string: "https://example.invalid/v1")!,
            httpClient: StubKAirHTTPClient(status: 202, body: Data())
        )
        do {
            try await client.deleteAccount()
            XCTFail("delete without a token should throw")
        } catch KAirServerAPIClientError.missingAccessToken {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Fixtures

    private static let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    private static func stored(_ accessToken: String, _ refreshToken: String) -> KAirStoredSession {
        KAirStoredSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: fixedNow.addingTimeInterval(900)
        )
    }

    private static func pair(_ accessToken: String, _ refreshToken: String, expiresIn: Int) -> KAirAuthTokenPair {
        KAirAuthTokenPair(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn, tokenType: "Bearer")
    }

    private static func clientReturningTokenPair(_ accessToken: String, _ refreshToken: String) -> KAirServerAPIClient {
        let body = try! JSONEncoder().encode(pair(accessToken, refreshToken, expiresIn: 900))
        return KAirServerAPIClient(
            baseURL: URL(string: "https://example.invalid/v1")!,
            httpClient: StubKAirHTTPClient(status: 200, body: body)
        )
    }

    private static func clientReturningStatus(_ status: Int) -> KAirServerAPIClient {
        let body = try! JSONEncoder().encode(
            KAirAPIErrorEnvelope(error: KAirAPIError(code: "e", message: "m", traceId: "t"))
        )
        return KAirServerAPIClient(
            baseURL: URL(string: "https://example.invalid/v1")!,
            httpClient: StubKAirHTTPClient(status: status, body: body)
        )
    }
}

private struct StubKAirHTTPClient: KAirHTTPClient {
    let status: Int
    let body: Data

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.invalid")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (body, response)
    }
}
