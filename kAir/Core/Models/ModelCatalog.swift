//
//  ModelCatalog.swift
//  kAir
//
//  Pure value contract for the model catalog (entries + roles + fixtures).
//
//  A3 model-catalog value contracts (kair-ai-model-memory-v1.md §1 roles, §5
//  catalog). Foundation only — fixtures, no network, no StoreKit, no model
//  runtime. Catalog metadata is NOT entitlement proof (§5): a paid model is
//  gated through `ModelEntitlementPolicy`, and a `downloadURL` is untrusted
//  without a `checksum` + `signature`.
//

import Foundation

/// A model's typed role in the kAir model memory (§1). Every model is a
/// purpose-built role, never a generic chatbot.
enum ModelRole: String, Codable, Hashable, Sendable, CaseIterable {
    /// Local intent router — fast, cheap, on-device (§1).
    case router
    /// Local action planner — structured tool/slot plans (§1).
    case planner
    /// Local embedder — retrieval / semantic memory (§1).
    case embedder
    /// Health specialist — local-only by contract (§1; PrivacyGuard
    /// `.healthDataMustNotReachRemoteModel`).
    case health
    /// Premium market model — server-gated, paid, remote (§1, §7).
    case premium

    /// Health specialist models are local-only and may never target a remote
    /// runtime family (§1). The catalog and entitlement policy both enforce it.
    var isLocalOnly: Bool {
        self == .health
    }
}

/// One curated model catalog entry (§5). Metadata only — visibility here does
/// not imply the model is entitled, installable on this device, or installed.
struct ModelCatalogEntry: Codable, Hashable, Sendable, Identifiable {
    /// Stable model id (e.g. "local-router-v1").
    let id: String
    /// User-facing name.
    let displayName: String
    /// Typed role (§1).
    let role: ModelRole
    /// Runtime family (§4).
    let runtimeFamily: ModelRuntimeFamily
    /// Catalog version string.
    let version: String
    /// BCP-47 language tags the model supports.
    let languageSupport: [String]
    /// Task tags the model supports (e.g. "routing", "summarize").
    let taskSupport: [String]
    /// On-disk footprint once installed.
    let diskSizeBytes: Int64
    /// Peak estimated working-set memory.
    let estimatedMemoryBytes: Int64
    /// Minimum device class label (e.g. "A17", "M-series").
    let minimumDeviceClass: String
    /// Minimum OS string (e.g. "17.0").
    let minimumOS: String
    /// Download source — `nil` for a bundled model. Untrusted without
    /// `checksum` + `signature` (§5).
    let downloadURL: URL?
    /// Expected content checksum (verify step).
    let checksum: String?
    /// Expected signature (verify step).
    let signature: String?
    /// License identifier.
    let license: String
    /// StoreKit product id for a paid model, or `nil` for a free/bundled model.
    /// This is a product identifier — never an API key (§5 forbidden).
    let priceProductID: String?
    /// Privacy classes this model is allowed to process (e.g. "general").
    /// Health/private classes stay local-only (§1).
    let privacyClassAllowed: [String]
    /// Whether the model can stream tokens.
    let supportsStreaming: Bool
    /// Whether the model can emit structured (JSON) output.
    let supportsStructuredOutput: Bool
    /// Whether the model can call tools.
    let supportsToolCalling: Bool
    /// Short, user-visible status copy (§5 statusCopy; §16 — no diagnostics).
    let statusCopy: String

    init(
        id: String,
        displayName: String,
        role: ModelRole,
        runtimeFamily: ModelRuntimeFamily,
        version: String,
        diskSizeBytes: Int64,
        estimatedMemoryBytes: Int64,
        minimumDeviceClass: String,
        minimumOS: String,
        license: String,
        statusCopy: String,
        languageSupport: [String] = [],
        taskSupport: [String] = [],
        downloadURL: URL? = nil,
        checksum: String? = nil,
        signature: String? = nil,
        priceProductID: String? = nil,
        privacyClassAllowed: [String] = [],
        supportsStreaming: Bool = false,
        supportsStructuredOutput: Bool = false,
        supportsToolCalling: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.runtimeFamily = runtimeFamily
        self.version = version
        self.diskSizeBytes = diskSizeBytes
        self.estimatedMemoryBytes = estimatedMemoryBytes
        self.minimumDeviceClass = minimumDeviceClass
        self.minimumOS = minimumOS
        self.license = license
        self.statusCopy = statusCopy
        self.languageSupport = languageSupport
        self.taskSupport = taskSupport
        self.downloadURL = downloadURL
        self.checksum = checksum
        self.signature = signature
        self.priceProductID = priceProductID
        self.privacyClassAllowed = privacyClassAllowed
        self.supportsStreaming = supportsStreaming
        self.supportsStructuredOutput = supportsStructuredOutput
        self.supportsToolCalling = supportsToolCalling
    }

    /// A paid model carries a StoreKit product id; download is gated through
    /// `ModelEntitlementPolicy` (§7). Free/bundled models have no product id.
    var isPaid: Bool {
        priceProductID != nil
    }

    /// Health-role models must run on-device (§1 local-only). A health entry on
    /// `.remoteGateway` violates the privacy contract and is invalid.
    var respectsHealthLocalOnly: Bool {
        role.isLocalOnly == false || runtimeFamily.isOnDevice
    }

    /// A downloadable entry is only trustworthy with both a checksum and a
    /// signature (§5). Bundled entries (no URL) are trivially trusted.
    var hasTrustedDownloadSource: Bool {
        guard downloadURL != nil else { return true }
        return (checksum?.isEmpty == false) && (signature?.isEmpty == false)
    }
}

