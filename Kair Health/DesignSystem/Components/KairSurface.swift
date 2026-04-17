//
//  KairSurface.swift
//  Kair Health
//
//  Shared surface primitives for the quieter kAir visual system.
//

import SwiftUI

enum KairSurfaceStyle {
    case hero
    case elevated
    case sunken
}

struct KairSurface<Content: View>: View {
    private let style: KairSurfaceStyle
    private let padding: CGFloat
    private let content: Content

    init(
        style: KairSurfaceStyle = .elevated,
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
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        AppTheme.Palette.surfaceElevated,
                        AppTheme.Palette.backgroundInset
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .elevated:
            return AnyShapeStyle(Color.white.opacity(0.70))
        case .sunken:
            return AnyShapeStyle(AppTheme.Palette.surface)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .hero:
            return Color.black.opacity(0.04)
        case .elevated:
            return Color.black.opacity(0.03)
        case .sunken:
            return .clear
        }
    }

    private var backgroundShape: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.Metrics.cardRadius,
            style: .continuous
        )
        .fill(fillStyle)
        .modifier(KairGlassSurface())
    }

    private var borderShape: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.Metrics.cardRadius,
            style: .continuous
        )
        .strokeBorder(AppTheme.Palette.line, lineWidth: 0.8)
    }
}

struct KairStatusPill: View {
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
                .fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct KairGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content
        }
    }
}
