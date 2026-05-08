//
//  RecommendationRail.swift
//  kAir
//
//  Vertical container for the Recommended Next slate.
//
//  Visual contract: Contracts/UX/mixed-recommendation-rail-visual-v1.md.
//  Behavior contract: Docs/design/mixed-recommendation-layout-v1.md.
//
//  This view loops over `objects` and renders one `ActionCardShell` per
//  object. There is NO `if index == 0` branching — the direct slot and
//  alternatives use the same view, per V2 §5.2 rule (1).
//
//  Empty rail is absent rail (V2 §3): when `objects.isEmpty`, the body
//  produces `EmptyView()`.
//

import SwiftUI

struct RecommendationRail: View {
    static let interCardSpacing: CGFloat = 12
    static let maxSlateSize: Int = 3

    let objects: [MatchingObject]
    var cardState: (MatchingObject) -> ActionCardState = { _ in .default }
    var onPrimaryTap: (MatchingObject) -> Void = { _ in }
    var onSecondaryTap: (MatchingObject) -> Void = { _ in }
    var onDismiss: (MatchingObject) -> Void = { _ in }
    var onFeedback: (MatchingObject, MatchingFeedbackKind) -> Void = { _, _ in }

    var body: some View {
        if objects.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Self.interCardSpacing) {
                ForEach(objects) { object in
                    ActionCardShell(
                        object: object,
                        state: cardState(object),
                        onPrimaryTap: { onPrimaryTap(object) },
                        onSecondaryTap: { onSecondaryTap(object) },
                        onDismiss: { onDismiss(object) },
                        onFeedback: { kind in onFeedback(object, kind) }
                    )
                }
            }
        }
    }
}

// MARK: - Test surface

extension RecommendationRail {
    /// True when the rail produces zero view-tree presence (V2 §3 absent rail).
    var isAbsent: Bool {
        objects.isEmpty
    }

    /// Number of cards the rail would render.
    var renderedCardCount: Int {
        objects.count
    }

    /// The rail's layout state per V2 §4.2.
    enum LayoutState: Hashable {
        case absent
        case single
        case dual
        case triple
        case overflow
    }

    var layoutState: LayoutState {
        switch objects.count {
        case 0:                            return .absent
        case 1:                            return .single
        case 2:                            return .dual
        case 3:                            return .triple
        default:                           return .overflow
        }
    }
}

// MARK: - Previews

#Preview("absent (empty)") {
    VStack(alignment: .leading, spacing: 8) {
        Text("RecommendationRail with empty objects renders nothing:")
            .font(.caption)
            .foregroundStyle(AppTheme.Palette.textMuted)
        RecommendationRail(objects: [])
            .border(Color.red.opacity(0.3), width: 0.5)
    }
    .padding(20)
    .background(AppTheme.Palette.backgroundEnd)
}

#Preview("single") {
    RecommendationRail(objects: RecommendationFixtures.singleSlate)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("dual") {
    RecommendationRail(objects: RecommendationFixtures.dualSlate)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("triple — mixed kinds") {
    RecommendationRail(objects: RecommendationFixtures.tripleSlate)
        .padding(20)
        .background(AppTheme.Palette.backgroundEnd)
}

#Preview("triple — accepted middle card") {
    RecommendationRail(
        objects: RecommendationFixtures.tripleSlate,
        cardState: { object in
            object.id == RecommendationFixtures.tripleSlate[1].id ? .accepted : .default
        }
    )
    .padding(20)
    .background(AppTheme.Palette.backgroundEnd)
}

#Preview("triple — loading first card") {
    RecommendationRail(
        objects: RecommendationFixtures.tripleSlate,
        cardState: { object in
            object.id == RecommendationFixtures.tripleSlate[0].id ? .loading : .default
        }
    )
    .padding(20)
    .background(AppTheme.Palette.backgroundEnd)
}
