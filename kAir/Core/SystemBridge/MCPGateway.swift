//
//  MCPGateway.swift
//  kAir
//
//  Comment-first scaffold for future Model Context Protocol integration.
//

import Foundation

/// Reserved Model Context Protocol gateway contracts for
/// `Docs/architecture/kair-provider-routing-mcp-search-v1.md` §7.
///
/// This file contains no MCP client, server connection, network transport, or
/// tool execution. It only decides whether a future MCP descriptor would be
/// allowed, blocked, or require confirmation.
enum MCPFeature: String, Codable, Hashable, Sendable, CaseIterable {
    case tool
    case resource
    case prompt
    case completion
    case elicitation
    case oauth
}

enum MCPRiskClass: String, Codable, Hashable, Sendable, CaseIterable {
    case read
    case write
    case pay
    case share
    case externalOpen

    var requiresConfirmation: Bool {
        switch self {
        case .read:
            return false
        case .write, .pay, .share, .externalOpen:
            return true
        }
    }
}

enum MCPDescriptorTrust: String, Codable, Hashable, Sendable, CaseIterable {
    case known
    case signed
    case unknown
}

enum MCPResourceDomain: String, Codable, Hashable, Sendable, CaseIterable {
    case general
    case `private`
    case health
}

enum MCPGatewayDenialReason: String, Codable, Hashable, Sendable, CaseIterable {
    case unknownServer
    case serverDisabled
    case untrustedDescriptor
    case toolNotAllowlisted
    case resourceNotAllowlisted
    case promptNotAllowlisted
    case healthResourceBlocked
    case healthPromptBlocked
    case confirmationRequired
}

struct MCPServerDescriptor: Codable, Hashable, Sendable, Identifiable {
    let serverID: String
    let displayName: String
    let isEnabled: Bool
    let descriptorTrust: MCPDescriptorTrust
    let allowedToolIDs: Set<String>
    let allowedResourceIDs: Set<String>
    let allowedPromptIDs: Set<String>

    var id: String { serverID }

    init(
        serverID: String,
        displayName: String,
        isEnabled: Bool,
        descriptorTrust: MCPDescriptorTrust,
        allowedToolIDs: Set<String>,
        allowedResourceIDs: Set<String>,
        allowedPromptIDs: Set<String> = []
    ) {
        self.serverID = serverID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.descriptorTrust = descriptorTrust
        self.allowedToolIDs = allowedToolIDs
        self.allowedResourceIDs = allowedResourceIDs
        self.allowedPromptIDs = allowedPromptIDs
    }
}

struct MCPToolDescriptor: Codable, Hashable, Sendable, Identifiable {
    let serverID: String
    let toolID: String
    let displayName: String
    let riskClasses: Set<MCPRiskClass>
    let isReadOnlyHint: Bool

    var id: String { "\(serverID):\(toolID)" }

    var requiresConfirmation: Bool {
        isReadOnlyHint == false || riskClasses.contains(where: \.requiresConfirmation)
    }
}

struct MCPResourceDescriptor: Codable, Hashable, Sendable, Identifiable {
    let serverID: String
    let resourceID: String
    let displayName: String
    let domain: MCPResourceDomain

    var id: String { "\(serverID):\(resourceID)" }
}

/// Reserved MCP prompt template descriptor. This models prompt discovery and
/// allowlisting only; it does not render, sample, or forward the prompt.
struct MCPPromptDescriptor: Codable, Hashable, Sendable, Identifiable {
    let serverID: String
    let promptID: String
    let displayName: String
    let argumentNames: [String]
    let domain: MCPResourceDomain
    let requiresUserReview: Bool

    var id: String { "\(serverID):\(promptID)" }
}

struct MCPConfirmationArtifact: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let confirmedAt: Date
    let confirmedRiskClasses: Set<MCPRiskClass>
}

enum MCPGatewayOperation: Codable, Hashable, Sendable {
    case tool(MCPToolDescriptor)
    case resource(MCPResourceDescriptor)
    case prompt(MCPPromptDescriptor)

    var feature: MCPFeature {
        switch self {
        case .tool:
            return .tool
        case .resource:
            return .resource
        case .prompt:
            return .prompt
        }
    }

    var stableID: String {
        switch self {
        case .tool(let descriptor):
            return descriptor.toolID
        case .resource(let descriptor):
            return descriptor.resourceID
        case .prompt(let descriptor):
            return descriptor.promptID
        }
    }

    var riskClasses: Set<MCPRiskClass> {
        switch self {
        case .tool(let descriptor):
            return descriptor.riskClasses
        case .resource, .prompt:
            return [.read]
        }
    }
}

struct MCPGatewayRequest: Codable, Hashable, Sendable {
    let traceID: String
    let serverID: String
    let operation: MCPGatewayOperation
    let privacyClass: ProviderPrivacyClass
    let membershipTier: MembershipTier
    let confirmationArtifact: MCPConfirmationArtifact?

    init(
        traceID: String = "mcp-trace",
        serverID: String,
        operation: MCPGatewayOperation,
        privacyClass: ProviderPrivacyClass = .general,
        membershipTier: MembershipTier = .free,
        confirmationArtifact: MCPConfirmationArtifact? = nil
    ) {
        self.traceID = traceID
        self.serverID = serverID
        self.operation = operation
        self.privacyClass = privacyClass
        self.membershipTier = membershipTier
        self.confirmationArtifact = confirmationArtifact
    }
}

