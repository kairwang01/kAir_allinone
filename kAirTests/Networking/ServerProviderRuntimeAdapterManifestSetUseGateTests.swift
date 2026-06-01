//
//  ServerProviderRuntimeAdapterManifestSetUseGateTests.swift
//  kAirTests
//
//  A76 manifest-backed adapter-set use tests: value-only, no adapter set input.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterManifestSetUseGateTests: XCTestCase {

    func test_registeredRemoteFamiliesAuthorizeOnlyWithAcceptedManifestValidation() {
        let validation = acceptedManifestValidation(
            registered: [.gaode, .googleMaps, .searchAPI],
            accepted: [.gaode, .googleMaps, .searchAPI]
        )

        for family in [ProviderFamily.gaode, .googleMaps, .searchAPI] {
            let authorization = ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
                requestedProviderFamily: family,
                validation: validation
            )

            XCTAssertTrue(authorization.isAuthorized)
            XCTAssertEqual(authorization.state, .authorized)
            XCTAssertEqual(authorization.requestedProviderFamily, family)
            XCTAssertNil(authorization.rejection)
            XCTAssertEqual(authorization.manifestValidationID, validation.id)
            XCTAssertEqual(authorization.manifestValidationState, .accepted)
            XCTAssertEqual(authorization.manifestAcceptedProviderFamilies, validation.acceptedProviderFamilies)
            XCTAssertEqual(authorization.readinessValidationID, validation.readinessValidation?.id)
            XCTAssertEqual(authorization.readinessValidationState, .accepted)
            XCTAssertEqual(authorization.readinessAuthorizationState, .authorized)
            XCTAssertNil(authorization.readinessAuthorizationRejection)
        }
    }

    func test_nilLocalRejectedManifestNotAcceptedMissingReadinessAndA69RejectionAreDistinct() {
        let accepted = acceptedManifestValidation(
            registered: [.googleMaps, .searchAPI],
            accepted: [.googleMaps]
        )
        let rejectedManifest = rejectedManifestValidation(
            registered: [.googleMaps],
            accepted: [.googleMaps],
            rejected: [
                manifestRejection(for: .mcp, reason: .missingManifestInstallationDecision),
            ],
            readinessValidation: acceptedReadinessValidation(
                registered: [.googleMaps],
                accepted: [.googleMaps]
            )
        )
        let missingReadiness = acceptedManifestValidationWithoutReadiness(
            registered: [.mcp],
            accepted: [.mcp]
        )
        let delegatedRejection = acceptedManifestValidation(
            registered: [.mcp],
            accepted: [.mcp],
            readinessValidation: acceptedReadinessValidation(
                registered: [.googleMaps],
                accepted: [.googleMaps]
            )
        )
        let cases: [(
            ProviderFamily?,
            ServerProviderRuntimeAdapterManifestSetValidation,
            ServerProviderRuntimeAdapterManifestSetUseRejectionReason,
            ServerProviderRuntimeAdapterSetUseRejectionReason?
        )] = [
            (nil, accepted, .missingRequestedProviderFamily, nil),
            (.appleLocal, accepted, .localNoServerAdapter, nil),
            (.cache, accepted, .localNoServerAdapter, nil),
            (.googleMaps, rejectedManifest, .manifestValidationRejected, nil),
            (.searchAPI, accepted, .providerFamilyNotAccepted, nil),
            (.mcp, missingReadiness, .missingReadinessValidation, nil),
            (.mcp, delegatedRejection, .readinessAuthorizationRejected, .unregisteredProviderFamily),
        ]

        for (family, validation, expectedRejection, expectedA69Rejection) in cases {
            let authorization = ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
                requestedProviderFamily: family,
                validation: validation
            )

            XCTAssertFalse(authorization.isAuthorized)
            XCTAssertEqual(authorization.state, .rejected)
            XCTAssertEqual(authorization.requestedProviderFamily, family)
            XCTAssertEqual(authorization.rejection, expectedRejection)
            XCTAssertEqual(authorization.readinessAuthorizationRejection, expectedA69Rejection)
        }
    }

    func test_acceptedPathsPreserveA69AuthorizationOutput() {
        let readinessValidation = acceptedReadinessValidation(
            registered: [.crawler],
            accepted: [.crawler]
        )
        let manifestValidation = acceptedManifestValidation(
            registered: [.crawler],
            accepted: [.crawler],
            readinessValidation: readinessValidation
        )
        let expectedA69 = ServerProviderRuntimeAdapterSetUseGate.authorize(
            requestedProviderFamily: .crawler,
            validation: readinessValidation
        )

        let authorization = ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
            requestedProviderFamily: .crawler,
            validation: manifestValidation
        )

        XCTAssertTrue(authorization.isAuthorized)
        XCTAssertEqual(authorization.readinessAuthorization, expectedA69)
        XCTAssertEqual(authorization.readinessAuthorization?.validationID, expectedA69.validationID)
        XCTAssertEqual(authorization.readinessAuthorization?.acceptedProviderFamilies, expectedA69.acceptedProviderFamilies)
    }

    func test_gateDoesNotAcceptAdapterSetInputOrCallResolve() {
        let validation = acceptedManifestValidation(
            registered: [.mcp],
            accepted: [.mcp]
        )

        let authorization = ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
            requestedProviderFamily: .mcp,
            validation: validation
        )

        XCTAssertTrue(authorization.isAuthorized)
        XCTAssertEqual(authorization.requestedProviderFamily, .mcp)
        XCTAssertEqual(authorization.manifestAcceptedProviderFamilies, [.mcp])
    }

    func test_encodingDescriptionAndStatusTextDoNotExposeSensitiveRuntimeFields() throws {
        let validation = acceptedManifestValidation(
            registered: [.googleMaps, .mcp],
            accepted: [.googleMaps, .mcp]
        )
        let authorizations = [
            ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
                requestedProviderFamily: .googleMaps,
                validation: validation
            ),
            ServerProviderRuntimeAdapterManifestSetUseGate.authorize(
                requestedProviderFamily: nil,
                validation: validation
            ),
        ]
        let data = try JSONEncoder().encode(authorizations)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let text = (
            [json]
                + authorizations.map(\.statusLine)
                + authorizations.map { String(describing: $0) }
        )
        .joined(separator: "\n")
        .lowercased()

        for fragment in forbiddenSensitiveFragments() {
            XCTAssertFalse(text.contains(fragment), "Unexpected manifest-set-use text field: \(fragment)")
        }
    }

    private func acceptedManifestValidation(
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation? = nil
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        let embeddedReadinessValidation = readinessValidation
            ?? acceptedReadinessValidation(registered: registered, accepted: accepted)
        return ServerProviderRuntimeAdapterManifestSetValidation(
            id: "test-manifest-set-validation",
            state: .accepted,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: [],
            readinessValidation: embeddedReadinessValidation
        )
    }

    private func acceptedManifestValidationWithoutReadiness(
        registered: [ProviderFamily],
        accepted: [ProviderFamily]
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "test-manifest-set-validation-missing-readiness",
            state: .accepted,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: [],
            readinessValidation: nil
        )
    }

    private func rejectedManifestValidation(
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        rejected: [ServerProviderRuntimeAdapterManifestSetValidationRejection],
        readinessValidation: ServerProviderRuntimeAdapterSetReadinessValidation?
    ) -> ServerProviderRuntimeAdapterManifestSetValidation {
        ServerProviderRuntimeAdapterManifestSetValidation(
            id: "test-manifest-set-validation-rejected",
            state: .rejected,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: rejected,
            readinessValidation: readinessValidation
        )
    }

    private func acceptedReadinessValidation(
        registered: [ProviderFamily],
        accepted: [ProviderFamily]
    ) -> ServerProviderRuntimeAdapterSetReadinessValidation {
        ServerProviderRuntimeAdapterSetReadinessValidation(
            id: "test-adapter-set-readiness-validation",
            state: .accepted,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: []
        )
    }

    private func manifestRejection(
        for providerFamily: ProviderFamily,
        reason: ServerProviderRuntimeAdapterManifestSetValidationRejectionReason
    ) -> ServerProviderRuntimeAdapterManifestSetValidationRejection {
        ServerProviderRuntimeAdapterManifestSetValidationRejection(
            id: "test-manifest-rejection-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            reason: reason,
            manifestDecisionID: nil,
            manifestDecisionProviderFamily: nil,
            manifestDecisionState: nil,
            manifestDecisionRejection: nil,
            installationDecisionID: nil,
            installationDecisionProviderFamily: nil,
            installationDecisionState: nil,
            installationDecisionRejection: nil
        )
    }

    private func forbiddenSensitiveFragments() -> [String] {
        [
            "end" + "point",
            "url",
            "api" + "key",
            "api" + "_" + "key",
            "bear" + "er",
            "tok" + "en",
            "creden" + "tial",
            "prompt",
            "raw" + "content",
            "raw" + "source",
            "hea" + "lth",
            "mer" + "chant",
            "book" + "ing",
            "ord" + "er",
            "pay" + "ment",
            "oauth" + "secret",
            "secret",
            "private" + "data",
        ]
    }
}
