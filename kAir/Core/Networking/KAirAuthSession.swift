//
//  KAirAuthSession.swift
//  kAir
//
//  Auth session + token store for the kAir backend. Keychain-backed in
//  production, in-memory in tests. Owns access/refresh tokens, exposes the
//  credentials closure `KAirServerAPIClient` needs, and performs 401 →
//  refresh → retry. No real secrets are baked in; the access token comes from
//  the server and is stored in the device Keychain only.
//

import Foundation
import Security

/// The persisted auth session.
struct KAirStoredSession: Codable, Hashable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
}

/// Token persistence boundary. Keychain in production; in-memory in tests.
protocol KAirSessionStore: Sendable {
    func load() throws -> KAirStoredSession?
    func save(_ session: KAirStoredSession) throws
    func clear() throws
}

/// Non-persistent store for tests and previews.
final class InMemoryKAirSessionStore: KAirSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: KAirStoredSession?

    init(session: KAirStoredSession? = nil) {
        self.session = session
    }

    func load() throws -> KAirStoredSession? {
        lock.lock(); defer { lock.unlock() }
        return session
    }

    func save(_ session: KAirStoredSession) throws {
        lock.lock(); defer { lock.unlock() }
        self.session = session
    }

    func clear() throws {
        lock.lock(); defer { lock.unlock() }
        session = nil
    }
}

enum KAirKeychainError: Error {
    case unexpectedStatus(OSStatus)
}

/// Keychain-backed store. Tokens are stored as a single generic-password item,
/// `AfterFirstUnlockThisDeviceOnly` (available post-unlock, never synced/exported).
final class KeychainKAirSessionStore: KAirSessionStore, @unchecked Sendable {
    private let service: String
    private let account: String

    init(service: String = "app.kair.session", account: String = "default") {
        self.service = service
        self.account = account
    }

    func load() throws -> KAirStoredSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KAirKeychainError.unexpectedStatus(status)
        }
        return try JSONDecoder().decode(KAirStoredSession.self, from: data)
    }

    func save(_ session: KAirStoredSession) throws {
        let data = try JSONEncoder().encode(session)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var insert = baseQuery()
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KAirKeychainError.unexpectedStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KAirKeychainError.unexpectedStatus(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KAirKeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// Source of an App Attest assertion. Real `DCAppAttestService` is device-only
/// and lands in a later round; this seam keeps the header honest (nil → no
/// `X-App-Attest`). Never fabricates an assertion.
protocol KAirAppAttestProvider: Sendable {
    func assertion() async -> String?
}

struct NoopKAirAppAttestProvider: KAirAppAttestProvider {
    func assertion() async -> String? { nil }
}

/// Owns the auth session. Observable so SwiftUI can react to sign-in state.
/// No UI, no networking of its own beyond `refresh`/`withAutoRefresh`.
@MainActor
@Observable
final class KAirAuthSessionManager {
    enum State: Hashable, Sendable {
        case signedOut
        case signedIn
    }

    private(set) var state: State

    private let store: KAirSessionStore
    private let attestProvider: KAirAppAttestProvider
    private let now: @Sendable () -> Date
    private var current: KAirStoredSession?

    init(
        store: KAirSessionStore,
        attestProvider: KAirAppAttestProvider = NoopKAirAppAttestProvider(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.attestProvider = attestProvider
        self.now = now
        let loaded = (try? store.load()) ?? nil
        self.current = loaded
        self.state = loaded == nil ? .signedOut : .signedIn
    }

    var isSignedIn: Bool { state == .signedIn }
    func accessToken() -> String? { current?.accessToken }
    var refreshToken: String? { current?.refreshToken }

    /// Whether the access token is at/after its expiry (for proactive refresh).
    var isAccessTokenExpired: Bool {
        guard let expiresAt = current?.accessTokenExpiresAt else { return true }
        return now() >= expiresAt
    }

    /// The credentials closure for `KAirServerAPIClient`. Reads the *current*
    /// token on each call (so a post-refresh token is picked up) and the live
    /// App Attest assertion. Captures `self` weakly.
    func credentialsProvider() -> @Sendable () async -> KAirServerCredentials {
        let attestProvider = self.attestProvider
        return { [weak self] in
            let token: String?
            if let self {
                token = await self.accessToken()
            } else {
                token = nil
            }
            let assertion = await attestProvider.assertion()
            return KAirServerCredentials(accessToken: token, appAttestAssertion: assertion)
        }
    }

    /// Persist a fresh token pair and move to signed-in.
    func apply(_ pair: KAirAuthTokenPair) {
        let session = KAirStoredSession(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            accessTokenExpiresAt: now().addingTimeInterval(TimeInterval(pair.expiresIn))
        )
        current = session
        try? store.save(session)
        state = .signedIn
    }

    /// Clear the session.
    func signOut() {
        current = nil
        try? store.clear()
        state = .signedOut
    }

    /// Refresh the access token. Applies the new pair, or signs out + throws on
    /// failure (a failed refresh is terminal — the user must re-authenticate).
    func refresh(using client: KAirServerAPIClient) async throws {
        guard let refreshToken = current?.refreshToken else {
            signOut()
            throw KAirServerAPIClientError.missingAccessToken
        }
        do {
            let pair = try await client.refresh(refreshToken: refreshToken)
            apply(pair)
        } catch {
            signOut()
            throw error
        }
    }

    /// Run an authenticated operation, retrying once after a 401 by refreshing
    /// the token. If the refresh itself fails, the session is signed out and
    /// the error propagates (no retry).
    func withAutoRefresh<T>(
        client: KAirServerAPIClient,
        _ operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch let KAirServerAPIClientError.api(statusCode, _) where statusCode == 401 {
            try await refresh(using: client)
            return try await operation()
        }
    }

    /// Delete the account on the server, then clear the local session. Retries
    /// once after a 401 (token refresh). A successful delete always signs out.
    func deleteAccount(using client: KAirServerAPIClient) async throws {
        try await withAutoRefresh(client: client) {
            try await client.deleteAccount()
        }
        signOut()
    }
}
