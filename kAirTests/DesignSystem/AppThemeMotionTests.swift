//
//  AppThemeMotionTests.swift
//  kAirTests
//
//  Pins the `AppTheme.Motion` tier values against the frozen
//  `Contracts/Design/design-system-v1.md` §3.6 table, and pins the
//  one production consumer wired in this PR (`ChatHomeView`).
//
//  Coverage:
//    - Both §3.6 tiers exist with the contract's curve + timing.
//    - The two tiers are distinct.
//    - Consumer wiring: `ChatHomeView.scrollMotion` resolves to
//      `AppTheme.Motion.standard`.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class AppThemeMotionTests: XCTestCase {

    // MARK: - Tier values (§3.6 table)

    func test_standard_matchesContract() {
        // .easeInOut, 0.24s
        XCTAssertEqual(
            AppTheme.Motion.standard,
            Animation.easeInOut(duration: 0.24)
        )
    }

    func test_emphasized_matchesContract() {
        // .spring(response: 0.42, dampingFraction: 0.82)
        XCTAssertEqual(
            AppTheme.Motion.emphasized,
            Animation.spring(response: 0.42, dampingFraction: 0.82)
        )
    }

    func test_tiers_areDistinct() {
        XCTAssertNotEqual(AppTheme.Motion.standard, AppTheme.Motion.emphasized)
    }

    // MARK: - Consumer wiring

    func test_chatHomeView_scrollMotionUsesStandardTier() {
        // The one production consumer wired in this PR. The build
        // compiling with `withAnimation(Self.scrollMotion)` proves
        // the token is applied; this asserts the tier it is wired
        // to. Scroll-to-bottom is a layout shift → `.standard`.
        XCTAssertEqual(ChatHomeView.scrollMotion, AppTheme.Motion.standard)
    }
}
