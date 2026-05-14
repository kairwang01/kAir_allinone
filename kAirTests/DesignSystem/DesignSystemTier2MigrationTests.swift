//
//  DesignSystemTier2MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 2 token migration (audit §8.1 box 2 + box 3): every
//  component whose off-grid shadow or off-spec eyebrow tracking was
//  migrated in this PR now resolves to an `AppTheme.Elevation` /
//  `AppTheme.Typography` token, and no longer carries a local
//  shadow / tracking magic value as its source of truth.
//
//  Strategy:
//    - Each migrated, test-reachable component exposes an internal
//      `static` for the token it is wired to. These tests assert
//      that `static` equals the expected `AppTheme` token. The build
//      compiling with `.kAirElevation(...)` / `.kAirTypography(...)`
//      applied proves the modifier is used; the `static` makes the
//      *which token* assertion a unit test.
//    - `HeroCard` (in `DashboardSections.swift`) is a `private`
//      struct and is intentionally not covered here — its wiring is
//      build-proven only. `ComposerBar` is intentionally NOT
//      migrated (see the PR description: `.caption2.weight(.bold)`
//      matches no §3.2 token) and is therefore not covered.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class DesignSystemTier2MigrationTests: XCTestCase {

    // MARK: - Box 2: off-grid shadows → AppTheme.Elevation

    func test_kAirSurface_usesRaisedElevationTier() {
        // §6: "Off-grid shadows in KAirSurface.hero, KAirSurface.sunken
        // … reroute to elevation.raised." All three styles now resolve
        // to `.raised` (the per-style `shadowColor` switch is gone).
        // `KAirSurface` is generic, so the static is referenced
        // through a concrete specialization.
        XCTAssertEqual(KAirSurface<EmptyView>.elevation, AppTheme.Elevation.raised)
    }

    func test_glassCard_usesRaisedElevationTier() {
        // §6: "Off-grid shadows in … GlassCard … reroute to
        // elevation.raised."
        XCTAssertEqual(GlassCard<EmptyView>.elevation, AppTheme.Elevation.raised)
    }

    func test_kAirActionCapsule_emphasizedUsesFloatingTier() {
        // Emphasized capsule was already α 0.08 / blur 14 / y 6 =
        // `.floating` exactly — an on-grid swap.
        XCTAssertEqual(
            KAirActionCapsule.emphasizedElevation,
            AppTheme.Elevation.floating
        )
    }

    func test_kAirActionCapsule_plainUsesRaisedTier() {
        // §6: "Off-grid shadows in … KAirActionCapsule non-emphasized
        // … reroute to elevation.raised."
        XCTAssertEqual(
            KAirActionCapsule.plainElevation,
            AppTheme.Elevation.raised
        )
    }

    func test_chatHomeView_surfacesUseRaisedElevationTier() {
        // The 3 previously off-grid (and §6-un-enumerated) ChatHomeView
        // shadows now resolve to `.raised` per §6's blanket rule.
        XCTAssertEqual(ChatHomeView.surfaceElevation, AppTheme.Elevation.raised)
    }

    // MARK: - Box 3: off-spec eyebrow tracking → AppTheme.Typography

    func test_kAirPageHeader_eyebrowUsesEyebrowTypographyToken() {
        // §6: "Eyebrow tracking 1.0 (existing in KAirPageHeader) —
        // Migrate to eyebrow token (1.2)."
        XCTAssertEqual(
            KAirPageHeader.eyebrowTypography,
            AppTheme.Typography.eyebrow
        )
    }

    func test_actionCardShell_headerLabelUsesEyebrowTypographyToken() {
        // The kind-label `Text` was `.caption.weight(.bold)` +
        // `.tracking(1.0)` — eyebrow font, off-spec tracking.
        XCTAssertEqual(
            ActionCardShell.headerLabelTypography,
            AppTheme.Typography.eyebrow
        )
    }

    func test_todayHomeView_sectionEyebrowsUseEyebrowTypographyToken() {
        // All 4 section labels ("TODAY" / "WHAT CHANGED" / "NEXT STEP"
        // / "RECENT CONTEXT") were `.caption.weight(.bold)` +
        // `.tracking(1.1)` — eyebrow font, off-spec tracking. They
        // share one token reference.
        XCTAssertEqual(
            TodayHomeView.eyebrowTypography,
            AppTheme.Typography.eyebrow
        )
    }

    // MARK: - No new magic values introduced

    func test_migratedElevationTiers_areExactlyTheContractTiers() {
        // Every elevation `static` a migrated component exposes must
        // be one of the 3 frozen §3.5 tiers — never a fresh `Token(...)`
        // with off-grid numbers. (Pins "no new shadow magic values".)
        let frozen: Set<AppTheme.Elevation.Token> = [
            AppTheme.Elevation.flat,
            AppTheme.Elevation.raised,
            AppTheme.Elevation.floating,
        ]
        XCTAssertTrue(frozen.contains(KAirSurface<EmptyView>.elevation))
        XCTAssertTrue(frozen.contains(GlassCard<EmptyView>.elevation))
        XCTAssertTrue(frozen.contains(KAirActionCapsule.emphasizedElevation))
        XCTAssertTrue(frozen.contains(KAirActionCapsule.plainElevation))
        XCTAssertTrue(frozen.contains(ChatHomeView.surfaceElevation))
    }

    func test_migratedTypographyTokens_areExactlyTheContractTokens() {
        // Every typography `static` a migrated component exposes must
        // be one of the 9 frozen §3.2 tokens. (Pins "no new tracking
        // magic values".)
        let frozen: Set<AppTheme.Typography.Token> = [
            AppTheme.Typography.display,
            AppTheme.Typography.sectionTitle,
            AppTheme.Typography.heading,
            AppTheme.Typography.actionLabel,
            AppTheme.Typography.body,
            AppTheme.Typography.meta,
            AppTheme.Typography.chip,
            AppTheme.Typography.eyebrow,
            AppTheme.Typography.micro,
        ]
        XCTAssertTrue(frozen.contains(KAirPageHeader.eyebrowTypography))
        XCTAssertTrue(frozen.contains(ActionCardShell.headerLabelTypography))
        XCTAssertTrue(frozen.contains(TodayHomeView.eyebrowTypography))
    }
}
