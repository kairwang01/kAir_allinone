//
//  AppSection.swift
//  kAir
//
//  Primary destinations for the rebuilt kAir shell.
//

import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case chat
    case health
    case ai
    case maps
    case store
    case music
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .health:
            return "Health"
        case .ai:
            return "AI"
        case .maps:
            return "Maps"
        case .store:
            return "Store"
        case .music:
            return "Music"
        case .video:
            return "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .health:
            return "heart.text.square"
        case .ai:
            return "sparkles.rectangle.stack"
        case .maps:
            return "map"
        case .store:
            return "bag"
        case .music:
            return "music.note"
        case .video:
            return "play.rectangle"
        }
    }
}
