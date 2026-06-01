//
//  MemoryCandidateExtractor.swift
//  kAir
//
//  Local-only extraction for explicit user memory writes.
//

import Foundation

/// Extracts only deliberate "remember this" user statements into local memory
/// candidates. Model output, inferred preferences, and unconfirmed plans are
/// deliberately out of scope; callers still have to pass the record through
/// `MemoryStore.write(_:)`, which enforces pause, sensitivity, and Health
/// isolation.
enum MemoryCandidateExtractor {
    static func extractExplicitSave(
        from text: String,
        defaultDomain: MemoryDomain = .chat,
        now: Date = Date()
    ) -> MemoryRecord? {
        let body = explicitBody(in: text)
        guard body.isEmpty == false else { return nil }

        let classifiedDomain = classifyDomain(for: body, defaultDomain: defaultDomain)
        let sensitivity = classifiedDomain == .health ? MemorySensitivity.sensitive : .personal
        return MemoryRecord(
            id: "explicit-\(stableID(for: classifiedDomain.rawValue + ":" + body))",
            domain: classifiedDomain,
            kind: "explicit_user_memory",
            title: title(for: body),
            body: body,
            source: .explicitUserSave,
            sensitivity: sensitivity,
            provenanceIDs: ["explicit-user-save"],
            derivedFromDomain: classifiedDomain == .health ? .health : nil,
            createdAt: now,
            updatedAt: now,
            retentionPolicy: .persistent,
            embeddingState: .none,
            userEditable: true,
            confidence: 1.0
        )
    }

    private static func explicitBody(in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let prefixes = [
            "remember that ",
            "remember: ",
            "please remember ",
            "save this memory: ",
            "记住：",
            "记住:",
            "请记住",
            "帮我记住",
            "以后记得",
        ]
        guard let prefix = prefixes.first(where: { lowercased.hasPrefix($0.lowercased()) }) else {
            return ""
        }
        let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
        return String(trimmed[start...])
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func classifyDomain(for body: String, defaultDomain: MemoryDomain) -> MemoryDomain {
        let lowercased = body.lowercased()
        let healthMarkers = [
            "health", "sleep", "heart rate", "blood pressure", "symptom",
            "medication", "allergy", "睡眠", "心率", "血压", "症状", "药", "过敏",
        ]
        if healthMarkers.contains(where: { lowercased.contains($0) }) {
            return .health
        }
        return defaultDomain
    }

    private static func title(for body: String) -> String {
        if body.count <= 48 {
            return body
        }
        return String(body.prefix(45)) + "..."
    }

    private static func stableID(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
