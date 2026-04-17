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
    let title: String
    let summary: String
    var eyebrow: String? = nil
    var badges: [KAirHeaderBadge] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let eyebrow, eyebrow.isEmpty == false {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
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
            .shadow(color: Color.black.opacity(0.08), radius: emphasized ? 14 : 10, x: 0, y: 6)
    }
}
