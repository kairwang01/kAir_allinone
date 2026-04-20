//
//  VideoPlaybackSession.swift
//  kAir
//
//  Lightweight playback session for chat-invoked video surfaces.
//

import Foundation

struct VideoPlaybackSession: Identifiable, Hashable {
    enum Category: String, Hashable {
        case tutorial
        case workout
        case explainer
        case ambient

        var title: String {
            switch self {
            case .tutorial:
                return "Tutorial"
            case .workout:
                return "Workout"
            case .explainer:
                return "Explainer"
            case .ambient:
                return "Ambient"
            }
        }

        var systemImage: String {
            switch self {
            case .tutorial:
                return "graduationcap"
            case .workout:
                return "figure.run"
            case .explainer:
                return "play.rectangle"
            case .ambient:
                return "sparkles.tv"
            }
        }
    }

    let id: UUID
    let title: String
    let summary: String
    let query: String
    let category: Category
    let durationLabel: String
    let startedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        query: String,
        category: Category,
        durationLabel: String,
        startedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.query = query
        self.category = category
        self.durationLabel = durationLabel
        self.startedAt = startedAt
    }
}
