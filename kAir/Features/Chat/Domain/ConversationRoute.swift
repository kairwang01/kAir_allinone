//
//  ConversationRoute.swift
//  kAir
//
//  Unified destination contract for chat-driven capability routing.
//

import Foundation

enum ConversationDestination: Hashable {
    case surface(AppSection)
    case userProfile
    case persistentPlayer

    var title: String {
        switch self {
        case .surface(let section):
            return section.title
        case .userProfile:
            return "User"
        case .persistentPlayer:
            return "Music"
        }
    }
}

struct ConversationRoute: Hashable {
    let destination: ConversationDestination
    let handoffReason: String
    let shouldRecordSystemNote: Bool
}
