//
//  FeedbackOption.swift
//  kAir
//
//  Decision-level feedback options attached to a RecommendationDecision and
//  every Action Card. These are the user-facing choices a person can apply
//  to a card. They map back to the scoring layer's `MatchingFeedbackKind`
//  when logged, but the decision contract exposes only this minimum set
//  so UI and logging never rely on internal scorer vocabulary.
//

import Foundation

enum FeedbackOption: String, Codable, CaseIterable, Hashable, Sendable {
    case notInterested = "not_interested"
    case showLessLikeThis = "show_less_like_this"
    case notNow = "not_now"
    case alreadyDone = "already_done"

    var title: String {
        switch self {
        case .notInterested:
            return "Not interested"
        case .showLessLikeThis:
            return "Show less like this"
        case .notNow:
            return "Not now"
        case .alreadyDone:
            return "Already done"
        }
    }

    var systemImage: String {
        switch self {
        case .notInterested:
            return "hand.thumbsdown"
        case .showLessLikeThis:
            return "line.3.horizontal.decrease.circle"
        case .notNow:
            return "clock.arrow.circlepath"
        case .alreadyDone:
            return "checkmark.circle"
        }
    }

    var matchingFeedbackKind: MatchingFeedbackKind {
        switch self {
        case .notInterested:
            return .notInterested
        case .showLessLikeThis:
            return .lessLikeThis
        case .notNow:
            return .notNow
        case .alreadyDone:
            return .alreadyDone
        }
    }

    init(from kind: MatchingFeedbackKind) {
        switch kind {
        case .dismiss, .notInterested:
            self = .notInterested
        case .lessLikeThis:
            self = .showLessLikeThis
        case .notNow:
            self = .notNow
        case .alreadyDone:
            self = .alreadyDone
        }
    }
}
