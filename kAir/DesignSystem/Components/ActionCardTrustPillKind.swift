//
//  ActionCardTrustPillKind.swift
//  kAir
//
//  UI-side enum for the trust-pill vocabulary rendered in
//  ActionCardShell's metadata row. Frozen vocabulary per
//  Docs/design/action-card-component-inventory.md §5.
//
//  Lives on the UI side because the pill set is a card-presentation
//  concept (label + glyph + tone). The domain `MatchingObject` carries
//  an array of these as pre-computed UI hints; the rail does not derive
//  pills from raw scoring data.
//

import Foundation

/// Seven frozen cases. Adding a new case is a v2 event on the
/// action-card-component-inventory contract.
enum ActionCardTrustPillKind: String, Hashable, CaseIterable {
    case placeResolutionLive
    case placeResolutionStub
    case etaConfidenceEstimate
    case distanceConfidenceEstimate
    case partnerFallback
    case locationPermissionDenied
    case locationPermissionManual

    var displayLabel: String {
        switch self {
        case .placeResolutionLive:        return "Live place"
        case .placeResolutionStub:        return "Estimated place"
        case .etaConfidenceEstimate:      return "ETA estimate"
        case .distanceConfidenceEstimate: return "Distance estimate"
        case .partnerFallback:            return "Partner pending"
        case .locationPermissionDenied:   return "No location permission"
        case .locationPermissionManual:   return "Manual place"
        }
    }

    var systemImage: String {
        switch self {
        case .placeResolutionLive:        return "wifi"
        case .placeResolutionStub:        return "questionmark.circle"
        case .etaConfidenceEstimate:      return "clock.badge.questionmark"
        case .distanceConfidenceEstimate: return "ruler"
        case .partnerFallback:            return "link.badge.plus"
        case .locationPermissionDenied:   return "location.slash"
        case .locationPermissionManual:   return "hand.point.up.left"
        }
    }

    var tone: ActionCardTrustPillTone {
        switch self {
        case .placeResolutionLive:
            return .positive
        case .placeResolutionStub,
             .etaConfidenceEstimate,
             .distanceConfidenceEstimate:
            return .neutral
        case .partnerFallback,
             .locationPermissionDenied,
             .locationPermissionManual:
            return .warning
        }
    }
}

enum ActionCardTrustPillTone: Hashable, CaseIterable {
    case positive
    case neutral
    case warning
}
