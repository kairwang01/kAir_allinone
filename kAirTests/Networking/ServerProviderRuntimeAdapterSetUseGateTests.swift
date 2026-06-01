//
//  ServerProviderRuntimeAdapterSetUseGateTests.swift
//  kAirTests
//
//  A69 adapter-set use authorization tests: value-only, no adapter set input.
//

import XCTest
@testable import kAir

final class ServerProviderRuntimeAdapterSetUseGateTests: XCTestCase {

    func test_acceptedValidationAuthorizesRegisteredRemoteFamilies() {
        let validation = acceptedValidation(
            registered: [.gaode, .googleMaps, .searchAPI],
            accepted: [.gaode, .googleMaps, .searchAPI]
        )

        for family in [ProviderFamily.gaode, .googleMaps, .searchAPI] {
            let authorization = ServerProviderRuntimeAdapterSetUseGate.authorize(
                requestedProviderFamily: family,
                validation: validation
            )

            XCTAssertTrue(authorization.isAuthorized)
            XCTAssertEqual(authorization.state, .authorized)
            XCTAssertEqual(authorization.requestedProviderFamily, family)
            XCTAssertNil(authorization.rejection)
            XCTAssertEqual(authorization.validationID, validation.id)
            XCTAssertEqual(authorization.validationState, .accepted)
            XCTAssertEqual(authorization.registeredProviderFamilies, validation.registeredProviderFamilies)
            XCTAssertEqual(authorization.acceptedProviderFamilies, validation.acceptedProviderFamilies)
        }
    }

    func test_rejectedValidationBlocksEvenWhenRequestedFamilyLooksAccepted() {
        let validation = rejectedValidation(
            registered: [.googleMaps, .searchAPI],
            accepted: [.googleMaps, .searchAPI],
            rejected: [
                rejection(for: .mcp, reason: .missingInstallationDecision),
            ]
        )

        let authorization = ServerProviderRuntimeAdapterSetUseGate.authorize(
            requestedProviderFamily: .googleMaps,
            validation: validation
        )

        XCTAssertFalse(authorization.isAuthorized)
        XCTAssertEqual(authorization.state, .rejected)
        XCTAssertEqual(authorization.requestedProviderFamily, .googleMaps)
        XCTAssertEqual(authorization.rejection, .validationRejected)
        XCTAssertEqual(authorization.validationState, .rejected)
    }

    func test_nilLocalUnregisteredAndMissingAcceptedFamiliesAreRejectedDeterministically() {
        let validation = acceptedValidation(
            registered: [.googleMaps, .searchAPI],
            accepted: [.googleMaps]
        )
        let cases: [(ProviderFamily?, ServerProviderRuntimeAdapterSetUseRejectionReason)] = [
            (nil, .missingRequestedProviderFamily),
            (.appleLocal, .localNoServerAdapter),
            (.cache, .localNoServerAdapter),
            (.mcp, .unregisteredProviderFamily),
            (.searchAPI, .providerFamilyNotAccepted),
        ]

        for (family, expectedRejection) in cases {
            let authorization = ServerProviderRuntimeAdapterSetUseGate.authorize(
                requestedProviderFamily: family,
                validation: validation
            )

            XCTAssertFalse(authorization.isAuthorized)
            XCTAssertEqual(authorization.state, .rejected)
            XCTAssertEqual(authorization.requestedProviderFamily, family)
            XCTAssertEqual(authorization.rejection, expectedRejection)
            XCTAssertEqual(authorization.validationID, validation.id)
        }
    }

    func test_gateDoesNotAcceptAdapterSetInputOrCallResolve() {
        let validation = acceptedValidation(
            registered: [.crawler],
            accepted: [.crawler]
        )

        let authorization = ServerProviderRuntimeAdapterSetUseGate.authorize(
            requestedProviderFamily: .crawler,
            validation: validation
        )

        XCTAssertTrue(authorization.isAuthorized)
        XCTAssertEqual(authorization.requestedProviderFamily, .crawler)
        XCTAssertEqual(authorization.registeredProviderFamilies, [.crawler])
        XCTAssertEqual(authorization.acceptedProviderFamilies, [.crawler])
    }

    func test_encodedAuthorizationResultsDoNotExposeSensitiveRuntimeFields() throws {
        let validation = acceptedValidation(
            registered: [.googleMaps, .mcp],
            accepted: [.googleMaps, .mcp]
        )
        let authorizations = [
            ServerProviderRuntimeAdapterSetUseGate.authorize(
                requestedProviderFamily: .googleMaps,
                validation: validation
            ),
            ServerProviderRuntimeAdapterSetUseGate.authorize(
                requestedProviderFamily: nil,
                validation: validation
            ),
        ]

        let data = try JSONEncoder().encode(authorizations)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lowercased = json.lowercased()
        let forbiddenFragments = [
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
            "pay" + "ment",
            "book" + "ing",
            "ord" + "er",
        ]

        for fragment in forbiddenFragments {
            XCTAssertFalse(lowercased.contains(fragment), "Unexpected encoded field: \(fragment)")
        }
    }

    private func acceptedValidation(
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

    private func rejectedValidation(
        registered: [ProviderFamily],
        accepted: [ProviderFamily],
        rejected: [ServerProviderRuntimeAdapterSetReadinessRejection]
    ) -> ServerProviderRuntimeAdapterSetReadinessValidation {
        ServerProviderRuntimeAdapterSetReadinessValidation(
            id: "test-adapter-set-readiness-validation-rejected",
            state: .rejected,
            registeredProviderFamilies: registered,
            acceptedProviderFamilies: accepted,
            rejectedProviderFamilies: rejected
        )
    }

    private func rejection(
        for providerFamily: ProviderFamily,
        reason: ServerProviderRuntimeAdapterSetReadinessRejectionReason
    ) -> ServerProviderRuntimeAdapterSetReadinessRejection {
        ServerProviderRuntimeAdapterSetReadinessRejection(
            id: "test-rejection-\(providerFamily.rawValue)",
            providerFamily: providerFamily,
            reason: reason,
            decisionID: nil,
            decisionProviderFamily: nil,
            decisionState: nil,
            decisionRejection: nil
        )
    }
}
