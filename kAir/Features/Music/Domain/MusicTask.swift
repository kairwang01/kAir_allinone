//
//  MusicTask.swift
//  kAir
//
//  Frozen Music task vocabulary per music-ui-spec-v0.md §2.
//  v0 scope: three task kinds, locked copy in zh/en, shared trust pills.
//

import Foundation

/// The three Music task kinds permitted in v0. Adding a fourth is a v1 event
/// on music-ui-spec-v0.md. Music is not allowed to inflate its surface
/// vocabulary without a shell-spec review.
enum MusicTaskKind: String, CaseIterable, Hashable, Sendable {
    case playNow
    case continueListening
    case moodMix

    var primaryCTATitle: (en: String, zh: String) {
        switch self {
        case .playNow:
            return ("Play now", "立刻播放")
        case .continueListening:
            return ("Resume", "继续听")
        case .moodMix:
            return ("Start mix", "开始播放")
        }
    }

    var secondaryCTATitle: (en: String, zh: String)? {
        switch self {
        case .playNow:
            return ("Preview", "试听")
        case .continueListening:
            return ("Switch track", "换一首")
        case .moodMix:
            return ("Different mood", "换种心情")
        }
    }

    var headerLabel: (en: String, zh: String) {
        switch self {
        case .playNow:
            return ("Play now", "立刻播放")
        case .continueListening:
            return ("Continue listening", "继续听")
        case .moodMix:
            return ("Mood mix", "心情歌单")
        }
    }

    var systemImage: String {
        switch self {
        case .playNow:
            return "play.circle.fill"
        case .continueListening:
            return "arrow.clockwise"
        case .moodMix:
            return "waveform.path"
        }
    }
}

/// Lightweight card content passed into `MusicActionCardView`. Deliberately
/// simpler than `MapActionCardModel` — v0 does not need a per-vertical
/// frozen-contract type since there is no Music scorer adapter yet. When
/// Music earns a scorer binding, this struct graduates to a real model type
/// mirroring Maps (same 6 fields, same 4 states, same 5 events).
struct MusicCardContent: Hashable, Sendable {
    let taskKind: MusicTaskKind
    let title: String
    let subtitle: String
    let reasonText: String?
    let language: Language

    enum Language: String, Hashable, Sendable {
        case english
        case chinese

        var usesChineseCopy: Bool { self == .chinese }
    }

    init(
        taskKind: MusicTaskKind,
        title: String,
        subtitle: String,
        reasonText: String? = nil,
        language: Language = .english
    ) {
        self.taskKind = taskKind
        self.title = title
        self.subtitle = subtitle
        self.reasonText = reasonText
        self.language = language
    }

    var primaryActionTitle: String {
        let copy = taskKind.primaryCTATitle
        return language.usesChineseCopy ? copy.zh : copy.en
    }

    var secondaryActionTitle: String? {
        guard let copy = taskKind.secondaryCTATitle else { return nil }
        return language.usesChineseCopy ? copy.zh : copy.en
    }

    var headerLabelTitle: String {
        let copy = taskKind.headerLabel
        return language.usesChineseCopy ? copy.zh : copy.en
    }

    var headerLabelSystemImage: String { taskKind.systemImage }

    /// v0 trust vocabulary. Always exactly the shared `partnerFallback` pill,
    /// truthfully communicating "partner pending." When a real streaming
    /// partner lands, this array becomes empty — never a new pill kind.
    var trustPills: [ActionCardTrustPillKind] { [.partnerFallback] }

    var feedbackAffordanceLabel: String {
        language.usesChineseCopy ? "反馈选项" : "Feedback options"
    }
}
