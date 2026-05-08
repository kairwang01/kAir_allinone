//
//  MatchingFeedbackKind.swift
//  kAir
//
//  Domain enum for the user's negative-feedback signals on a
//  recommendation card. Frozen vocabulary per
//  Docs/design/mixed-recommendation-layout-v1.md §5.1.
//
//  No UI dependencies. The card UI binds .dismiss to the ✕ button
//  and the remaining four cases to the ⋯ menu (per inventory §1).
//

import Foundation

/// Five frozen cases. Adding a sixth requires a v2 of
/// `mixed-recommendation-layout-v1.md` AND `negative-feedback-ux-v1.md`.
enum MatchingFeedbackKind: String, Hashable, CaseIterable {
    case dismiss
    case notInterested
    case lessLikeThis
    case notNow
    case alreadyDone

    /// English display label. Localization companion deferred.
    var displayLabel: String {
        switch self {
        case .dismiss:       return "Dismiss"
        case .notInterested: return "Not interested"
        case .lessLikeThis:  return "Less like this"
        case .notNow:        return "Not now"
        case .alreadyDone:   return "Already done"
        }
    }
}
