//
//  SettingsCopyTests.swift
//  kAirTests
//
//  Compliance-copy invariants (App Store 1.4.1). The shared health disclaimer +
//  privacy statement are surfaced by both Settings and Onboarding; these guard
//  that the copy stays present, non-diagnostic, and safety-pointing.
//

import XCTest
@testable import kAir

final class SettingsCopyTests: XCTestCase {

    func test_healthDisclaimer_isPresentNonDiagnosticAndSafe() {
        let text = KAirLegalCopy.healthDisclaimer
        XCTAssertFalse(text.isEmpty)
        // Non-diagnostic posture + a safety pointer (1.4.1).
        XCTAssertTrue(text.localizedCaseInsensitiveContains("not a medical device"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("clinician"))
        // Must not over-claim certainty / diagnosis.
        for banned in ["guaranteed", "medically certain", "we diagnose"] {
            XCTAssertFalse(
                text.localizedCaseInsensitiveContains(banned),
                "disclaimer must not over-claim: \(banned)"
            )
        }
    }

    func test_privacyStatement_assertsOnDeviceProcessing() {
        let text = KAirLegalCopy.privacyStatement
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(
            text.localizedCaseInsensitiveContains("on this device")
                || text.localizedCaseInsensitiveContains("on-device")
        )
    }

    func test_appVersion_isNonEmpty() {
        XCTAssertFalse(ProfileAndSettingsView.appVersion.isEmpty)
    }
}
