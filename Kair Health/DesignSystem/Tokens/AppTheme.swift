//
//  AppTheme.swift
//  Kair Health
//
//  Shared design tokens for the rebuilt kAir shell.
//

import SwiftUI

enum AppTheme {
    enum Palette {
        static let accent = Color(red: 0.33, green: 0.36, blue: 0.40)
        static let accentStrong = Color(red: 0.11, green: 0.12, blue: 0.13)
        static let tabAccent = Color(red: 0.17, green: 0.18, blue: 0.19)

        static let backgroundStart = Color(red: 0.98, green: 0.97, blue: 0.96)
        static let backgroundEnd = Color(red: 0.95, green: 0.94, blue: 0.92)
        static let backgroundInset = Color.white.opacity(0.52)

        static let surface = Color.white.opacity(0.44)
        static let surfaceElevated = Color.white.opacity(0.74)
        static let surfaceStrong = Color(red: 0.15, green: 0.16, blue: 0.18)
        static let tabBar = Color.white.opacity(0.90)

        static let line = Color.black.opacity(0.07)
        static let lineStrong = Color.black.opacity(0.11)

        static let textPrimary = Color(red: 0.11, green: 0.12, blue: 0.13)
        static let textSecondary = Color(red: 0.34, green: 0.35, blue: 0.37)
        static let textMuted = Color(red: 0.51, green: 0.52, blue: 0.54)
        static let textOnStrong = Color.white

        static let success = Color(red: 0.32, green: 0.44, blue: 0.38)
        static let warning = Color(red: 0.56, green: 0.46, blue: 0.30)
        static let danger = Color(red: 0.62, green: 0.35, blue: 0.31)
        static let sky = Color(red: 0.39, green: 0.46, blue: 0.53)
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
            LinearGradient(
                colors: [
                    AppTheme.Palette.backgroundStart,
                    AppTheme.Palette.backgroundEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(AppTheme.Palette.accent.opacity(0.035))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 140, y: -260)

            Circle()
                .fill(AppTheme.Palette.sky.opacity(0.025))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -150, y: 260)

            Rectangle()
                .fill(.white.opacity(0.12))
                .blur(radius: 180)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
