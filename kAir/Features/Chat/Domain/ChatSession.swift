//
//  ChatSession.swift
//  kAir
//
//  Planned path for conversation domain models.
//

import Foundation

enum ChatNavigationTarget: Hashable {
    case section(AppSection)
    case userProfile

    var title: String {
        switch self {
        case .section(let section):
            return section.title
        case .userProfile:
            return "User"
        }
    }
}

struct ChatSession: Identifiable, Codable {
    var id: UUID
    var title: String
    var messages: [ConversationMessage]

    init(
        id: UUID = UUID(),
        title: String,
        messages: [ConversationMessage]
    ) {
        self.id = id
        self.title = title
        self.messages = messages
    }
}