/// Fixture catalog for A3. Real catalog loading (bundled snapshot + remote
/// snapshot merge) lands later behind a provider; this proves the value
/// contract and lets the Model Library bind without hardcoded cards.
enum ModelCatalog {
    /// id of the local intent router (§1).
    static let localRouterID = "local-router-v1"
    /// id of the local action planner (§1).
    static let localPlannerID = "local-planner-v1"
    /// id of the local embedder (§1).
    static let localEmbedderID = "local-embedder-v1"
    /// id of the local Health specialist — local-only (§1).
    static let healthSpecialistID = "health-local-specialist-v1"
    /// id of the paid premium market model — remote, StoreKit-gated (§1, §7).
    static let premiumMarketID = "market-large-model-v1"

    /// All fixture entries. Covers free/bundled, free/downloadable, local-only
    /// Health, and a paid remote premium model.
    static let fixtures: [ModelCatalogEntry] = [
        // Free, bundled with the app (no download URL → trivially trusted).
        ModelCatalogEntry(
            id: localRouterID,
            displayName: "Local Router",
            role: .router,
            runtimeFamily: .foundationModels,
            version: "1.0.0",
            diskSizeBytes: 180_000_000,
            estimatedMemoryBytes: 320_000_000,
            minimumDeviceClass: "A16",
            minimumOS: "17.0",
            license: "proprietary-bundled",
            statusCopy: "随应用内置，用于本地意图分流。",
            languageSupport: ["zh-Hans", "en"],
            taskSupport: ["routing", "classification"],
            privacyClassAllowed: ["general", "private"],
            supportsStructuredOutput: true,
            supportsToolCalling: true
        ),
        // Free, downloadable (URL + checksum + signature → trusted source).
        ModelCatalogEntry(
            id: localPlannerID,
            displayName: "Local Planner",
            role: .planner,
            runtimeFamily: .coreML,
            version: "1.0.0",
            diskSizeBytes: 1_300_000_000,
            estimatedMemoryBytes: 1_600_000_000,
            minimumDeviceClass: "A16",
            minimumOS: "17.0",
            license: "apache-2.0",
            statusCopy: "下载后用于生成本地动作计划。",
            languageSupport: ["zh-Hans", "en"],
            taskSupport: ["planning", "tool-use"],
            downloadURL: URL(string: "https://models.kair.local/local-planner-v1.mlpackage"),
            checksum: "sha256:planner-fixture-checksum",
            signature: "ed25519:planner-fixture-signature",
            privacyClassAllowed: ["general", "private"],
            supportsStructuredOutput: true,
            supportsToolCalling: true
        ),
        // Free, downloadable embedder.
        ModelCatalogEntry(
            id: localEmbedderID,
            displayName: "Local Embedder",
            role: .embedder,
            runtimeFamily: .coreML,
            version: "1.0.0",
            diskSizeBytes: 90_000_000,
            estimatedMemoryBytes: 160_000_000,
            minimumDeviceClass: "A15",
            minimumOS: "17.0",
            license: "mit",
            statusCopy: "下载后用于本地语义检索。",
            languageSupport: ["zh-Hans", "en"],
            taskSupport: ["embedding", "retrieval"],
            downloadURL: URL(string: "https://models.kair.local/local-embedder-v1.mlpackage"),
            checksum: "sha256:embedder-fixture-checksum",
            signature: "ed25519:embedder-fixture-signature",
            privacyClassAllowed: ["general", "private"]
        ),
        // Health specialist — local-only by contract (§1). On-device runtime,
        // no product id, no remote fallback.
        ModelCatalogEntry(
            id: healthSpecialistID,
            displayName: "Health Specialist",
            role: .health,
            runtimeFamily: .coreML,
            version: "1.0.0",
            diskSizeBytes: 780_000_000,
            estimatedMemoryBytes: 900_000_000,
            minimumDeviceClass: "A16",
            minimumOS: "17.0",
            license: "proprietary-local",
            statusCopy: "仅在本机运行，健康数据不出设备。",
            languageSupport: ["zh-Hans", "en"],
            taskSupport: ["health-summary", "trend-scoring"],
            downloadURL: URL(string: "https://models.kair.local/health-local-specialist-v1.mlpackage"),
            checksum: "sha256:health-fixture-checksum",
            signature: "ed25519:health-fixture-signature",
            privacyClassAllowed: ["health"]
        ),
        // Paid premium market model — remote gateway, StoreKit-gated (§7).
        // No download URL: it runs server-side via the (not-yet-wired) remote
        // gateway. Entitlement is required before any access (§6, §7).
        ModelCatalogEntry(
            id: premiumMarketID,
            displayName: "Market Large Model",
            role: .premium,
            runtimeFamily: .remoteGateway,
            version: "1.0.0",
            diskSizeBytes: 0,
            estimatedMemoryBytes: 0,
            minimumDeviceClass: "any",
            minimumOS: "17.0",
            license: "commercial",
            statusCopy: "付费后由服务器侧网关提供，需购买解锁。",
            languageSupport: ["zh-Hans", "en", "ja"],
            taskSupport: ["long-context", "reasoning"],
            priceProductID: "com.kair.model.market_large_model",
            privacyClassAllowed: ["general"],
            supportsStreaming: true,
            supportsStructuredOutput: true,
            supportsToolCalling: true
        ),
    ]

    /// Lookup a fixture entry by id.
    static func entry(id: String) -> ModelCatalogEntry? {
        fixtures.first { $0.id == id }
    }
}
