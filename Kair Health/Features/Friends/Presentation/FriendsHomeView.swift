//
//  FriendsHomeView.swift
//  Kair Health
//
//  Friends shell with empty states for future collaboration.
//

import SwiftUI

struct FriendsHomeView: View {
    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KairSurface(style: .hero) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Friends")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Social collaboration will sit beside chat, not inside Health. This page is a runnable shell with empty states only.")
                                .font(.body)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }

                    KairSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nothing Shared Yet")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text("Thread sharing, companion handoff, and trusted circles are reserved for later backend and identity work.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }

                    KairSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 12) {
                            featureRow(
                                title: "Trusted Circle",
                                summary: "Invite-only groups for shared context and memory."
                            )
                            featureRow(
                                title: "Shared Threads",
                                summary: "Pass a conversation canvas to another person without losing local state."
                            )
                            featureRow(
                                title: "Companion Presence",
                                summary: "See who is active before opening any collaborative space."
                            )
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featureRow(title: String, summary: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Spacer()

            Text("Soon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
        }
    }
}
