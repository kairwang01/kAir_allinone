//
//  ActionCardShell.swift
//  kAir
//
//  The single primitive view for every Recommended Next card.
//  Region inventory: action-card-component-inventory.md §1.
//  Per-state visual: design-system-v1 §4.4 + mixed-recommendation-rail-visual-v1 §6.
//
//  This view does NOT branch on slate index. The rail uses the SAME
//  ActionCardShell for the direct slot and for alternatives. Position
//  in the rail's VStack is the only signal — see V2 §5.2.
//

import SwiftUI

// MARK: - Card state

/// The four per-card states the rail can render. v1 mirror of
/// design-system-v1 §4.4 component-state mapping (the empty / error
/// states are owned by the rail/primitive at lower levels and are
/// out of v1 scope). `suppressed` and `refreshed` are slate-level
/// concerns handled by `RecommendationRail`, not by this view.
enum ActionCardState: Hashable, CaseIterable {
    case `default`
    case accepted
    case dismissed
    case loading
}

// MARK: - ActionCardShell

struct ActionCardShell: View {
    static let containerPadding: CGFloat = 20
    static let containerCornerRadius: CGFloat = AppTheme.Metrics.cardRadius
    static let interRegionSpacing: CGFloat = 12
    static let titleSubtitleSpacing: CGFloat = 6
    static let primaryCTAVerticalPadding: CGFloat = 16
    static let secondaryCTAVerticalPadding: CGFloat = 12
    static let trustPillSpacing: CGFloat = 6
    static let borderWidth: CGFloat = 0.8

    /// Elevation tier per `design-system-v1.md` §3.5. `ActionCardShell`
    /// is a top-level card, so it sits at `.raised`. The previous
    /// local shadow constants (`shadowOpacity 0.06` / `shadowBlur 12`
    /// / `shadowOffsetY 6`) were exactly the `.raised` tier; this
    /// replaces them with the shared token. Exposed (internal) so the
    /// token-wiring test can assert `elevation == AppTheme.Elevation.raised`.
    static let elevation = AppTheme.Elevation.raised

    /// Header-label (kind eyebrow) typography per
    /// `design-system-v1.md` §3.2.
    ///
    /// Tier 2 migration (audit §8.1 box 3): the previous
    /// `.font(.caption.weight(.bold))` + `.tracking(1.0)` pair on the
    /// kind-label `Text` used the eyebrow font but an off-spec
    /// tracking (`1.0`). This routes it through the shared `eyebrow`
    /// token (tracking `1.2`). The sibling glyph `Image` keeps its
    /// own `.font(.caption.weight(.bold))` — `.tracking` does not
    /// apply to images, so it is not an eyebrow consumer. Exposed
    /// (internal) for the token-wiring test.
    static let headerLabelTypography = AppTheme.Typography.eyebrow

