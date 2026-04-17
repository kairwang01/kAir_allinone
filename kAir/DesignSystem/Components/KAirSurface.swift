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
            .shadow(color: shadowColor, radius: 12, x: 0, y: 6)
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

    private var shadowColor: Color {
        switch style {
        case .hero:
            return Color.black.opacity(0.07)
        case .elevated:
            return Color.black.opacity(0.06)
        case .sunken:
            return Color.black.opacity(0.04)
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
