//
//  CapabilityKind.swift
//  kAir
//
//  Frozen capability vocabulary per
//  Contracts/capability-registry-and-adapter-contract-v1.md §3.
//
//  10 cases total: §3.1 ships 3 (.aiCompletion, .threadLookup,
//  .localStoreLookup); §3.2 reserves 7 identifiers without an adapter
//  commitment. Adding an eleventh case is a v2 change per §3.3.
//
//  Each capability maps to exactly one CapabilitySurfaceKind family and
//  declares one primary MatchingObjectKind per the §3 tables.
//

import Foundation

enum CapabilityKind: String, Hashable, CaseIterable {
    // §3.1 — Shipped in v1 scope
    case aiCompletion
    case threadLookup
    case localStoreLookup

    // §3.2 — Reserved (vocabulary, not shipped)
    case placeSearch
    case routePlanning
    case musicPlayback
    case videoPlayback
    case healthRead
    case healthWrite
    case webSearch

    /// `true` for the 3 capabilities the v1 contract requires at least one
    /// production adapter for (§3.1). `false` for the 7 reserved-identifier
    /// entries (§3.2) that have no shipping commitment in v1.
    var isShippedInV1: Bool {
        switch self {
        case .aiCompletion, .threadLookup, .localStoreLookup:
            return true
        case .placeSearch, .routePlanning, .musicPlayback,
             .videoPlayback, .healthRead, .healthWrite, .webSearch:
            return false
        }
    }

    /// Per the §3 surface-family column. Each kind maps to exactly one
    /// surface family (§3.3).
    var surfaceFamily: CapabilitySurfaceKind {
        switch self {
        case .aiCompletion:     return .ai
        case .threadLookup:     return .chat
        case .localStoreLookup: return .store
        case .placeSearch:      return .maps
        case .routePlanning:    return .maps
        case .musicPlayback:    return .music
        case .videoPlayback:    return .video
        case .healthRead:       return .health
        case .healthWrite:      return .health
        case .webSearch:        return .search
        }
    }

    /// Per the §3 primary `MatchingObjectKind` column. Each capability
    /// declares one primary kind; v1 forbids declaring multiple (§3.3).
    var primaryObjectKind: MatchingObjectKind {
        switch self {
        case .aiCompletion:     return .answerCard
        case .threadLookup:     return .thread
        case .localStoreLookup: return .toolEntry
        case .placeSearch:      return .place
        case .routePlanning:    return .route
        case .musicPlayback:    return .song
        case .videoPlayback:    return .video
        case .healthRead:       return .answerCard
        case .healthWrite:      return .answerCard
        case .webSearch:        return .searchResult
        }
    }
}