    let object: MatchingObject
    var state: ActionCardState = .default
    var onPrimaryTap: () -> Void = {}
    var onSecondaryTap: () -> Void = {}
    var onDismiss: () -> Void = {}
    var onFeedback: (MatchingFeedbackKind) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.interRegionSpacing) {
            head
            metadataRow
            bodyRegion
            primaryCTA
            secondaryCTARegion
        }
        .padding(Self.containerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Self.containerCornerRadius, style: .continuous)
                .fill(AppTheme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.containerCornerRadius, style: .continuous)
                .fill(Self.acceptedOverlayColor(for: state))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.containerCornerRadius, style: .continuous)
                .strokeBorder(Self.borderColor(for: state), lineWidth: Self.borderWidth)
        )
        .kAirElevation(Self.elevation)
        .opacity(Self.opacity(for: state))
    }

    // MARK: - Region (1) HEAD

    @ViewBuilder
    private var head: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: object.kind.headerGlyph)
                    .font(.caption.weight(.bold))
                Text(verbatim: object.kind.headerLabel)
                    .kAirTypography(Self.headerLabelTypography)
            }
            .foregroundStyle(AppTheme.Palette.accentStrong)

            Spacer(minLength: 8)

            feedbackMenu
            dismissButton
        }
    }

    private var feedbackMenu: some View {
        Menu {
            ForEach(Self.feedbackMenuKinds, id: \.self) { kind in
                Button {
                    onFeedback(kind)
                } label: {
                    Text(verbatim: kind.displayLabel)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .padding(6)
                .contentShape(Rectangle())
        }
    }

    private var dismissButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Region (2) METADATA ROW + (7) PARTNER BADGE

    /// Pill array for `object`. Resolved through the UI-side adapter so
    /// `MatchingObject` (a domain type) does not need to know about the
    /// trust-pill vocabulary. Empty array collapses the row to zero
    /// height per inventory §2.
    private var trustPills: [ActionCardTrustPillKind] {
        ActionCardTrustPillResolver.pills(for: object)
    }

    @ViewBuilder
    private var metadataRow: some View {
        if trustPills.isEmpty == false {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.trustPillSpacing) {
                    ForEach(trustPills, id: \.self) { pill in
                        ActionCardTrustPill(kind: pill)
                    }
                }
            }
        }
    }

    // MARK: - Region (3) BODY

    private var bodyRegion: some View {
        VStack(alignment: .leading, spacing: Self.titleSubtitleSpacing) {
            Text(verbatim: object.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if object.subtitleTokens.isEmpty == false {
                Text(verbatim: object.subtitleTokens.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            if let reason = object.reasonText, reason.isEmpty == false {
                Text(verbatim: reason)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Region (4) PRIMARY CTA

    private var primaryCTA: some View {
        Button {
            onPrimaryTap()
        } label: {
            HStack(spacing: 6) {
                if state == .accepted {
                    Image(systemName: "checkmark")
                        .font(.headline)
                }
                Text(verbatim: object.primaryCTA)
                    .font(.headline)
            }
            .foregroundStyle(AppTheme.Palette.textOnStrong)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Self.primaryCTAVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                    .fill(Color.black.opacity(0.9))
            )
        }
        .buttonStyle(.plain)
        .disabled(state == .loading)
    }

    // MARK: - Region (5) SECONDARY CTA

    @ViewBuilder
    private var secondaryCTARegion: some View {
        if let label = object.secondaryCTA, label.isEmpty == false {
            Button {
                onSecondaryTap()
            } label: {
                Text(verbatim: label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Self.secondaryCTAVerticalPadding)
            }
            .buttonStyle(.plain)
            .disabled(state == .loading)
        }
    }

    // MARK: - State helpers (exposed at static scope so contract tests
    // can verify the visual mapping without instantiating the view)

    /// Per behavior contract `negative-feedback-ux-v1.md` §2.2 and visual
    /// contract `negative-feedback-affordance-visual-v1.md` §4.2:
    /// the ⋯ menu offers all five `MatchingFeedbackKind` cases in a
    /// fixed order, with `.dismiss` as the first entry. (`.dismiss` also
    /// fires from the ✕ button; surfacing it in the menu spares users
    /// who already opened the menu from having to reach for ✕.)
    static let feedbackMenuKinds: [MatchingFeedbackKind] = [
        .dismiss,
        .notInterested,
        .lessLikeThis,
        .notNow,
        .alreadyDone
    ]

    /// Container alpha for each state.
    /// Per design-system-v1 §4.4 + V2 §6:
    /// - default / accepted / loading: opaque (1.0)
    /// - dismissed: fades to 0
    static func opacity(for state: ActionCardState) -> Double {
        switch state {
        case .default, .accepted, .loading:
            return 1.0
        case .dismissed:
            return 0.0
        }
    }

    /// Accepted-state overlay color, per V2 §6: `Palette.success @ 0.10`.
    /// Other states have no overlay (returns clear).
    static func acceptedOverlayColor(for state: ActionCardState) -> Color {
        switch state {
        case .accepted:
            return AppTheme.Palette.success.opacity(0.10)
        case .default, .dismissed, .loading:
            return Color.clear
        }
    }

    /// Border color per V2 §6:
    /// - accepted: `Palette.success @ 0.18`
    /// - everything else: `Palette.line`
    static func borderColor(for state: ActionCardState) -> Color {
        switch state {
        case .accepted:
            return AppTheme.Palette.success.opacity(0.18)
        case .default, .dismissed, .loading:
            return AppTheme.Palette.line
        }
    }
}

// MARK: - ActionCardTrustPill

struct ActionCardTrustPill: View {
    let kind: ActionCardTrustPillKind

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.systemImage)
                .font(.caption2.weight(.semibold))
            Text(verbatim: kind.displayLabel)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Self.foregroundColor(for: kind.tone))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Self.backgroundColor(for: kind.tone))
        )
    }

    static func foregroundColor(for tone: ActionCardTrustPillTone) -> Color {
        switch tone {
        case .positive: return AppTheme.Palette.success
        case .neutral:  return AppTheme.Palette.textSecondary
        case .warning:  return AppTheme.Palette.warning
        }
    }

    static func backgroundColor(for tone: ActionCardTrustPillTone) -> Color {
        switch tone {
        case .positive: return AppTheme.Palette.success.opacity(0.10)
        case .neutral:  return AppTheme.Palette.backgroundInset
        case .warning:  return AppTheme.Palette.warning.opacity(0.10)
        }
    }
}

// MARK: - Previews

#Preview("default") {
    ActionCardShell(object: RecommendationFixtures.placeRoute)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("accepted") {
    ActionCardShell(object: RecommendationFixtures.placeRoute, state: .accepted)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("dismissed") {
    ActionCardShell(object: RecommendationFixtures.placeRoute, state: .dismissed)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("loading") {
    ActionCardShell(object: RecommendationFixtures.placeRoute, state: .loading)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("with trust pills") {
    ActionCardShell(object: RecommendationFixtures.placeWithTrustPills)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}
