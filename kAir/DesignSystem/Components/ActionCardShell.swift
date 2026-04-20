//
//  ActionCardShell.swift
//  kAir
//
//  Shared primitive behind every Action Card that Chat → Recommended Next
//  renders. The shell locks the 7 regions that make up a card:
//
//      1. Card head         — kind label + feedback menu + dismiss button
//      2. Metadata row      — 0..n ActionCardTrustPill values (includes partner/source)
//      3. Body              — title + subtitle + optional plain reason caption
//      4. Primary CTA       — black capsule button
//      5. Secondary CTA     — plain-text button (optional)
//      6. Feedback affordance — accessible label on the ⋯ menu (in head)
//      7. Partner / source badge — rendered as a trust pill inside region 2
//
//  Callers (UnifiedActionCard, MapActionCardView, future Music / Store cards)
//  are not allowed to introduce their own container, padding, or visual
//  grammar. Language-bound copy variations are allowed; visual divergence is
//  a Maps-UI-Spec v1 violation.
//

import SwiftUI

struct ActionCardShell: View {
    let headerLabelTitle: String
    let headerLabelSystemImage: String
    let trustPills: [ActionCardTrustPillKind]
    let isZh: Bool
    let title: String
    let subtitle: String
    let reasonText: String?
    let primaryActionTitle: String
    let primaryEnabled: Bool
    let secondaryActionTitle: String?
    let feedbackAffordanceLabel: String
    let onCardTap: (() -> Void)?
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    let onFeedback: (MatchingFeedbackKind) -> Void
    let onDismiss: () -> Void

    init(
        headerLabelTitle: String,
        headerLabelSystemImage: String,
        trustPills: [ActionCardTrustPillKind] = [],
        isZh: Bool = false,
        title: String,
        subtitle: String,
        reasonText: String? = nil,
        primaryActionTitle: String,
        primaryEnabled: Bool = true,
        secondaryActionTitle: String? = nil,
        feedbackAffordanceLabel: String,
        onCardTap: (() -> Void)? = nil,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil,
        onFeedback: @escaping (MatchingFeedbackKind) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.headerLabelTitle = headerLabelTitle
        self.headerLabelSystemImage = headerLabelSystemImage
        self.trustPills = trustPills
        self.isZh = isZh
        self.title = title
        self.subtitle = subtitle
        self.reasonText = reasonText
        self.primaryActionTitle = primaryActionTitle
        self.primaryEnabled = primaryEnabled
        self.secondaryActionTitle = secondaryActionTitle
        self.feedbackAffordanceLabel = feedbackAffordanceLabel
        self.onCardTap = onCardTap
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onFeedback = onFeedback
        self.onDismiss = onDismiss
    }

    var body: some View {
        KAirSurface(style: .elevated, padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if trustPills.isEmpty == false {
                    metadataRow
                }
                bodyRegion
                actions
            }
        }
    }

    // MARK: - Region 1: Head

    private var header: some View {
        HStack {
            Label(headerLabelTitle, systemImage: headerLabelSystemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Palette.accentStrong)
                .textCase(.uppercase)

            Spacer()

            HStack(spacing: 4) {
                Menu {
                    ForEach(MatchingFeedbackKind.allCases.filter { $0 != .dismiss }, id: \.self) { feedback in
                        Button {
                            onFeedback(feedback)
                        } label: {
                            Label(feedback.title, systemImage: feedback.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                        .padding(8)
                        .contentShape(Rectangle())
                        .accessibilityLabel(feedbackAffordanceLabel)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textMuted)
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Region 2: Metadata row (trust pills + partner badge slot)

    private var metadataRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(trustPills, id: \.self) { pill in
                    ActionCardTrustPill(kind: pill, isZh: isZh)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Region 3: Body

    private var bodyRegion: some View {
        Button {
            onCardTap?()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .lineLimit(3)

                if let reasonText {
                    Text(reasonText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textMuted)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onCardTap == nil)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Regions 4 + 5: Primary + Secondary CTA

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onPrimaryAction) {
                Text(primaryActionTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius)
                            .fill(Color.black.opacity(0.9))
                    )
            }
            .buttonStyle(.plain)
            .disabled(primaryEnabled == false)
            .opacity(primaryEnabled ? 1.0 : 0.55)

            if let secondaryActionTitle, let onSecondaryAction {
                Button(action: onSecondaryAction) {
                    Text(secondaryActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Trust pill vocabulary (frozen)

/// Frozen vocabulary for the metadata row. Adding a new case is a spec change
/// (requires a v2 bump on Maps UI Spec). The copy is locked per case and
/// cannot be overridden by callers.
enum ActionCardTrustPillKind: String, CaseIterable, Hashable {
    case placeResolutionLive
    case placeResolutionStub
    case etaConfidenceEstimate
    case distanceConfidenceEstimate
    case partnerFallback
    case locationPermissionDenied
    case locationPermissionManual

    func title(isZh: Bool) -> String {
        switch self {
        case .placeResolutionLive:
            return isZh ? "实时地点" : "Live place"
        case .placeResolutionStub:
            return isZh ? "估算地点" : "Estimated place"
        case .etaConfidenceEstimate:
            return isZh ? "ETA 估算" : "ETA estimate"
        case .distanceConfidenceEstimate:
            return isZh ? "距离估算" : "Distance estimate"
        case .partnerFallback:
            return isZh ? "合作方待接入" : "Partner pending"
        case .locationPermissionDenied:
            return isZh ? "无定位权限" : "No location permission"
        case .locationPermissionManual:
            return isZh ? "手动地点" : "Manual place"
        }
    }

    var systemImage: String {
        switch self {
        case .placeResolutionLive:
            return "mappin.circle.fill"
        case .placeResolutionStub:
            return "mappin.and.ellipse"
        case .etaConfidenceEstimate:
            return "clock"
        case .distanceConfidenceEstimate:
            return "ruler"
        case .partnerFallback:
            return "square.stack.3d.up.slash"
        case .locationPermissionDenied:
            return "location.slash"
        case .locationPermissionManual:
            return "hand.point.up.braille"
        }
    }

    var tone: ActionCardTrustTone {
        switch self {
        case .placeResolutionLive:
            return .positive
        case .placeResolutionStub, .etaConfidenceEstimate, .distanceConfidenceEstimate:
            return .neutral
        case .partnerFallback, .locationPermissionDenied, .locationPermissionManual:
            return .warning
        }
    }
}

enum ActionCardTrustTone: Hashable {
    case positive
    case warning
    case neutral

    var foreground: Color {
        switch self {
        case .positive:
            return AppTheme.Palette.success
        case .warning:
            return AppTheme.Palette.warning
        case .neutral:
            return AppTheme.Palette.textMuted
        }
    }

    var borderColor: Color {
        foreground.opacity(0.18)
    }
}

struct ActionCardTrustPill: View {
    let kind: ActionCardTrustPillKind
    let isZh: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: kind.systemImage)
                .font(.caption2.weight(.semibold))
            Text(kind.title(isZh: isZh))
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(kind.tone.foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(kind.tone.borderColor, lineWidth: 0.8)
        )
    }
}
