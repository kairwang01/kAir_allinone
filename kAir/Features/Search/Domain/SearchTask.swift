//
//  SearchTask.swift
//  kAir
//
//  Frozen Search task vocabulary per search-ui-spec-v0.md §2.
//  v0 scope: three task kinds, locked copy in zh/en, shared trust pills.
//  Search is the third UI validation vertical — exactly like Music, this
//  file owns only Search-specific copy + glyph; every other visual concern
//  comes from ActionCardShell and super-app-visual-system-v1.md.
//

import Foundation

/// The three Search task kinds permitted in v0. Adding a fourth is a v1 event
/// on search-ui-spec-v0.md — T9 explicitly asserts the cardinality is 3.
enum SearchTaskKind: String, CaseIterable, Hashable, Sendable {
    case answerNow
    case openWebResult
    case deepResearch

    var primaryCTATitle: (en: String, zh: String) {
        switch self {
        case .answerNow:
            return ("Show answer", "查看答案")
        case .openWebResult:
            return ("Open result", "打开结果")
        case .deepResearch:
            return ("Start research", "开始研究")
        }
    }

    var secondaryCTATitle: (en: String, zh: String) {
        switch self {
        case .answerNow:
            return ("Why this answer", "依据")
        case .openWebResult:
            return ("Open another", "换一个")
        case .deepResearch:
            return ("Narrow scope", "缩小范围")
        }
    }

    var headerLabel: (en: String, zh: String) {
        switch self {
        case .answerNow:
            return ("Answer", "答案")
        case .openWebResult:
            return ("Web result", "网络结果")
        case .deepResearch:
            return ("Deep research", "深度研究")
        }
    }

    var systemImage: String {
        switch self {
        case .answerNow:
            return "sparkles.square.filled.on.square"
        case .openWebResult:
            return "link"
        case .deepResearch:
            return "doc.text.magnifyingglass"
        }
    }

    /// Post-return message format, per search-ui-spec-v0.md §8. The returned
    /// string is suitable for writing back into the chat thread when Search
    /// closes. v0 does not wire this into `ChatStore` yet; T9 only asserts the
    /// format table produces the locked strings.
    func returnMessage(query: String, isZh: Bool) -> String {
        let truncated = Self.truncate(query: query, limit: 60)
        switch self {
        case .answerNow:
            return isZh ? "已回答：\(truncated)" : "Answer shown: \(truncated)"
        case .openWebResult:
            return isZh ? "已打开结果：\(truncated)" : "Opened result for: \(truncated)"
        case .deepResearch:
            return isZh ? "已开始研究：\(truncated)" : "Research started on: \(truncated)"
        }
    }

    private static func truncate(query: String, limit: Int) -> String {
        guard query.count > limit else { return query }
        let endIndex = query.index(query.startIndex, offsetBy: limit)
        return String(query[..<endIndex]) + "…"
    }
}

/// Lightweight card content passed into `SearchActionCardView`. Follows the
/// Music template — deliberately simpler than `MapActionCardModel` since v0
/// has no Search scorer adapter. If Search ever earns a scorer binding, this
/// struct graduates to a real model type mirroring Maps (same 6 fields, same
/// 4 states, same 5 events).
struct SearchCardContent: Hashable, Sendable {
    let taskKind: SearchTaskKind
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
        taskKind: SearchTaskKind,
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

    var secondaryActionTitle: String {
        let copy = taskKind.secondaryCTATitle
        return language.usesChineseCopy ? copy.zh : copy.en
    }

    var headerLabelTitle: String {
        let copy = taskKind.headerLabel
        return language.usesChineseCopy ? copy.zh : copy.en
    }

    var headerLabelSystemImage: String { taskKind.systemImage }

    /// v0 trust vocabulary. Always exactly the shared `partnerFallback` pill,
    /// truthfully communicating "partner pending." When a real search partner
    /// lands, this array becomes empty — never a new pill kind. See
    /// search-ui-spec-v0.md §3.
    var trustPills: [ActionCardTrustPillKind] { [.partnerFallback] }

    var feedbackAffordanceLabel: String {
        language.usesChineseCopy ? "反馈选项" : "Feedback options"
    }
}
