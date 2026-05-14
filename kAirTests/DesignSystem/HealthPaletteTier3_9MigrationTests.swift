//
//  HealthPaletteTier3_9MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.9 bounded slice (audit §8.1 box 4): the single
//  `HealthPalette` §6-alias call site *inside `ContentView`* (in
//  `ContentView.swift`) is migrated to the `AppTheme.Palette`
//  contract token it aliases.
//
//  Scope note: this slice is the box-4 "external straggler" — the
//  one box-4 alias occurrence that lived OUTSIDE
//  `DashboardSections.swift`: `.tint(HealthPalette.mint)` on the
//  live-dashboard `TabView`. After this slice, `ContentView.swift`
//  has zero box-4 sites and the remaining box-4 scope is fully
//  consolidated into `DashboardSections.swift`.
//
//  `ContentView` is an internal `struct` (the `.tint` is set inside
//  its `private func liveDashboard(_:)`, but the struct itself is
//  internal), so — like the `FailureStateScreen` slice (#43, Tier
//  3.6) — the migration exposes an internal `static let` wiring pin
//  (`ContentView.tintColor`) that this test reaches directly.
//
//  Two kinds of assertion:
//    1. Component wiring — `ContentView.tintColor` equals the
//       contract `AppTheme.Palette.success` token it now uses, and
//       equals the `HealthPalette.mint` alias the call site used
//       before (proves the symbol changed, the value did not).
//    2. Visual-safety proof — the migrated box-4 alias (`mint`) is
//       `==` to its `AppTheme.Palette` target (pure rename, zero
//       visual change).
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_9MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (ContentView slice)

    func test_contentView_tintColorUsesContractSuccessToken() {
        XCTAssertEqual(ContentView.tintColor, AppTheme.Palette.success)
    }

    func test_contentView_tintColorMatchesTheBox4AliasItReplaced() {
        // Cross-check: the screen `static` equals the `HealthPalette`
        // alias the `.tint(...)` call site previously used. Proves the
        // migration changed the *symbol* without changing the *value*.
        XCTAssertEqual(ContentView.tintColor, HealthPalette.mint)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Alias_migratedInThisSlice_equalsItsContractToken() {
        // The box-4 alias consumed by `ContentView` is DEFINED as its
        // `AppTheme.Palette` target, so swapping the call site from the
        // alias to the token is provably a pure rename — zero
        // rendered-color change.
        XCTAssertEqual(HealthPalette.mint, AppTheme.Palette.success)
    }
}
