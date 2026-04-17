//
//  ComposerBar.swift
//  Kair Health
//
//  Shared multi-layer composer for chat and tool entry.
//

import SwiftUI

struct ComposerBar: View {
    @Binding var text: String

    let placeholder: String
    let contextSummary: String
    let modes: [ComposerMode]
    let selectedModeID: String
    let accessories: [ComposerAccessory]
    let onSelectMode: (ComposerMode) -> Void
    let onAccessoryTap: (ComposerAccessory) -> Void
    let onSend: () -> Void

    private var canSend: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var selectedMode: ComposerMode? {
        modes.first(where: { $0.id == selectedModeID })
    }

    var body: some View {
        KairSurface(style: .elevated, padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                if contextSummary.isEmpty == false {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.success)

                        Text(contextSummary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textSecondary)

                        Spacer(minLength: 12)

                        if let selectedMode {
                            Text(selectedMode.title.uppercased())
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.Palette.textMuted)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(modes) { mode in
                            Button {
                                onSelectMode(mode)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: mode.systemImage)
                                    Text(mode.title)
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(
                                    mode.id == selectedModeID
                                    ? AppTheme.Palette.textOnStrong
                                    : AppTheme.Palette.textSecondary
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            mode.id == selectedModeID
                                            ? AppTheme.Palette.accentStrong
                                            : AppTheme.Palette.surfaceElevated
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(1 ... 5)
                        .font(.body)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    HStack(spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(accessories) { accessory in
                                    Button {
                                        onAccessoryTap(accessory)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: accessory.systemImage)
                                            Text(accessory.title)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Palette.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.white.opacity(0.72))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)

                        Spacer(minLength: 8)

                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(
                                    canSend
                                    ? AppTheme.Palette.textOnStrong
                                    : AppTheme.Palette.textSecondary
                                )
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(
                                            canSend
                                            ? AppTheme.Palette.accentStrong
                                            : AppTheme.Palette.surface
                                        )
                                )
                        }
                        .disabled(canSend == false)
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Metrics.compactRadius + 4,
                        style: .continuous
                    )
                    .fill(AppTheme.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: AppTheme.Metrics.compactRadius + 4,
                        style: .continuous
                    )
                    .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
                )
            }
        }
    }
}
