//
//  ComposerBar.swift
//  kAir
//
//  Shared multi-layer composer for chat and tool entry.
//

import SwiftUI

struct ComposerBar: View {
    // MARK: - Mode-label typography — intentional Tier-2 exception
    //
    // The composer's selected-mode label (e.g. "ASK", "COACH") is
    // rendered with `.caption2.weight(.bold)` + tracking `0.8`. The
    // Design-System Token Migration Audit (PR #37 §4) listed this
    // call site under "eyebrow tracking" sites because it carries a
    // `.tracking(...)` call — but it is NOT the contract's `eyebrow`
    // token semantically, and Tier 2 intentionally does NOT migrate
    // it. Rationale:
    //
    //   1. Font mismatch. `AppTheme.Typography.eyebrow` is
    //      `.caption.weight(.bold)`. This label is
    //      `.caption2.weight(.bold)` — a smaller size. They are
    //      different fonts; the site does not match the `eyebrow`
    //      token.
    //   2. No-redesign constraint. Forcing `.kAirTypography(.eyebrow)`
    //      here would enlarge the label from `.caption2` to
    //      `.caption`, changing the composer's visual hierarchy —
    //      a redesign, which Tier 2 forbids.
    //   3. No-new-token constraint. Inventing a 10th §3.2 token
    //      (e.g. a "micro-emphasis" token for `.caption2.weight(.bold)`)
    //      is a contract expansion, not a Tier-2 migration. Tier 1
    //      (PR #38) froze the §3.2 set at 9 tokens.
    //   4. Therefore this site is EXCLUDED from box-3's migration
    //      scope. It is a composer micro-emphasis label, not a
    //      section eyebrow. Whether a dedicated micro-emphasis token
    //      should exist is deferred to a future Typography semantic
    //      audit — it is NOT a missed migration.
    //
    // The font + tracking are pinned as named `static let`s below
    // (a source pin, not a token migration) so this exception is
    // testable and cannot be mistaken for an oversight. The values
    // are byte-identical to the previous inline literals — zero
    // visual change.

    /// Font for the composer's selected-mode label. Intentionally a
    /// raw `Font` (not an `AppTheme.Typography` token) — see the
    /// "intentional Tier-2 exception" note above. `.caption2` does
    /// not match the `eyebrow` token's `.caption`.
    static let modeLabelFont: Font = .caption2.weight(.bold)

    /// Tracking for the composer's selected-mode label. Intentionally
    /// a raw value (not `AppTheme.Typography.eyebrow.tracking`, which
    /// is `1.2`) — see the "intentional Tier-2 exception" note above.
    static let modeLabelTracking: CGFloat = 0.8

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
        KAirSurface(style: .elevated, padding: 14) {
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
                            // Intentional Tier-2 exception — see the
                            // "Mode-label typography" note at the top
                            // of `ComposerBar`. NOT migrated to
                            // `AppTheme.Typography.eyebrow`: this is a
                            // composer micro-emphasis label, not a
                            // section eyebrow.
                            Text(selectedMode.title.uppercased())
                                .font(Self.modeLabelFont)
                                .tracking(Self.modeLabelTracking)
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
