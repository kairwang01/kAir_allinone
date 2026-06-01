//
//  AppTheme.swift
//  kAir
//
//  Shared design tokens for the rebuilt kAir shell.
//

import SwiftUI

enum AppTheme {
    enum Palette {
        static let accent = Color(red: 0.35, green: 0.37, blue: 0.41)
        static let accentStrong = Color(red: 0.10, green: 0.11, blue: 0.13)
        static let tabAccent = Color(red: 0.15, green: 0.16, blue: 0.18)

        static let backgroundStart = Color(red: 1.0, green: 1.0, blue: 1.0)
        static let backgroundEnd = Color(red: 0.97, green: 0.97, blue: 0.975)
        static let backgroundInset = Color(red: 0.985, green: 0.985, blue: 0.99)

        static let surface = Color.white
        static let surfaceElevated = Color.white
        static let surfaceStrong = Color(red: 0.15, green: 0.16, blue: 0.18)
        static let tabBar = Color.white

        static let line = Color.black.opacity(0.06)
        static let lineStrong = Color.black.opacity(0.10)

        static let textPrimary = Color(red: 0.11, green: 0.12, blue: 0.13)
        static let textSecondary = Color(red: 0.34, green: 0.35, blue: 0.37)
        static let textMuted = Color(red: 0.51, green: 0.52, blue: 0.54)
        static let textOnStrong = Color.white

        static let success = Color(red: 0.31, green: 0.43, blue: 0.38)
        static let warning = Color(red: 0.57, green: 0.46, blue: 0.29)
        static let danger = Color(red: 0.62, green: 0.34, blue: 0.30)
        static let sky = Color(red: 0.38, green: 0.45, blue: 0.54)
    }

    enum Metrics {
        static let screenPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 16
        static let cardRadius: CGFloat = 26
        static let compactRadius: CGFloat = 16
    }

    static func tint(for section: AppSection) -> Color {
        switch section {
        case .chat:
            return Palette.accentStrong
        case .health:
            return Palette.success
        case .ai:
            return Palette.sky
        case .maps:
            return Palette.warning
        case .search:
            return Palette.sky
        case .store:
            return Palette.accent
        }
    }

    static func tint(for token: String) -> Color {
        switch token {
        case "overall", "recovery", "heart_rate", "resting_heart_rate", "heart_disease":
            return Palette.success
        case "respiratory", "spo2", "respiratory_rate", "sleep_apnea":
            return Palette.sky
        case "activity", "steps", "active_energy", "diabetes":
            return Palette.warning
        case "metabolic", "body_mass", "vo2max":
            return Palette.danger
        case "ecg":
            return Palette.accent
        default:
            return Palette.accentStrong
        }
    }

    static func statusTint(for band: String) -> Color {
        switch band.lowercased() {
        case "stable", "clean":
            return Palette.success
        case "watch", "guarded":
            return Palette.warning
        case "skipped":
            return Palette.accent
        default:
            return Palette.sky
        }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.Palette.backgroundStart

            LinearGradient(
                colors: [
                    Color.clear,
                    AppTheme.Palette.backgroundEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(AppTheme.Palette.backgroundInset)
                .frame(width: 320, height: 180)
                .blur(radius: 64)
                .offset(x: 120, y: -280)
        }
        .ignoresSafeArea()
    }
}
