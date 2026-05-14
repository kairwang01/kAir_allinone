//
//  AppThemeTypographyTests.swift
//  kAirTests
//
//  Pins the `AppTheme.Typography` token values against the frozen
//  `Contracts/Design/design-system-v1.md` §3.2 table, and pins the
//  one production consumer wired in this PR (`SystemEvidenceBlock`).
//
//  Coverage:
//    - All 9 §3.2 tokens exist and carry the contract's font + tracking.
//    - Only `eyebrow` carries non-zero tracking (1.2); the other 8
//      are tracking `0` ("default").
//    - `Token` is `Equatable` so consumers / tests can compare.
//    - Consumer wiring: `SystemEvidenceBlock.eyebrowTypography`
//      resolves to `AppTheme.Typography.eyebrow`.
//

import XCTest
import SwiftUI
@testable import kAir

final class AppThemeTypographyTests: XCTestCase {

    // MARK: - Token font values (§3.2 table)

    func test_display_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.display,
            AppTheme.Typography.Token(font: .largeTitle.weight(.bold), tracking: 0)
        )
    }

    func test_sectionTitle_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.sectionTitle,
            AppTheme.Typography.Token(font: .title3.weight(.semibold), tracking: 0)
        )
    }

    func test_heading_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.heading,
            AppTheme.Typography.Token(font: .headline.weight(.semibold), tracking: 0)
        )
    }

    func test_actionLabel_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.actionLabel,
            AppTheme.Typography.Token(font: .subheadline.weight(.semibold), tracking: 0)
        )
    }

    func test_body_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.body,
            AppTheme.Typography.Token(font: .body.weight(.regular), tracking: 0)
        )
    }

    func test_meta_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.meta,
            AppTheme.Typography.Token(font: .footnote.weight(.medium), tracking: 0)
        )
    }

    func test_chip_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.chip,
            AppTheme.Typography.Token(font: .caption.weight(.semibold), tracking: 0)
        )
    }

    func test_eyebrow_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.eyebrow,
            AppTheme.Typography.Token(font: .caption.weight(.bold), tracking: 1.2)
        )
    }

    func test_micro_matchesContract() {
        XCTAssertEqual(
            AppTheme.Typography.micro,
            AppTheme.Typography.Token(font: .caption2.weight(.regular), tracking: 0)
        )
    }

    // MARK: - Tracking invariant

    func test_eyebrow_isTheOnlyTokenWithNonZeroTracking() {
        // §3.2: every token is "default" tracking except `eyebrow`
        // (1.2). This pins that invariant so a future re-tune of any
        // other token's tracking is a deliberate, caught change.
        XCTAssertEqual(AppTheme.Typography.eyebrow.tracking, 1.2)

        for token in [
            AppTheme.Typography.display,
            AppTheme.Typography.sectionTitle,
            AppTheme.Typography.heading,
            AppTheme.Typography.actionLabel,
            AppTheme.Typography.body,
            AppTheme.Typography.meta,
            AppTheme.Typography.chip,
            AppTheme.Typography.micro,
        ] {
            XCTAssertEqual(token.tracking, 0, "non-eyebrow token had non-zero tracking")
        }
    }

    // MARK: - Consumer wiring

    func test_systemEvidenceBlock_eyebrowUsesEyebrowToken() {
        // The one production consumer wired in this PR. The build
        // compiling with `.kAirTypography(Self.eyebrowTypography)`
        // proves the modifier is applied; this asserts the token it
        // is wired to.
        XCTAssertEqual(
            SystemEvidenceBlock.eyebrowTypography,
            AppTheme.Typography.eyebrow
        )
    }
}
