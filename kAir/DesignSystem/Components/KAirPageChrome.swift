//
//  KAirPageChrome.swift
//  kAir
//
//  Minimal shared page chrome aligned with the chat-first home.
//

import SwiftUI

struct KAirHeaderBadge: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
}

struct KAirPageHeader: View {
    /// Eyebrow typography per `design-system-v1.md` §3.2.
    ///
    /// Tier 2 migration (audit §8.1 box 3): the previous
    /// `.font(.caption.weight(.bold))` + `.tracking(1.0)` pair used
    /// the eyebrow font but an off-spec tracking (`1.0`). The
    /// contract §6 rules: "Eyebrow tracking `1.0` (existing in
    /// `KAirPageHeader`) — Migrate to `eyebrow` token (`1.2`) on
    /// next touch." This IS that touch. Exposed (internal) for the
    /// token-wiring test.
    static let eyebrowTypography = AppTheme.Typography.eyebrow

    let title: String
    let summary: String
    var eyebrow: String? = nil
    var badges: [KAirHeaderBadge] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let eyebrow, eyebrow.isEmpty == false {
                Text(eyebrow.uppercased())
                    .kAirTypography(Self.eyebrowTypography)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }

            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text(summary)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            if badges.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(badges) { badge in
                            KAirStatusPill(
                                title: badge.title,
                                systemImage: badge.systemImage,
                                tint: badge.tint
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KAirActionCapsule: View {
    /// Elevation tier for the emphasized capsule per
    /// `design-system-v1.md` §3.5. The previous inline values
    /// (α 0.08 / blur 14 / y 6) were exactly `elevation.floating` —
    /// this is an exact, on-grid swap.
    static let emphasizedElevation = AppTheme.Elevation.floating

    /// Elevation tier for the non-emphasized capsule per §3.5.
    ///
    /// Tier 2 migration (audit §8.1 box 2): the previous inline
    /// non-emphasized values (α 0.08 / blur 10 / y 6) were off-grid.
    /// The contract §6 rules: "Off-grid shadows in … `KAirActionCapsule`
    /// non-emphasized … reroute to `elevation.raised` on next touch."
    /// This IS that touch.
    static let plainElevation = AppTheme.Elevation.raised

    let title: String
    let systemImage: String
    var emphasized = true

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                emphasized
                ? AppTheme.Palette.textOnStrong
                : AppTheme.Palette.textPrimary
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasized ? AppTheme.Palette.accentStrong : Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(emphasized ? 0 : 0.06), lineWidth: 1)
            )
            .kAirElevation(emphasized ? Self.emphasizedElevation : Self.plainElevation)
    }
}
