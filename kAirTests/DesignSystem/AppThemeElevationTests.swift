//
//  AppThemeElevationTests.swift
//  kAirTests
//
//  Pins the `AppTheme.Elevation` tier values against the frozen
//  `Contracts/Design/design-system-v1.md` §3.5 table, and pins the
//  one production consumer wired in this PR (`ActionCardShell`).
//
//  Coverage:
//    - All 3 §3.5 tiers exist with the contract's α / blur / y-offset.
//    - `flat` is a true no-shadow tier (opacity 0, radius 0, y 0).
//    - `Token` is `Equatable` so consumers / tests can compare.
//    - Consumer wiring: `ActionCardShell.elevation` resolves to
//      `AppTheme.Elevation.raised`.
//

import XCTest
@testable import kAir

final class AppThemeElevationTests: XCTestCase {

    // MARK: - Tier values (§3.5 table)

    func test_flat_matchesContract() {
        let flat = AppTheme.Elevation.flat
        XCTAssertEqual(flat.shadowOpacity, 0.0)
        XCTAssertEqual(flat.radius, 0)
        XCTAssertEqual(flat.yOffset, 0)
    }

    func test_raised_matchesContract() {
        let raised = AppTheme.Elevation.raised
        XCTAssertEqual(raised.shadowOpacity, 0.06)
        XCTAssertEqual(raised.radius, 12)
        XCTAssertEqual(raised.yOffset, 6)
    }

    func test_floating_matchesContract() {
        let floating = AppTheme.Elevation.floating
        XCTAssertEqual(floating.shadowOpacity, 0.08)
        XCTAssertEqual(floating.radius, 14)
        XCTAssertEqual(floating.yOffset, 6)
    }

    // MARK: - Tier identity / ordering invariants

    func test_tiers_areDistinct() {
        XCTAssertNotEqual(AppTheme.Elevation.flat, AppTheme.Elevation.raised)
        XCTAssertNotEqual(AppTheme.Elevation.raised, AppTheme.Elevation.floating)
        XCTAssertNotEqual(AppTheme.Elevation.flat, AppTheme.Elevation.floating)
    }

    func test_opacityIncreasesWithTier() {
        // §3.5 orders flat < raised < floating by shadow weight.
        XCTAssertLessThan(
            AppTheme.Elevation.flat.shadowOpacity,
            AppTheme.Elevation.raised.shadowOpacity
        )
        XCTAssertLessThan(
            AppTheme.Elevation.raised.shadowOpacity,
            AppTheme.Elevation.floating.shadowOpacity
        )
    }

    // MARK: - Consumer wiring

    func test_actionCardShell_usesRaisedTier() {
        // The one production consumer wired in this PR. The build
        // compiling with `.kAirElevation(Self.elevation)` proves the
        // modifier is applied; this asserts the tier it is wired to.
        // ActionCardShell is a top-level card → `.raised`.
        XCTAssertEqual(ActionCardShell.elevation, AppTheme.Elevation.raised)
    }
}
