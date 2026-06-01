//
//  AppSection.swift
//  kAir
//
//  Primary destinations for the rebuilt kAir shell.
//

import Foundation

enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case chat
    case health
    case ai
    case maps
    case search
    case store

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
        case .search:
            return "Search"
        case .store:
            return "Store"
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
        case .search:
            return "magnifyingglass"
        case .store:
            return "bag"
        }
    }
}
