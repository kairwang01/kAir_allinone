//
//  KAirServerConfiguration.swift
//  kAir
//
//  App-root server endpoint configuration. The base URL is environment-specific
//  and read from the Info.plist key `KAIR_SERVER_BASE_URL` (set via build
//  settings); the in-source value is only a placeholder host reached once a
//  server flag is on. Consumed only when server features are enabled
//  (`FeatureFlag.serverAuthEnabled` / `serverProvidersEnabled`); in the
//  local-first v1 it is never reached.
//

import Foundation

struct KAirServerConfiguration: Sendable, Hashable {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// App-root default. Reads `KAIR_SERVER_BASE_URL` from the bundle when set,
    /// else a placeholder that is only reached once a server feature flag is on.
    static let `default`: KAirServerConfiguration = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "KAIR_SERVER_BASE_URL") as? String,
           raw.isEmpty == false,
           let url = URL(string: raw) {
            return KAirServerConfiguration(baseURL: url)
        }
        return KAirServerConfiguration(baseURL: URL(string: "https://api.kair.app/v1")!)
    }()

    /// Builds a credentialed API client bound to a session manager so requests
    /// carry the current access token (and pick up post-refresh tokens).
    @MainActor
    func makeClient(authSession: KAirAuthSessionManager) -> KAirServerAPIClient {
        KAirServerAPIClient(baseURL: baseURL, credentials: authSession.credentialsProvider())
    }
}
