//
//  KAirServerAPIClient.swift
//  kAir
//
//  Typed client boundary for the kAir-owned backend /v1 contract.
//

import Foundation

protocol KAirHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionKAirHTTPClient: KAirHTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KAirServerAPIClientError.invalidResponse
        }
        return (data, httpResponse)
    }
}

struct KAirServerCredentials: Sendable, Hashable {
    let accessToken: String?
    let appAttestAssertion: String?

    init(accessToken: String? = nil, appAttestAssertion: String? = nil) {
        self.accessToken = accessToken
        self.appAttestAssertion = appAttestAssertion
    }
}

struct KAirServerAPIClient: Sendable {
    let baseURL: URL
    let httpClient: KAirHTTPClient
    let credentials: @Sendable () async -> KAirServerCredentials

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        httpClient: KAirHTTPClient = URLSessionKAirHTTPClient(),
        credentials: @escaping @Sendable () async -> KAirServerCredentials = { KAirServerCredentials() }
    ) {
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.credentials = credentials
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func register(email: String, password: String) async throws -> KAirRegisterResponse {
        try await send(
            method: .post,
            path: "auth/register",
            body: KAirEmailPasswordRequest(email: email, password: password),
            requiresAuth: false
        )
    }

    func login(email: String, password: String) async throws -> KAirAuthTokenPair {
        try await send(
            method: .post,
            path: "auth/login",
            body: KAirEmailPasswordRequest(email: email, password: password),
            requiresAuth: false
        )
    }

    func refresh(refreshToken: String) async throws -> KAirAuthTokenPair {
        try await send(
            method: .post,
            path: "auth/refresh",
            body: KAirRefreshRequest(refreshToken: refreshToken),
            requiresAuth: false
        )
    }

    func me() async throws -> KAirMe {
        try await send(
            method: .get,
            path: "me",
            body: Optional<KAirEmptyRequest>.none,
            requiresAuth: true
        )
    }

    func entitlements() async throws -> KAirEntitlementSnapshot {
        try await send(
            method: .get,
            path: "me/entitlements",
            body: Optional<KAirEmptyRequest>.none,
            requiresAuth: true
        )
    }

    /// Account deletion (App Store Guideline 5.1.1(v)). `DELETE /v1/me` → 202:
    /// the server erases all account data and revokes Sign in with Apple tokens.
    func deleteAccount() async throws {
        try await sendExpectingNoContent(method: .delete, path: "me", requiresAuth: true)
    }

    func postMaps<Result: Decodable>(
        envelope: KAirProviderEnvelope,
        query: KAirMapsQuery,
        resultType: Result.Type = Result.self,
        idempotencyKey: String
    ) async throws -> KAirProviderResult<Result> {
        try await send(
            method: .post,
            path: "kair/maps",
            body: KAirProviderRequestBody(envelope: envelope, query: query),
            requiresAuth: true,
            idempotencyKey: idempotencyKey,
            traceID: envelope.traceId
        )
    }

    func postSearch<Result: Decodable>(
        envelope: KAirProviderEnvelope,
        query: KAirSearchQuery,
        resultType: Result.Type = Result.self,
        idempotencyKey: String
    ) async throws -> KAirProviderResult<Result> {
        try await send(
            method: .post,
            path: "kair/search",
            body: KAirProviderRequestBody(envelope: envelope, query: query),
            requiresAuth: true,
            idempotencyKey: idempotencyKey,
            traceID: envelope.traceId
        )
    }

    func postModel(
        envelope: KAirProviderEnvelope,
        query: KAirModelQuery,
        idempotencyKey: String,
        estimatedUnits: Int = 1
    ) async throws -> KAirProviderResult<KAirModelCompletion> {
        try await send(
            method: .post,
            path: "kair/model",
            body: KAirProviderRequestBody(
                envelope: envelope,
                query: query,
                estimatedUnits: estimatedUnits
            ),
            requiresAuth: true,
            idempotencyKey: idempotencyKey,
            traceID: envelope.traceId
        )
    }

    private func send<Response: Decodable, Body: Encodable>(
        method: KAirHTTPMethod,
        path: String,
        body: Body?,
        requiresAuth: Bool,
        idempotencyKey: String? = nil,
        traceID: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        if let traceID {
            request.setValue(traceID, forHTTPHeaderField: "X-Trace-Id")
        }

        let credentials = await credentials()
        if let appAttestAssertion = credentials.appAttestAssertion,
           appAttestAssertion.isEmpty == false {
            request.setValue(appAttestAssertion, forHTTPHeaderField: "X-App-Attest")
        }
        if requiresAuth {
            guard let accessToken = credentials.accessToken,
                  accessToken.isEmpty == false else {
                throw KAirServerAPIClientError.missingAccessToken
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await httpClient.data(for: request)
        if (200..<300).contains(response.statusCode) {
            return try decoder.decode(Response.self, from: data)
        }

        let apiError = (try? decoder.decode(KAirAPIErrorEnvelope.self, from: data).error)
            ?? KAirAPIError(
                code: "http.\(response.statusCode)",
                message: "Request failed with status \(response.statusCode).",
                traceId: traceID ?? ""
            )
        throw KAirServerAPIClientError.api(statusCode: response.statusCode, error: apiError)
    }

    /// Like `send`, for 2xx no-content responses (202/204). Applies the same
    /// auth / attestation headers; decodes nothing on success.
    private func sendExpectingNoContent(
        method: KAirHTTPMethod,
        path: String,
        requiresAuth: Bool
    ) async throws {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let credentials = await credentials()
        if let appAttestAssertion = credentials.appAttestAssertion,
           appAttestAssertion.isEmpty == false {
            request.setValue(appAttestAssertion, forHTTPHeaderField: "X-App-Attest")
        }
        if requiresAuth {
            guard let accessToken = credentials.accessToken,
                  accessToken.isEmpty == false else {
                throw KAirServerAPIClientError.missingAccessToken
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await httpClient.data(for: request)
        if (200..<300).contains(response.statusCode) {
            return
        }
        let apiError = (try? decoder.decode(KAirAPIErrorEnvelope.self, from: data).error)
            ?? KAirAPIError(
                code: "http.\(response.statusCode)",
                message: "Request failed with status \(response.statusCode).",
                traceId: ""
            )
        throw KAirServerAPIClientError.api(statusCode: response.statusCode, error: apiError)
    }

    private func url(for path: String) -> URL {
        path
            .split(separator: "/")
            .reduce(baseURL) { partialURL, component in
                partialURL.appendingPathComponent(String(component))
            }
    }
}

enum KAirServerAPIClientError: Error {
    case invalidResponse
    case missingAccessToken
    case api(statusCode: Int, error: KAirAPIError)
}

private enum KAirHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

private struct KAirEmptyRequest: Encodable {}

private struct KAirEmailPasswordRequest: Encodable {
    let email: String
    let password: String
}

private struct KAirRefreshRequest: Encodable {
    let refreshToken: String
}

private struct KAirProviderRequestBody<Query: Encodable>: Encodable {
    let envelope: KAirProviderEnvelope
    let query: Query
    let estimatedUnits: Int?

    init(envelope: KAirProviderEnvelope, query: Query, estimatedUnits: Int? = nil) {
        self.envelope = envelope
        self.query = query
        self.estimatedUnits = estimatedUnits
    }
}

struct KAirRegisterResponse: Codable, Hashable, Sendable {
    let userId: String
}

struct KAirAuthTokenPair: Codable, Hashable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

struct KAirMe: Codable, Hashable, Sendable {
    let userId: String
    let tenant: String
    let email: String?
    let roles: [String]
    let membershipTier: MembershipTier
    let createdAt: String
}

struct KAirAPIErrorEnvelope: Codable, Sendable {
    let error: KAirAPIError
}

struct KAirAPIError: Codable, Sendable {
    let code: String
    let message: String
    let traceId: String
    let details: [String: KAirJSONValue]?

    init(
        code: String,
        message: String,
        traceId: String,
        details: [String: KAirJSONValue]? = nil
    ) {
        self.code = code
        self.message = message
        self.traceId = traceId
        self.details = details
    }
}

enum KAirEntitlementStatus: String, Codable, Hashable, Sendable {
    case active
    case grace
    case expired
}

struct KAirEntitlementSnapshot: Codable, Hashable, Sendable {
    let membershipTier: MembershipTier
    let status: KAirEntitlementStatus
    let currentPeriodEnd: String?
    let entitlements: [KAirEntitlement]
    let quotas: [KAirQuota]
    let sourceAt: String

    func providerAccessProfile(
        defaultRegion: ProviderRegion = .global,
        preferredProvider: ProviderFamily? = nil
    ) -> ProviderAccessProfile {
        ProviderAccessProfile(
            membershipTier: membershipTier,
            defaultRegion: defaultRegion,
            preferredProvider: preferredProvider,
            meteredProviderEntitlements: meteredEligibleFamilies,
            unavailableProviders: disabledFamilies
        )
    }

    func providerQuotaSnapshot() -> ServerProviderQuotaSnapshot {
        ServerProviderQuotaSnapshot(
            allowedProviderFamilies: Set<ProviderFamily>([.appleLocal, .cache]).union(allowedFamilies),
            entitledProviderFamilies: allowedFamilies,
            remainingIncludedQuota: Dictionary(
                uniqueKeysWithValues: quotas.compactMap { quota in
                    guard let providerFamily = quota.providerFamily.providerFamily else {
                        return nil
                    }
                    return (providerFamily, quota.remainingUnits)
                }
            ),
            meteredEligibleProviderFamilies: meteredEligibleFamilies,
            disabledProviderFamilies: disabledFamilies
        )
    }

    private var allowedFamilies: Set<ProviderFamily> {
        Set(
            entitlements.compactMap { entitlement in
                guard entitlement.allowed else {
                    return nil
                }
                return entitlement.providerFamily.providerFamily
            }
        )
    }

    private var meteredEligibleFamilies: Set<ProviderFamily> {
        Set(
            entitlements.compactMap { entitlement in
                guard entitlement.allowed, entitlement.meteredEligible else {
                    return nil
                }
                return entitlement.providerFamily.providerFamily
            }
        )
    }

    private var disabledFamilies: Set<ProviderFamily> {
        Set(
            entitlements.compactMap { entitlement in
                guard entitlement.allowed == false else {
                    return nil
                }
                return entitlement.providerFamily.providerFamily
            }
        )
    }
}

struct KAirEntitlement: Codable, Hashable, Sendable {
    let providerFamily: KAirAPIProviderFamily
    let capability: KAirAPIProviderCapability
    let allowed: Bool
    let includedQuota: Int
    let meteredEligible: Bool
}

struct KAirQuota: Codable, Hashable, Sendable {
    let providerFamily: KAirAPIProviderFamily
    let periodId: String
    let includedUnits: Int
    let usedUnits: Int
    let remainingUnits: Int
}

enum KAirAPIProviderFamily: String, Codable, Hashable, Sendable, CaseIterable {
    case appleLocal
    case gaode
    case googleMaps
    case searchAPI
    case researchAPI
    case modelGateway
    case crawler
    case mcp
    case cache

    nonisolated init(providerFamily: ProviderFamily) {
        switch providerFamily {
        case .appleLocal: self = .appleLocal
        case .gaode: self = .gaode
        case .googleMaps: self = .googleMaps
        case .searchAPI: self = .searchAPI
        case .crawler: self = .crawler
        case .mcp: self = .mcp
        case .cache: self = .cache
        }
    }

    nonisolated var providerFamily: ProviderFamily? {
        switch self {
        case .appleLocal: return .appleLocal
        case .gaode: return .gaode
        case .googleMaps: return .googleMaps
        case .searchAPI: return .searchAPI
        case .crawler: return .crawler
        case .mcp: return .mcp
        case .cache: return .cache
        case .researchAPI, .modelGateway: return nil
        }
    }
}

enum KAirAPIProviderCapability: String, Codable, Hashable, Sendable, CaseIterable {
    case mapDisplay
    case placeSearch
    case routePlanning
    case webSearch
    case localServiceSearch
    case scholarlySearch
    case citationLookup
    case aiCompletion
    case chatCompletion
    case crawlerFetch
    case mcpTool

    nonisolated init(providerCapability: ProviderCapability) {
        switch providerCapability {
        case .mapDisplay: self = .mapDisplay
        case .placeSearch: self = .placeSearch
        case .routePlanning: self = .routePlanning
        case .webSearch: self = .webSearch
        case .localServiceSearch: self = .localServiceSearch
        case .crawlerFetch: self = .crawlerFetch
        case .mcpTool: self = .mcpTool
        }
    }
}

enum KAirAPIConfirmationState: String, Codable, Hashable, Sendable {
    case notRequired
    case required
    case confirmed

    nonisolated init(confirmationState: ServerConfirmationState) {
        switch confirmationState {
        case .notRequired:
            self = .notRequired
        case .requiredMissing:
            self = .required
        case .confirmed:
            self = .confirmed
        }
    }
}

struct KAirProviderEnvelope: Codable, Hashable, Sendable {
    let traceId: String
    let capability: KAirAPIProviderCapability
    let providerFamily: KAirAPIProviderFamily
    let privacyClass: ProviderPrivacyClass
    let region: ProviderRegion
    let membershipTier: MembershipTier?
    let costClass: ProviderCostClass?
    let freshness: ProviderFreshness
    let preferredProvider: KAirAPIProviderFamily?
    let confirmationState: KAirAPIConfirmationState

    init(
        traceId: String,
        capability: KAirAPIProviderCapability,
        providerFamily: KAirAPIProviderFamily,
        privacyClass: ProviderPrivacyClass = .general,
        region: ProviderRegion = .global,
        membershipTier: MembershipTier? = nil,
        costClass: ProviderCostClass? = nil,
        freshness: ProviderFreshness = .cachedOK,
        preferredProvider: KAirAPIProviderFamily? = nil,
        confirmationState: KAirAPIConfirmationState = .notRequired
    ) {
        self.traceId = traceId
        self.capability = capability
        self.providerFamily = providerFamily
        self.privacyClass = privacyClass
        self.region = region
        self.membershipTier = membershipTier
        self.costClass = costClass
        self.freshness = freshness
        self.preferredProvider = preferredProvider
        self.confirmationState = confirmationState
    }

    init(
        serverEnvelope: ServerProviderEnvelope,
        region: ProviderRegion,
        preferredProvider: ProviderFamily? = nil
    ) {
        self.init(
            traceId: serverEnvelope.traceID,
            capability: KAirAPIProviderCapability(providerCapability: serverEnvelope.capability),
            providerFamily: KAirAPIProviderFamily(providerFamily: serverEnvelope.providerFamily),
            privacyClass: serverEnvelope.privacyClass,
            region: region,
            membershipTier: serverEnvelope.membershipTier,
            costClass: serverEnvelope.costClass,
            freshness: serverEnvelope.freshness,
            preferredProvider: preferredProvider.map { KAirAPIProviderFamily(providerFamily: $0) },
            confirmationState: KAirAPIConfirmationState(confirmationState: serverEnvelope.confirmationState)
        )
    }
}

struct KAirProviderTrace: Codable, Hashable, Sendable {
    let traceId: String
    let capability: KAirAPIProviderCapability
    let selectedProviderId: String?
    let selectedProviderFamily: KAirAPIProviderFamily?
    let costClass: ProviderCostClass
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let freshness: ProviderFreshness
    let latencyMs: Int
    let resultCount: Int
    let failureReason: String?
}

struct KAirProviderResult<Result: Decodable>: Decodable {
    let result: Result?
    let blocked: KAirProviderBlocked?
    let citations: [KAirCitation]?
    let limitations: [String]?
    let trace: KAirProviderTrace
}

struct KAirProviderBlocked: Codable, Hashable, Sendable {
    let reason: KAirProviderBlockedReason
    let message: String
}

enum KAirProviderBlockedReason: Hashable, Sendable {
    case blockedByPrivacy
    case blockedByCost
    case missingSnapshot
    case vendorDisabled
    case membershipMissing
    case privacyBlocked
    case overQuota
    case staleSnapshot
    case capabilityMismatch
    case alreadyReserved
    case other(String)

    var rawValue: String {
        switch self {
        case .blockedByPrivacy:  return "blockedByPrivacy"
        case .blockedByCost:     return "blockedByCost"
        case .missingSnapshot:   return "missingSnapshot"
        case .vendorDisabled:    return "vendorDisabled"
        case .membershipMissing: return "membershipMissing"
        case .privacyBlocked:    return "privacyBlocked"
        case .overQuota:         return "overQuota"
        case .staleSnapshot:     return "staleSnapshot"
        case .capabilityMismatch: return "capabilityMismatch"
        case .alreadyReserved:   return "alreadyReserved"
        case .other(let value):  return value
        }
    }
}

extension KAirProviderBlockedReason: Codable {
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "blockedByPrivacy":  self = .blockedByPrivacy
        case "blockedByCost":     self = .blockedByCost
        case "missingSnapshot":   self = .missingSnapshot
        case "vendorDisabled":    self = .vendorDisabled
        case "membershipMissing": self = .membershipMissing
        case "privacyBlocked":    self = .privacyBlocked
        case "overQuota":         self = .overQuota
        case "staleSnapshot":     self = .staleSnapshot
        case "capabilityMismatch": self = .capabilityMismatch
        case "alreadyReserved":   self = .alreadyReserved
        default:                  self = .other(rawValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct KAirCitation: Codable, Hashable, Sendable {
    let title: String
    let url: URL
    let sourceId: String
    let doi: String?
    let publishedAt: String?
}

struct KAirMapsQuery: Codable, Hashable, Sendable {
    let text: String
    let region: ProviderRegion?

    init(text: String, region: ProviderRegion? = nil) {
        self.text = text
        self.region = region
    }
}

struct KAirSearchQuery: Codable, Hashable, Sendable {
    let text: String
    let maxResults: Int?
    let region: ProviderRegion?

    init(text: String, maxResults: Int? = nil, region: ProviderRegion? = nil) {
        self.text = text
        self.maxResults = maxResults
        self.region = region
    }
}

struct KAirModelQuery: Codable, Hashable, Sendable {
    let text: String
    let region: ProviderRegion?

    init(text: String, region: ProviderRegion? = nil) {
        self.text = text
        self.region = region
    }
}

struct KAirModelCompletion: Codable, Hashable, Sendable {
    let message: String
    let model: String?
    let finishReason: String?
    let usage: KAirModelUsage?
}

struct KAirModelUsage: Codable, Hashable, Sendable {
    let promptTokens: Int?
    let completionTokens: Int?
    let reasoningTokens: Int?
    let totalTokens: Int?
}

enum KAirJSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: KAirJSONValue])
    case array([KAirJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: KAirJSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([KAirJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
