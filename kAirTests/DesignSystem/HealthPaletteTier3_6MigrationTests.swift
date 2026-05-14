//
//  HealthPaletteTier3_6MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.6 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `FailureStateScreen`*
//  (in `DashboardSections.swift`) are migrated to the
//  `AppTheme.Palette` contract tokens they alias.
//
//  Scope note: this slice is ONE component domain — the
//  `FailureStateScreen` struct (4 box-4 alias occurrences). It is
//  the sixth box-4 slice; prior slices: `HealthDashboardStyle.swift`
//  (#40, 6), `DataLibraryScreen` (#41, 23), `HealthAccessIntroScreen`
//  (#42, 7), `OverviewScreen` (#43, 6), `RiskOrb` (#44, 5).
//
//  `FailureStateScreen` is the densest *fully clean* resolver-free
//  domain remaining: zero `HealthPalette.color(for:)` /
//  `statusColor(for:)` calls AND zero §7-out-of-scope references —
//  so, like the `HealthAccessIntroScreen` slice (#42), this one has
//  NO exceptions to pin, only clean migrations.
//
//  Two kinds of assertion:
//    1. Component wiring — `FailureStateScreen` exposes 3 internal
//       `static`s for the contract colors it now uses.
//    2. Visual-safety proof — the 3 migrated box-4 aliases (`ink`,
//       `mutedInk`, `coral`) are `==` to their `AppTheme.Palette`
//       targets (pure rename, zero visual change).
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_6MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (FailureStateScreen slice)

    func test_failureStateScreen_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(FailureStateScreen.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_failureStateScreen_mutedInkUsesContractTextSecondaryToken() {
        XCTAssertEqual(FailureStateScreen.mutedInkColor, AppTheme.Palette.textSecondary)
    }

    func test_failureStateScreen_dangerAccentUsesContractDangerToken() {
        XCTAssertEqual(FailureStateScreen.dangerAccent, AppTheme.Palette.danger)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 3 box-4 aliases consumed by `FailureStateScreen` are
        // DEFINED as their `AppTheme.Palette` targets, so swapping a
        // call site from the alias to the token is provably a pure
        // rename — zero rendered-color change.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.coral, AppTheme.Palette.danger)
    }

    func test_failureStateScreenStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each screen `static` equals the `HealthPalette`
        // alias the call sites previously used. Proves the migration
        // changed the *symbol* without changing the *value*.
        XCTAssertEqual(FailureStateScreen.inkColor, HealthPalette.ink)
        XCTAssertEqual(FailureStateScreen.mutedInkColor, HealthPalette.mutedInk)
        XCTAssertEqual(FailureStateScreen.dangerAccent, HealthPalette.coral)
    }
}