struct MCPAuditRecord: Codable, Hashable, Sendable {
    let trace: ProviderTrace
    let serverID: String
    let feature: MCPFeature
    let operationID: String
    let riskClasses: Set<MCPRiskClass>
    let denialReason: MCPGatewayDenialReason?
}

struct MCPGatewayDecision: Hashable, Sendable {
    let isAllowed: Bool
    let requiresConfirmation: Bool
    let denialReason: MCPGatewayDenialReason?
    let audit: MCPAuditRecord
}

enum MCPGatewayPolicy {
    static func authorize(
        _ request: MCPGatewayRequest,
        registry: [MCPServerDescriptor]
    ) -> MCPGatewayDecision {
        guard let server = registry.first(where: { $0.serverID == request.serverID }) else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .unknownServer
            )
        }

        guard server.isEnabled else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .serverDisabled
            )
        }

        guard server.descriptorTrust != .unknown else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .untrustedDescriptor
            )
        }

        switch request.operation {
        case .tool(let tool):
            return authorizeTool(tool, request: request, server: server)
        case .resource(let resource):
            return authorizeResource(resource, request: request, server: server)
        case .prompt(let prompt):
            return authorizePrompt(prompt, request: request, server: server)
        }
    }

    private static func authorizeTool(
        _ tool: MCPToolDescriptor,
        request: MCPGatewayRequest,
        server: MCPServerDescriptor
    ) -> MCPGatewayDecision {
        guard tool.serverID == request.serverID,
              server.allowedToolIDs.contains(tool.toolID) else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .toolNotAllowlisted
            )
        }

        if tool.requiresConfirmation, request.confirmationArtifact == nil {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: true,
                denialReason: .confirmationRequired
            )
        }

        return makeDecision(
            request: request,
            isAllowed: true,
            requiresConfirmation: false,
            denialReason: nil
        )
    }

    private static func authorizeResource(
        _ resource: MCPResourceDescriptor,
        request: MCPGatewayRequest,
        server: MCPServerDescriptor
    ) -> MCPGatewayDecision {
        guard resource.serverID == request.serverID,
              server.allowedResourceIDs.contains(resource.resourceID) else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .resourceNotAllowlisted
            )
        }

        guard resource.domain != .health, request.privacyClass != .health else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .healthResourceBlocked
            )
        }

        return makeDecision(
            request: request,
            isAllowed: true,
            requiresConfirmation: false,
            denialReason: nil
        )
    }

    private static func authorizePrompt(
        _ prompt: MCPPromptDescriptor,
        request: MCPGatewayRequest,
        server: MCPServerDescriptor
    ) -> MCPGatewayDecision {
        guard prompt.serverID == request.serverID,
              server.allowedPromptIDs.contains(prompt.promptID) else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .promptNotAllowlisted
            )
        }

        guard prompt.domain != .health, request.privacyClass != .health else {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: false,
                denialReason: .healthPromptBlocked
            )
        }

        if prompt.requiresUserReview, request.confirmationArtifact == nil {
            return makeDecision(
                request: request,
                isAllowed: false,
                requiresConfirmation: true,
                denialReason: .confirmationRequired
            )
        }

        return makeDecision(
            request: request,
            isAllowed: true,
            requiresConfirmation: false,
            denialReason: nil
        )
    }

    private static func makeDecision(
        request: MCPGatewayRequest,
        isAllowed: Bool,
        requiresConfirmation: Bool,
        denialReason: MCPGatewayDenialReason?
    ) -> MCPGatewayDecision {
        let providerFailure = denialReason.map(providerSkipReason(for:))
        let trace = ProviderTrace(
            traceID: request.traceID,
            capability: .mcpTool,
            selectedProviderID: isAllowed ? request.serverID : nil,
            selectedProviderFamily: isAllowed ? .mcp : nil,
            skippedProviders: isAllowed ? [] : [
                ProviderSkip(
                    providerID: request.serverID,
                    family: .mcp,
                    reason: providerFailure ?? .unavailable
                ),
            ],
            costClass: isAllowed ? .includedQuota : costClass(for: denialReason),
            privacyClass: request.privacyClass,
            membershipTier: request.membershipTier,
            freshness: .liveRequired,
            failureReason: providerFailure
        )

        let audit = MCPAuditRecord(
            trace: trace,
            serverID: request.serverID,
            feature: request.operation.feature,
            operationID: request.operation.stableID,
            riskClasses: request.operation.riskClasses,
            denialReason: denialReason
        )

        return MCPGatewayDecision(
            isAllowed: isAllowed,
            requiresConfirmation: requiresConfirmation,
            denialReason: denialReason,
            audit: audit
        )
    }

    nonisolated private static func providerSkipReason(
        for reason: MCPGatewayDenialReason
    ) -> ProviderSkipReason {
        switch reason {
        case .healthResourceBlocked, .healthPromptBlocked:
            return .blockedByPrivacy
        case .confirmationRequired, .serverDisabled, .untrustedDescriptor:
            return .disabledByDefault
        case .unknownServer, .toolNotAllowlisted, .resourceNotAllowlisted,
             .promptNotAllowlisted:
            return .unavailable
        }
    }

    private static func costClass(
        for reason: MCPGatewayDenialReason?
    ) -> ProviderCostClass {
        switch reason {
        case .healthResourceBlocked, .healthPromptBlocked:
            return .blockedByPrivacy
        case .confirmationRequired, .serverDisabled, .untrustedDescriptor,
             .unknownServer, .toolNotAllowlisted, .resourceNotAllowlisted,
             .promptNotAllowlisted, nil:
            return .blockedByTerms
        }
    }
}
