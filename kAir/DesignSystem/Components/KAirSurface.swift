//
//  KAirSurface.swift
//  kAir
//
//  Shared surface primitives for the quieter kAir visual system.
//

import SwiftUI

enum KAirSurfaceStyle {
    case hero
    case elevated
    case sunken
}

struct KAirSurface<Content: View>: View {
    /// Elevation tier per `design-system-v1.md` §3.5.
    ///
    /// Tier 2 migration (audit §8.1 box 2): the previous per-style
    /// `shadowColor` switch produced off-grid α values for `.hero`
    /// (0.07) and `.sunken` (0.04); `.elevated` was already on-grid
    /// (0.06). The contract §6 rules: "Off-grid shadows in
    /// `KAirSurface.hero`, `KAirSurface.sunken` … reroute to
    /// `elevation.raised` on next touch." This IS that touch — all
    /// three styles now resolve to `.raised`, so the `shadowColor`
    /// switch is gone. (`KAirSurfaceStyle` still drives `fillStyle`;
    /// that is out of Tier-2 scope and untouched.)
    ///
    /// Declared as a static *computed* property because
    /// `KAirSurface` is generic and Swift forbids static *stored*
    /// properties on generic types. Exposed (internal) so the
    /// token-wiring test can assert it equals `AppTheme.Elevation.raised`.
    static var elevation: AppTheme.Elevation.Token { AppTheme.Elevation.raised }

    private let style: KAirSurfaceStyle
    private let padding: CGFloat
    private let content: Content

    init(
        style: KAirSurfaceStyle = .elevated,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundShape)
            .overlay(borderShape)
            .kAirElevation(Self.elevation)
    }

    private var fillStyle: AnyShapeStyle {
        switch style {
        case .hero:
            return AnyShapeStyle(Color.white)
        case .elevated:
            return AnyShapeStyle(Color.white)
        case .sunken:
            return AnyShapeStyle(Color.white)
        }
    }

    private var backgroundShape: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.Metrics.cardRadius,
            style: .continuous
        )
        .fill(fillStyle)
    }

    private var borderShape: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.Metrics.cardRadius,
            style: .continuous
        )
        .strokeBorder(AppTheme.Palette.line, lineWidth: 0.8)
    }
}

struct KAirStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        )
    }
}
