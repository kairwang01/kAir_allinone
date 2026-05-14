//
//  HealthPaletteTier3_7MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.7 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `LoadingStateScreen`
//  and `EmptyStateRow`* (both in `DashboardSections.swift`) are
//  migrated to the `AppTheme.Palette` contract tokens they alias.
//
//  Scope note: this slice is TWO sibling components in
//  `DashboardSections.swift` — `LoadingStateScreen` (internal struct,
//  2 box-4 alias occurrences) and `EmptyStateRow` (private struct, 2
//  box-4 alias occurrences + 1 §7-out-of-scope `HealthPalette.sky`
//  reference). It is the seventh box-4 slice; prior slices:
//  `HealthDashboardStyle.swift` (#40, 6), `DataLibraryScreen`
//  (#41, 23), `HealthAccessIntroScreen` (#42, 7), `OverviewScreen`
//  (#43, 6), `RiskOrb` (#44, 5), `FailureStateScreen` (#45, 4).
//
//  Three kinds of assertion:
//    1. Component wiring — `LoadingStateScreen` (internal) exposes 2
//       internal `static`s for the contract colors it now uses.
//       `EmptyStateRow` is a `private` struct, so its `static`s are
//       not test-reachable — like `HeroCard` (#40) / `RiskOrb` (#44),
//       its migration is build-proven and references the
//       `AppTheme.Palette` tokens inline. For `EmptyStateRow` the
//       visual-safety proof below IS the wiring guarantee.
//    2. Visual-safety proof — the 2 migrated box-4 aliases (`ink`,
//       `mutedInk`) are `==` to their `AppTheme.Palette` targets, so
//       the migration is a pure rename with zero visual change.
//    3. §7 exception pin — `HealthPalette.sky` (the local variant,
//       used on `EmptyStateRow`'s background fill) is NOT equal to
//       `AppTheme.Palette.sky`, and matches NONE of the box-4 alias
//       targets — exactly why it cannot be migrated without a
//       contract or visual change. This pins it as intentional, not
//       missed.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_7MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (LoadingStateScreen slice)

    func test_loadingStateScreen_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(LoadingStateScreen.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_loadingStateScreen_mutedInkUsesContractTextSecondaryToken() {
        XCTAssertEqual(LoadingStateScreen.mutedInkColor, AppTheme.Palette.textSecondary)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 2 box-4 aliases consumed by `LoadingStateScreen` and
        // `EmptyStateRow` are DEFINED as their `AppTheme.Palette`
        // targets, so swapping a call site from the alias to the
        // token is provably a pure rename — zero rendered-color
        // change. For `EmptyStateRow` (a `private` struct with no
        // test-reachable `static`), THIS equivalence is the wiring
        // guarantee: the struct references `AppTheme.Palette.textPrimary`
        // / `.textSecondary` inline, and these assertions prove those
        // are the exact values the `HealthPalette.ink` / `.mutedInk`
        // call sites previously resolved to.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
    }

    func test_loadingStateScreenStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each `LoadingStateScreen` `static` equals the
        // `HealthPalette` alias the call sites previously used. Proves
        // the migration changed the *symbol* without changing the
        // *value*.
        XCTAssertEqual(LoadingStateScreen.inkColor, HealthPalette.ink)
        XCTAssertEqual(LoadingStateScreen.mutedInkColor, HealthPalette.mutedInk)
    }

    // MARK: - 3. §7 exception pin (HealthPalette.sky is NOT a box-4 alias)

    func test_healthPaletteSky_isIntentionalExceptionNotABox4Alias() {
        // `HealthPalette.sky` is the local `Color(0.54, 0.60, 0.68)`
        // variant, used on `EmptyStateRow`'s background fill.
        // `design-system-v1.md` §7 lists it as out-of-scope — it is
        // NOT a §6 box-4 alias. The proof: it is NOT equal to
        // `AppTheme.Palette.sky` (the frozen role). Because it has no
        // contract-token counterpart, the `EmptyStateRow` background
        // fill that uses it is left as a documented exception —
        // migrating it would require a contract change or a visual
        // change, both forbidden in Tier 3.
        XCTAssertNotEqual(
            HealthPalette.sky,
            AppTheme.Palette.sky,
            "HealthPalette.sky must remain distinct from the frozen Palette.sky role — "
                + "if they were equal it would be a migratable box-4 alias, not a §7 exception"
        )
    }

    func test_healthPaletteSky_isNotAnyBox4AliasTarget() {
        // Stronger pin: the local `HealthPalette.sky` matches NONE of
        // the `AppTheme.Palette` colors that the §6 box-4 aliases map
        // to. This is the factual basis for "no contract token fits
        // this site" — the reason it is an exception rather than a
        // migration.
        let box4Targets: Set<Color> = [
            AppTheme.Palette.backgroundStart, // canvas
            AppTheme.Palette.textPrimary,     // ink
            AppTheme.Palette.textSecondary,   // mutedInk
            AppTheme.Palette.line,            // cardStroke
            AppTheme.Palette.success,         // mint
            AppTheme.Palette.sky,             // cyan
            AppTheme.Palette.warning,         // amber
            AppTheme.Palette.danger,          // coral
        ]
        XCTAssertFalse(
            box4Targets.contains(HealthPalette.sky),
            "HealthPalette.sky unexpectedly matches a box-4 alias target — "
                + "if a contract token now fits, it should be migrated, not kept as an exception"
        )
    }
}
