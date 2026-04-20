//
//  SearchSession.swift
//  kAir
//
//  Lightweight session for chat-invoked Search. Modeled after
//  MusicPlaybackSession (same lightness, same scope). v0 has no real
//  provider; sessions are deterministic fixtures used to drive SearchHomeView
//  in previews and tests.
//

import Foundation

struct SearchSession: Identifiable, Hashable {
    enum Language: String, Hashable {
        case english
        case chinese

        var usesChineseCopy: Bool { self == .chinese }
    }

    let id: UUID
    let kind: SearchTaskKind
    let query: String
    let headlineAnswer: String
    let summary: String
    let sourceLabel: String
    let language: Language
    let startedAt: Date

    init(
        id: UUID = UUID(),
        kind: SearchTaskKind,
        query: String,
        headlineAnswer: String,
        summary: String,
        sourceLabel: String = "AI-synthesized",
        language: Language = .english,
        startedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.query = query
        self.headlineAnswer = headlineAnswer
        self.summary = summary
        self.sourceLabel = sourceLabel
        self.language = language
        self.startedAt = startedAt
    }

    var cardContentLanguage: SearchCardContent.Language {
        language.usesChineseCopy ? .chinese : .english
    }
}
