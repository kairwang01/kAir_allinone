//
//  MusicPlaybackSession.swift
//  kAir
//
//  Lightweight playback session for chat-invoked music.
//

import Foundation

struct MusicPlaybackSession: Identifiable, Hashable {
    enum Mood: String, Hashable {
        case focus
        case calm
        case energy
        case jazz
        case ambient
        case custom

        var title: String {
            switch self {
            case .focus:
                return "Focus"
            case .calm:
                return "Calm"
            case .energy:
                return "Energy"
            case .jazz:
                return "Jazz"
            case .ambient:
                return "Ambient"
            case .custom:
                return "Custom"
            }
        }

        var systemImage: String {
            switch self {
            case .focus:
                return "brain.head.profile"
            case .calm:
                return "moon.stars"
            case .energy:
                return "bolt.heart"
            case .jazz:
                return "music.note.list"
            case .ambient:
                return "sparkles"
            case .custom:
                return "waveform"
            }
        }
    }

    let id: UUID
    let title: String
    let subtitle: String
    let mood: Mood
    let query: String
    let sourceLabel: String
    let startedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        mood: Mood,
        query: String,
        sourceLabel: String = "AI-curated",
        startedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.mood = mood
        self.query = query
        self.sourceLabel = sourceLabel
        self.startedAt = startedAt
    }
}
