//
//  OnboardingView.swift
//  kAir
//
//  First-run experience (B4). Sets the local-first / on-device expectation,
//  primes Apple Health, and surfaces the non-diagnostic disclaimer before the
//  shell appears. Shown once, gated by `@AppStorage("kair.onboarding.completed")`
//  in `ContentView`. No account is required to proceed — kAir is fully usable
//  on-device.
//

import SwiftUI

struct OnboardingView: View {
    /// Invoked when the user taps the primary CTA. The caller flips the
    /// persisted completion flag and swaps in the shell.
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(AppTheme.Palette.accentStrong)
                            .accessibilityHidden(true)

                        Text("Meet Odera")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("The AI that turns intent into action — inside kAir, private by design on your iPhone.")
                            .font(.body)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 18) {
                        FeatureRow(
                            icon: "bubble.left.and.text.bubble.right",
                            tint: AppTheme.Palette.accentStrong,
                            title: "Describe what you want",
                            detail: "Odera keeps chat as the command surface and routes to local capabilities when you choose."
                        )
                        FeatureRow(
                            icon: "heart.text.square",
                            tint: AppTheme.Palette.success,
                            title: "Health is one local domain",
                            detail: "Apple Health is processed on-device when attached. It is one capability, not the whole product."
                        )
                        FeatureRow(
                            icon: "lock.shield",
                            tint: AppTheme.Palette.success,
                            title: "No account needed",
                            detail: "Works fully on-device. Sign-in is optional."
                        )
                    }

                    Text(KAirLegalCopy.healthDisclaimer)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onComplete) {
                        Text("Get started")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textOnStrong)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                AppTheme.Palette.accentStrong,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.getStarted")
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 34, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
