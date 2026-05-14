//
//  HealthDashboardStyle.swift
//  kAir
//
//  Calm, neutral styling for health surfaces inside kAir.
//

import SwiftUI

enum HealthPalette {
    static let canvas = AppTheme.Palette.backgroundStart
    static let ink = AppTheme.Palette.textPrimary
    static let mutedInk = AppTheme.Palette.textSecondary
    static let cardStroke = AppTheme.Palette.line

    static let mint = AppTheme.Palette.success
    static let cyan = AppTheme.Palette.sky
    static let amber = AppTheme.Palette.warning
    static let coral = AppTheme.Palette.danger
    static let plum = Color(red: 0.43, green: 0.40, blue: 0.50)
    static let sky = Color(red: 0.54, green: 0.60, blue: 0.68)

    static let heroGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.92),
            Color(red: 0.96, green: 0.95, blue: 0.92),
            Color(red: 0.92, green: 0.93, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(for token: String) -> Color {
        switch token {
        case "overall", "recovery", "heart_rate", "resting_heart_rate", "heart_disease":
            return mint
        case "respiratory", "spo2", "respiratory_rate", "sleep_apnea":
            return cyan
        case "activity", "steps", "active_energy", "diabetes":
            return amber
        case "metabolic", "body_mass", "vo2max":
            return coral
        case "ecg":
            return plum
        default:
            return sky
        }
    }

    static func statusColor(for band: String) -> Color {
        switch band.lowercased() {
        case "guarded":
            return amber
        case "clean":
            return mint
        case "skipped":
            return plum
        default:
            return sky
        }
    }
}

struct HealthScreenBackground: View {
    var body: some View {
        AppBackground()
    }
}

struct GlassCard<Content: View>: View {
    /// Elevation tier per `design-system-v1.md` §3.5.
    ///
    /// Tier 2 migration (audit §8.1 box 2): the previous inline
    /// shadow (α 0.04 / blur 18 / y 10) was off-grid. The contract
    /// §6 rules: "Off-grid shadows in … `GlassCard` … reroute to
    /// `elevation.raised` on next touch." This IS that touch.
    ///
    /// Declared as a static *computed* property because `GlassCard`
    /// is generic (static *stored* properties are forbidden on
    /// generic types). Exposed (internal) for the token-wiring test.
    static var elevation: AppTheme.Elevation.Token { AppTheme.Elevation.raised }

    /// Card stroke color per `design-system-v1.md` §3.1.
    ///
    /// Tier 3 migration (audit §8.1 box 4): the previous
    /// `HealthPalette.cardStroke` reference is a §6 alias of
    /// `AppTheme.Palette.line`. This is a wiring pin referencing the
    /// existing contract token — NOT a new color token. `GlassCard`
    /// is generic, so this is a static *computed* property.
    static var strokeColor: Color { AppTheme.Palette.line }

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Self.strokeColor, lineWidth: 1)
                )
                .modifier(LiquidGlassSurface())
        }
        .kAirElevation(Self.elevation)
    }
}

struct CapsuleChip: View {
    /// Chip ink color per `design-system-v1.md` §3.1.
    ///
    /// Tier 3 migration (audit §8.1 box 4): the previous
    /// `HealthPalette.ink` reference is a §6 alias of
    /// `AppTheme.Palette.textPrimary`. Wiring pin referencing the
    /// existing contract token — NOT a new color token.
    static let inkColor = AppTheme.Palette.textPrimary

    let title: String

    /// Default chip accent color.
    ///
    /// Intentional Tier-3 exception: `HealthPalette.sky` is the
    /// local `Color(0.54, 0.60, 0.68)` variant, which
    /// `design-system-v1.md` §7 lists as out-of-scope (naming
    /// collision with the frozen `Palette.sky` role; distinct
    /// value). It is NOT a §6 box-4 alias — it has no
    /// `AppTheme.Palette` counterpart. Migrating it would require
    /// either a contract change (a new color token — forbidden in
    /// Tier 3) or substituting `Palette.sky`, a different color
    /// (a visual change — forbidden). It is therefore left as-is,
    /// outside box-4 scope. Most call sites pass an explicit
    /// `color:`, so this default is rarely hit.
    var color: Color = HealthPalette.sky

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Self.inkColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(color.opacity(0.10))
                    .overlay(Capsule(style: .continuous).strokeBorder(color.opacity(0.18), lineWidth: 1))
                    .modifier(LiquidGlassSurface())
            }
    }
}

struct MetricTile: View {
    /// Tile title color per `design-system-v1.md` §3.1.
    ///
    /// Tier 3 migration (audit §8.1 box 4): the previous
    /// `HealthPalette.mutedInk` reference is a §6 alias of
    /// `AppTheme.Palette.textSecondary`. Wiring pin referencing the
    /// existing contract token — NOT a new color token.
    static let titleColor = AppTheme.Palette.textSecondary

    /// Tile value color per `design-system-v1.md` §3.1.
    ///
    /// Tier 3 migration (audit §8.1 box 4): the previous
    /// `HealthPalette.ink` reference is a §6 alias of
    /// `AppTheme.Palette.textPrimary`. Wiring pin referencing the
    /// existing contract token — NOT a new color token.
    static let valueColor = AppTheme.Palette.textPrimary

    let title: String
    let value: String

    /// Default tile accent color.
    ///
    /// Intentional Tier-3 exception: `HealthPalette.sky` is the
    /// local `Color(0.54, 0.60, 0.68)` variant — `design-system-v1.md`
    /// §7 out-of-scope, NOT a §6 box-4 alias (see the matching note
    /// on `CapsuleChip.color`). Left as-is, outside box-4 scope.
    /// Most call sites pass an explicit `accent:`, so this default
    /// is rarely hit.
    var accent: Color = HealthPalette.sky

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Self.titleColor)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Self.valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }
}

struct SectionEyebrow: View {
    /// Eyebrow title color per `design-system-v1.md` §3.1.
    ///
    /// Tier 3 migration (audit §8.1 box 4): the previous
    /// `HealthPalette.mutedInk` reference is a §6 alias of
    /// `AppTheme.Palette.textSecondary`. Wiring pin referencing the
    /// existing contract token — NOT a new color token.
    static let titleColor = AppTheme.Palette.textSecondary

    /// Eyebrow subtitle color per `design-system-v1.md` §3.1.
    ///
    /// Tier 3 migration (audit §8.1 box 4): the previous
    /// `HealthPalette.ink` reference is a §6 alias of
    /// `AppTheme.Palette.textPrimary`. Wiring pin referencing the
    /// existing contract token — NOT a new color token.
    static let subtitleColor = AppTheme.Palette.textPrimary

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Note: the title's `.font(.caption.weight(.bold))` +
            // `.tracking(1.2)` is on-spec (the eyebrow token's
            // tracking is 1.2). Typography-token migration of this
            // raw font pair is a separate concern from Tier 3's
            // box-4 color work and is intentionally NOT done here.
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Self.titleColor)
                .tracking(1.2)
            Text(subtitle)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Self.subtitleColor)
        }
    }
}

private struct LiquidGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content
        }
    }
}
