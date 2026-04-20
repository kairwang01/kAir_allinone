//
//  ChatSession.swift
//  kAir
//
//  Planned path for conversation domain models.
//

import Foundation

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
