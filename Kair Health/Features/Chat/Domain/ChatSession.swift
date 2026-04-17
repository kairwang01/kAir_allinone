//
//  ChatSession.swift
//  Kair Health
//
//  Planned path for conversation domain models.
//

import Foundation

struct ChatSession: Identifiable {
    let id = UUID()
    var title: String
    var messages: [ConversationMessage]
}
