//
//  MatchingObjectKind.swift
//  kAir
//
//  Domain enum for the kind of object the matching kernel can recommend.
//  Frozen vocabulary per Docs/design/mixed-recommendation-layout-v1.md §1.
//
//  No UI dependencies — header label / glyph live with the data here so
//  the rail's UI layer can read them, but the enum itself is owned by
//  the domain model and is safe to consume from non-UI code.
//

import Foundation

/// Nine frozen cases. Adding a tenth requires a v2 of
/// `mixed-recommendation-layout-v1.md`.
enum MatchingObjectKind: String, Hashable, CaseIterable {
    case place
    case route
    case contact
    case song
    case video
    case searchResult
    case answerCard
    case toolEntry
    case thread

    /// English display label for the card head. Localization companion
    /// deferred until a localization pipeline exists.
    var headerLabel: String {
        switch self {
        case .place:        return "PLACE"
        case .route:        return "ROUTE"
        case .contact:      return "CONTACT"
        case .song:         return "SONG"
        case .video:        return "VIDEO"
        case .searchResult: return "WEB RESULT"
        case .answerCard:   return "ANSWER"
        case .toolEntry:    return "TOOL"
        case .thread:       return "THREAD"
        }
    }

    /// SF Symbol identifier per inventory §1. The symbol name is
    /// platform-independent string data; resolving it to an `Image`
    /// happens in the UI layer.
    var headerGlyph: String {
        switch self {
        case .place:        return "mappin.and.ellipse"
        case .route:        return "arrow.triangle.turn.up.right.diamond"
        case .contact:      return "person.2"
        case .song:         return "music.note"
        case .video:        return "play.rectangle"
        case .searchResult: return "magnifyingglass"
        case .answerCard:   return "text.bubble"
        case .toolEntry:    return "square.stack.3d.up"
        case .thread:       return "bubble.left.and.bubble.right"
        }
    }
}
