//
//  MCPGatewayPolicyTests.swift
//  kAirTests
//
//  A5c MCP reservation contracts: default deny, allowlisted read-only tools,
//  confirmation gates, and Health resource blocking.
//

import XCTest
@testable import kAir

final class MCPGatewayPolicyTests: XCTestCase {

    func test_unknownServerBlocked() {
        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "unknown",
                operation: .tool(readTool(serverID: "unknown"))
            ),
            registry: []
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.denialReason, .unknownServer)
        XCTAssertEqual(decision.audit.trace.failureReason, .unavailable)
    }

    func test_disabledByDefaultServerBlocked() {
        let server = MCPServerDescriptor(
            serverID: "calendar",
            displayName: "Calendar MCP",
            isEnabled: false,
            descriptorTrust: .known,
            allowedToolIDs: ["read-events"],
            allowedResourceIDs: []
        )

        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .tool(readTool(serverID: "calendar"))
            ),
            registry: [server]
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.denialReason, .serverDisabled)
        XCTAssertEqual(decision.audit.trace.failureReason, .disabledByDefault)
    }

    func test_readOnlyAllowlistedToolAllowed() {
        let server = enabledServer(
            allowedToolIDs: ["read-events"],
            allowedResourceIDs: []
        )

        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                traceID: "mcp-read",
                serverID: "calendar",
                operation: .tool(readTool(serverID: "calendar")),
                membershipTier: .plus
            ),
            registry: [server]
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(decision.requiresConfirmation)
        XCTAssertNil(decision.denialReason)
        XCTAssertEqual(decision.audit.serverID, "calendar")
        XCTAssertEqual(decision.audit.feature, .tool)
        XCTAssertEqual(decision.audit.operationID, "read-events")
        XCTAssertEqual(decision.audit.trace.selectedProviderFamily, .mcp)
        XCTAssertEqual(decision.audit.trace.membershipTier, .plus)
    }

    func test_destructiveToolRequiresConfirmationBeforeAllowed() {
        let server = enabledServer(
            allowedToolIDs: ["delete-event"],
            allowedResourceIDs: []
        )
        let destructive = MCPToolDescriptor(
            serverID: "calendar",
            toolID: "delete-event",
            displayName: "Delete Event",
            riskClasses: [.write],
            isReadOnlyHint: false
        )

        let blocked = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .tool(destructive)
            ),
            registry: [server]
        )

        XCTAssertFalse(blocked.isAllowed)
        XCTAssertTrue(blocked.requiresConfirmation)
        XCTAssertEqual(blocked.denialReason, .confirmationRequired)

        let confirmation = MCPConfirmationArtifact(
            id: "confirm-delete",
            confirmedAt: Date(timeIntervalSince1970: 1_800_000_000),
            confirmedRiskClasses: [.write]
        )
        let allowed = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .tool(destructive),
                confirmationArtifact: confirmation
            ),
            registry: [server]
        )

        XCTAssertTrue(allowed.isAllowed)
        XCTAssertFalse(allowed.requiresConfirmation)
        XCTAssertNil(allowed.denialReason)
        XCTAssertEqual(allowed.audit.riskClasses, [.write])
    }

    func test_healthResourceBlockedEvenWhenAllowlisted() {
        let server = enabledServer(
            allowedToolIDs: [],
            allowedResourceIDs: ["health-summary"]
        )
        let resource = MCPResourceDescriptor(
            serverID: "calendar",
            resourceID: "health-summary",
            displayName: "Health Summary",
            domain: .health
        )

        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .resource(resource),
                privacyClass: .health
            ),
            registry: [server]
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.denialReason, .healthResourceBlocked)
        XCTAssertEqual(decision.audit.trace.costClass, .blockedByPrivacy)
        XCTAssertEqual(decision.audit.trace.failureReason, .blockedByPrivacy)
    }

    func test_allowlistedPromptReservedWithoutExecution() {
        let server = enabledServer(
            allowedToolIDs: [],
            allowedResourceIDs: [],
            allowedPromptIDs: ["daily-review"]
        )
        let prompt = MCPPromptDescriptor(
            serverID: "calendar",
            promptID: "daily-review",
            displayName: "Daily Review",
            argumentNames: ["date"],
            domain: .general,
            requiresUserReview: false
        )

        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                traceID: "mcp-prompt",
                serverID: "calendar",
                operation: .prompt(prompt),
                membershipTier: .plus
            ),
            registry: [server]
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(decision.requiresConfirmation)
        XCTAssertNil(decision.denialReason)
        XCTAssertEqual(decision.audit.feature, .prompt)
        XCTAssertEqual(decision.audit.operationID, "daily-review")
        XCTAssertEqual(decision.audit.riskClasses, [.read])
        XCTAssertEqual(decision.audit.trace.selectedProviderFamily, .mcp)
    }

    func test_promptRequiresReviewBeforeAllowed() {
        let server = enabledServer(
            allowedToolIDs: [],
            allowedResourceIDs: [],
            allowedPromptIDs: ["weekly-review"]
        )
        let prompt = MCPPromptDescriptor(
            serverID: "calendar",
            promptID: "weekly-review",
            displayName: "Weekly Review",
            argumentNames: ["week"],
            domain: .general,
            requiresUserReview: true
        )

        let blocked = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .prompt(prompt)
            ),
            registry: [server]
        )

        XCTAssertFalse(blocked.isAllowed)
        XCTAssertTrue(blocked.requiresConfirmation)
        XCTAssertEqual(blocked.denialReason, .confirmationRequired)

        let confirmation = MCPConfirmationArtifact(
            id: "confirm-prompt",
            confirmedAt: Date(timeIntervalSince1970: 1_800_000_001),
            confirmedRiskClasses: [.read]
        )
        let allowed = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .prompt(prompt),
                confirmationArtifact: confirmation
            ),
            registry: [server]
        )

        XCTAssertTrue(allowed.isAllowed)
        XCTAssertNil(allowed.denialReason)
    }

    func test_healthPromptBlockedEvenWhenAllowlisted() {
        let server = enabledServer(
            allowedToolIDs: [],
            allowedResourceIDs: [],
            allowedPromptIDs: ["health-review"]
        )
        let prompt = MCPPromptDescriptor(
            serverID: "calendar",
            promptID: "health-review",
            displayName: "Health Review",
            argumentNames: ["metric"],
            domain: .health,
            requiresUserReview: false
        )

        let decision = MCPGatewayPolicy.authorize(
            MCPGatewayRequest(
                serverID: "calendar",
                operation: .prompt(prompt),
                privacyClass: .health
            ),
            registry: [server]
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertEqual(decision.denialReason, .healthPromptBlocked)
        XCTAssertEqual(decision.audit.trace.costClass, .blockedByPrivacy)
        XCTAssertEqual(decision.audit.trace.failureReason, .blockedByPrivacy)
    }

    private func enabledServer(
        allowedToolIDs: Set<String>,
        allowedResourceIDs: Set<String>,
        allowedPromptIDs: Set<String> = []
    ) -> MCPServerDescriptor {
        MCPServerDescriptor(
            serverID: "calendar",
            displayName: "Calendar MCP",
            isEnabled: true,
            descriptorTrust: .known,
            allowedToolIDs: allowedToolIDs,
            allowedResourceIDs: allowedResourceIDs,
            allowedPromptIDs: allowedPromptIDs
        )
    }

    private func readTool(serverID: String) -> MCPToolDescriptor {
        MCPToolDescriptor(
            serverID: serverID,
            toolID: "read-events",
            displayName: "Read Events",
            riskClasses: [.read],
            isReadOnlyHint: true
        )
    }
}
