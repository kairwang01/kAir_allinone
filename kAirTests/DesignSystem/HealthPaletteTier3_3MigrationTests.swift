//
//  HealthPaletteTier3_3MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.3 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `HealthAccessIntroScreen`*
//  (in `DashboardSections.swift`) are migrated to the
//  `AppTheme.Palette` contract tokens they alias.
//
//  Scope note: this slice is ONE component domain — the
//  `HealthAccessIntroScreen` struct (7 box-4 alias occurrences
//  across 6 lines). It is the third box-4 slice; the first two were
//  `HealthDashboardStyle.swift` (PR #40, 6 sites) and
//  `DataLibraryScreen` (PR #41, 23 sites). This slice was chosen as
//  the densest fully-resolver-free domain: `HealthAccessIntroScreen`
//  has zero `HealthPalette.color(for:)` / `statusColor(for:)` calls
//  and zero §7-out-of-scope references — so unlike the prior two
//  slices, this one has NO exceptions to pin, only clean migrations.
//
//  Two kinds of assertion (same shape as the prior slices):
//    1. Component wiring — `HealthAccessIntroScreen` exposes 3
//       internal `static`s for the contract colors it now uses;
//       these tests assert each equals the expected
//       `AppTheme.Palette` token.
//    2. Visual-safety proof — the 3 migrated box-4 aliases (`ink`,
//       `mutedInk`, `mint`) are `==` to their `AppTheme.Palette`
//       targets, so the migration is a pure rename with zero
//       visual change.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_3MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (HealthAccessIntroScreen slice)

    func test_healthAccessIntroScreen_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(HealthAccessIntroScreen.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_healthAccessIntroScreen_mutedInkUsesContractTextSecondaryToken() {
        XCTAssertEqual(HealthAccessIntroScreen.mutedInkColor, AppTheme.Palette.textSecondary)
    }

    func test_healthAccessIntroScreen_chipAccentUsesContractSuccessToken() {
        XCTAssertEqual(HealthAccessIntroScreen.chipAccent, AppTheme.Palette.success)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 3 box-4 aliases consumed by `HealthAccessIntroScreen`
        // are DEFINED as their `AppTheme.Palette` targets, so swapping
        // a call site from the alias to the token is provably a pure
        // rename — zero rendered-color change.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.mint, AppTheme.Palette.success)
    }

    func test_healthAccessIntroScreenStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each screen `static` equals the `HealthPalette`
        // alias the call sites previously used. Proves the migration
        // changed the *symbol* without changing the *value*.
        XCTAssertEqual(HealthAccessIntroScreen.inkColor, HealthPalette.ink)
        XCTAssertEqual(HealthAccessIntroScreen.mutedInkColor, HealthPalette.mutedInk)
        XCTAssertEqual(HealthAccessIntroScreen.chipAccent, HealthPalette.mint)
    }
}
