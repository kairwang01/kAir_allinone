//
//  ConversationModels.swift
//  kAir
//
//  Shared UI-level models for chat rendering.
//

import Foundation

enum ConversationRole: String, Hashable {
    case assistant
    case user
    case system

    var alignsTrailing: Bool {
        self == .user
    }
}

struct ConversationContextItem: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

struct ComposerMode: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
}

struct ComposerAccessory: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
}

enum ConversationToolResultState: String, Hashable {
    case ready
    case working
    case warning
}

struct ConversationToolMetric: Identifiable, Hashable {
    let key: String
    let value: String

    var id: String { key }
}

struct ConversationToolResult: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let state: ConversationToolResultState
    let metrics: [ConversationToolMetric]
    let footer: String?
}

struct ConversationMessage: Identifiable, Hashable {
    let id: String
    let role: ConversationRole
    let author: String
    let text: String
    let timestamp: Date
    let tags: [String]
    let toolResults: [ConversationToolResult]

    init(
        id: String = UUID().uuidString,
        role: ConversationRole,
        author: String,
        text: String,
        timestamp: Date = .now,
        tags: [String] = [],
        toolResults: [ConversationToolResult] = []
    ) {
        self.id = id
        self.role = role
        self.author = author
        self.text = text
        self.timestamp = timestamp
        self.tags = tags
        self.toolResults = toolResults
    }
}

extension ConversationMessage {
    static func assistant(
        text: String,
        timestamp: Date = .now,
        tags: [String] = [],
        toolResults: [ConversationToolResult] = []
    ) -> ConversationMessage {
        ConversationMessage(
            role: .assistant,
            author: "kAir",
            text: text,
            timestamp: timestamp,
            tags: tags,
            toolResults: toolResults
        )
    }

    static func user(
        text: String,
        timestamp: Date = .now,
        tags: [String] = []
    ) -> ConversationMessage {
        ConversationMessage(
            role: .user,
            author: "You",
            text: text,
            timestamp: timestamp,
            tags: tags
        )
    }

    static func system(
        text: String,
        timestamp: Date = .now,
        tags: [String] = []
    ) -> ConversationMessage {
        ConversationMessage(
            role: .system,
            author: "kAir",
            text: text,
            timestamp: timestamp,
            tags: tags
        )
    }
}
