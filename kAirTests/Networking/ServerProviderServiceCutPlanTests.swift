//
//  ServerProviderServiceCutPlanTests.swift
//  kAirTests
//
//  A182 service-lane contract tests. These prove planning copy only.
//

import XCTest
@testable import kAir

final class ServerProviderServiceCutPlanTests: XCTestCase {
    func test_freeLocalMapsChooseAppleLocalWithoutRemoteEntitlement() {
        let decision = ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapRoute,
                providerFamily: .appleLocal,
                capability: .routePlanning,
                membershipTier: .free,
                region: .northAmerica,
                privacyClass: .health,
                costClass: .freeLocal,
                privateDataPosture: .privateOrHealthLocalOnly
            )
        )

        XCTAssertEqual(decision.state, .localReady)
        XCTAssertEqual(decision.selectedLane, .localAppleMaps)
        XCTAssertEqual(decision.providerFamily, .appleLocal)
        XCTAssertEqual(decision.costClass, .freeLocal)
        XCTAssertTrue(decision.requiredPriorGates.isEmpty)
        XCTAssertTrue(decision.blockReasons.isEmpty)
        XCTAssertFalse(decision.isRuntimeCallable)
        XCTAssertFalse(decision.isExecutable)
        XCTAssertTrue(decision.statusLine.contains("Local service lane"))
    }

    func test_googleAndGaodeMapUpgradesAreServerReservedOnlyWithPolicyInputs() {
        let google = ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapSearch,
                providerFamily: .googleMaps,
                capability: .placeSearch,
                membershipTier: .pro,
                region: .northAmerica,
                costClass: .meteredPremium,
                quotaPosture: .meteredEligible,
                attributionCacheDisplayPolicy: .represented,
                serverSecretPosture: .serverOwned
            )
        )
        let gaode = ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapRoute,
                providerFamily: .gaode,
                capability: .routePlanning,
                membershipTier: .plus,
                region: .china,
                costClass: .includedQuota,
                quotaPosture: .includedQuotaAvailable,
                attributionCacheDisplayPolicy: .represented,
                serverSecretPosture: .serverOwned
            )
        )
        let missingAttribution = ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mapSearch,
                providerFamily: .googleMaps,
                capability: .placeSearch,
                membershipTier: .pro,
                region: .northAmerica,
                costClass: .meteredPremium,
                quotaPosture: .meteredEligible,
                attributionCacheDisplayPolicy: .missing,
                serverSecretPosture: .serverOwned
            )
        )

        XCTAssertEqual(google.state, .serverReserved)
        XCTAssertEqual(google.selectedLane, .serverGoogleMaps)
        XCTAssertEqual(
            Set(google.requiredPriorGates),
            [
                .membershipPackage,
                .regionPolicy,
                .costUnitPolicy,
                .quotaOrQPSPolicy,
                .attributionCacheDisplayPolicy,
                .serverSecretOwnership,
            ]
        )
        XCTAssertFalse(google.isRuntimeCallable)
        XCTAssertFalse(google.isExecutable)
        XCTAssertEqual(gaode.state, .serverReserved)
        XCTAssertEqual(gaode.selectedLane, .serverGaode)
        XCTAssertFalse(gaode.isRuntimeCallable)
        XCTAssertEqual(missingAttribution.state, .blocked)
        XCTAssertEqual(missingAttribution.selectedLane, .serverGoogleMaps)
        XCTAssertTrue(
            missingAttribution.blockReasons.contains(.attributionCacheDisplayMissing)
        )
        XCTAssertTrue(
            missingAttribution.requiredPriorGates.contains(.attributionCacheDisplayPolicy)
        )
    }

    func test_searchAPIPublicInfoRequiresSourceRawRetentionCostAndEntitlementPolicy() {
        let allowed = ServerProviderServiceCutPlanner.decide(searchAPIInput())
        let missingSource = ServerProviderServiceCutPlanner.decide(
            searchAPIInput(sourceCitationRequirement: .missing)
        )
        let unsafeRawContent = ServerProviderServiceCutPlanner.decide(
            searchAPIInput(rawContentPolicy: .unsafeAllowed)
        )

        XCTAssertEqual(allowed.state, .serverReserved)
        XCTAssertEqual(allowed.selectedLane, .serverSearchAPI)
        XCTAssertTrue(allowed.requiredPriorGates.contains(.sourceCitationPolicy))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.rawContentPolicy))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.retentionPolicy))
        XCTAssertFalse(allowed.isRuntimeCallable)
        XCTAssertFalse(allowed.isExecutable)
        XCTAssertEqual(missingSource.state, .blocked)
        XCTAssertTrue(missingSource.blockReasons.contains(.sourceCitationMissing))
        XCTAssertEqual(unsafeRawContent.state, .blocked)
        XCTAssertTrue(unsafeRawContent.blockReasons.contains(.rawContentPolicyMissing))
    }

    func test_crawlerRequiresSourceRobotsRetentionSandboxAuditAndExperimentalEnablement() {
        let blocked = ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .publicSourceCrawlCandidate,
                providerFamily: .crawler,
                capability: .crawlerFetch,
                membershipTier: .pro,
                costClass: .meteredPremium,
                quotaPosture: .meteredEligible,
                sourceCitationRequirement: .requiredAndRepresented,
                rawContentPolicy: .redactedOrDisabled,
                serverSecretPosture: .serverOwned,
                robotsState: .unknown,
                rateRetentionPosture: .represented,
                sandboxAuditPosture: .missing,
                experimentalEnablementPosture: .disabled
            )
        )
        let allowed = ServerProviderServiceCutPlanner.decide(crawlerInput())

        XCTAssertEqual(blocked.state, .blocked)
        XCTAssertEqual(blocked.selectedLane, .reservedCrawler)
        XCTAssertTrue(blocked.blockReasons.contains(.robotsPolicyMissingOrBlocked))
        XCTAssertTrue(blocked.blockReasons.contains(.sandboxAuditMissing))
        XCTAssertTrue(blocked.blockReasons.contains(.experimentalProviderDisabled))
        XCTAssertEqual(allowed.state, .serverReserved)
        XCTAssertEqual(allowed.selectedLane, .reservedCrawler)
        XCTAssertTrue(allowed.requiredPriorGates.contains(.robotsPolicy))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.sandboxAudit))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.experimentalEnablement))
        XCTAssertFalse(allowed.isRuntimeCallable)
        XCTAssertFalse(allowed.isExecutable)
    }

    func test_mcpDefaultDisabledThenRequiresDescriptorAuthorizationConfirmationTokenAndAudit() {
        let disabled = ServerProviderServiceCutPlanner.decide(
            ServerProviderServiceCutPlanInput(
                serviceIntent: .mcpToolCandidate,
                providerFamily: .mcp,
                capability: .mcpTool,
                membershipTier: .developerInternal,
                costClass: .includedQuota,
                quotaPosture: .includedQuotaAvailable,
                descriptorTrustPosture: .verified,
                confirmationRequirement: .notRequired,
                serverSecretPosture: .serverOwned,
                sandboxAuditPosture: .represented,
                experimentalEnablementPosture: .disabled,
                mcpAuthorizationPosture: .represented,
                tokenProtectionPosture: .represented
            )
        )
        let confirmationMissing = ServerProviderServiceCutPlanner.decide(
            mcpInput(confirmationRequirement: .requiredMissing)
        )
        let allowed = ServerProviderServiceCutPlanner.decide(mcpInput())

        XCTAssertEqual(disabled.state, .blocked)
        XCTAssertEqual(disabled.selectedLane, .reservedMCP)
        XCTAssertTrue(disabled.blockReasons.contains(.experimentalProviderDisabled))
        XCTAssertEqual(confirmationMissing.state, .blocked)
        XCTAssertTrue(confirmationMissing.blockReasons.contains(.confirmationMissing))
        XCTAssertEqual(allowed.state, .serverReserved)
        XCTAssertEqual(allowed.selectedLane, .reservedMCP)
        XCTAssertTrue(allowed.requiredPriorGates.contains(.mcpDescriptorVerification))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.mcpDiscoveryFiltering))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.mcpInvocationAuthorization))
        XCTAssertTrue(allowed.requiredPriorGates.contains(.mcpTokenProtection))
        XCTAssertFalse(allowed.isRuntimeCallable)
        XCTAssertFalse(allowed.isExecutable)
    }

    func test_privateHealthAndLocationSensitiveRemoteRequestsAreBlocked() {
        let health = ServerProviderServiceCutPlanner.decide(
            searchAPIInput(privacyClass: .health)
        )
        let privateData = ServerProviderServiceCutPlanner.decide(
            searchAPIInput(privateDataPosture: .containsPrivateRemoteData)
        )

        XCTAssertEqual(health.state, .blocked)
        XCTAssertEqual(health.selectedLane, .serverSearchAPI)
        XCTAssertEqual(health.blockReasons, [.privacyBlocked])
        XCTAssertEqual(health.requiredPriorGates, [.privateDataLocalOnly])
        XCTAssertEqual(privateData.state, .blocked)
        XCTAssertEqual(privateData.blockReasons, [.privateDataBlocked])
        XCTAssertEqual(privateData.requiredPriorGates, [.privateDataLocalOnly])
        XCTAssertFalse(health.isRuntimeCallable)
        XCTAssertFalse(privateData.isExecutable)
    }

    func test_decisionCopyIsCodableValueOnlyAndFreeOfRuntimeFragments() throws {
        let decisions = [
            ServerProviderServiceCutPlanner.decide(searchAPIInput()),
            ServerProviderServiceCutPlanner.decide(crawlerInput()),
            ServerProviderServiceCutPlanner.decide(mcpInput()),
        ]
        let encoded = try JSONEncoder().encode(decisions)
        let decoded = try JSONDecoder().decode(
            [ServerProviderServiceCutPlanDecision].self,
            from: encoded
        )
        let inspected = String(data: encoded, encoding: .utf8)! + "\n" + String(describing: decisions)

        XCTAssertEqual(decoded, decisions)
        XCTAssertTrue(decisions.allSatisfy { $0.isRuntimeCallable == false })
        XCTAssertTrue(decisions.allSatisfy { $0.isExecutable == false })
        for forbidden in serviceCutPlanForbiddenFragments() {
            XCTAssertFalse(inspected.localizedCaseInsensitiveContains(forbidden), forbidden)
        }
    }

    private func searchAPIInput(
        sourceCitationRequirement: ServerProviderServiceSourceCitationRequirement = .requiredAndRepresented,
        rawContentPolicy: ServerProviderServiceRawContentPolicy = .redactedOrDisabled,
        privacyClass: ProviderPrivacyClass = .general,
        privateDataPosture: ServerProviderServicePrivateDataPosture = .publicOrGeneral
    ) -> ServerProviderServiceCutPlanInput {
        ServerProviderServiceCutPlanInput(
            serviceIntent: .publicInfoSearch,
            providerFamily: .searchAPI,
            capability: .webSearch,
            membershipTier: .pro,
            region: .northAmerica,
            privacyClass: privacyClass,
            costClass: .meteredPremium,
            quotaPosture: .meteredEligible,
            sourceCitationRequirement: sourceCitationRequirement,
            rawContentPolicy: rawContentPolicy,
            serverSecretPosture: .serverOwned,
            privateDataPosture: privateDataPosture,
            rateRetentionPosture: .represented
        )
    }

    private func crawlerInput() -> ServerProviderServiceCutPlanInput {
        ServerProviderServiceCutPlanInput(
            serviceIntent: .publicSourceCrawlCandidate,
            providerFamily: .crawler,
            capability: .crawlerFetch,
            membershipTier: .pro,
            region: .northAmerica,
            costClass: .meteredPremium,
            quotaPosture: .meteredEligible,
            sourceCitationRequirement: .requiredAndRepresented,
            rawContentPolicy: .redactedOrDisabled,
            serverSecretPosture: .serverOwned,
            robotsState: .allowed,
            rateRetentionPosture: .represented,
            sandboxAuditPosture: .represented,
            experimentalEnablementPosture: .enabled
        )
    }

    private func mcpInput(
        confirmationRequirement: ServerProviderServiceConfirmationRequirement = .requiredSatisfied
    ) -> ServerProviderServiceCutPlanInput {
        ServerProviderServiceCutPlanInput(
            serviceIntent: .mcpToolCandidate,
            providerFamily: .mcp,
            capability: .mcpTool,
            membershipTier: .developerInternal,
            region: .global,
            costClass: .includedQuota,
            quotaPosture: .includedQuotaAvailable,
            descriptorTrustPosture: .verified,
            confirmationRequirement: confirmationRequirement,
            serverSecretPosture: .serverOwned,
            sandboxAuditPosture: .represented,
            experimentalEnablementPosture: .enabled,
            mcpAuthorizationPosture: .represented,
            tokenProtectionPosture: .represented
        )
    }

    private func serviceCutPlanForbiddenFragments() -> [String] {
        [
            "end" + "point",
            "api" + " key",
            "oa" + "uth",
            "bear" + "er",
            "creden" + "tial",
            "url" + "session",
            "url" + "request",
            "s" + "dk/client",
            "raw" + " query",
            "raw" + " page",
            "raw" + " provider",
            "crawler " + "runtime",
            "mcp " + "runtime",
            "maps " + "sdk",
            "store" + "kit",
            "pay" + "ment",
            "book" + "ing",
            "provider " + "call",
            "execution " + "claim",
            "completion " + "claim",
            "real " + "provider",
            "concrete " + "vendor",
        ]
    }
}
