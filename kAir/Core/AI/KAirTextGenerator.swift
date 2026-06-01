//
//  KAirTextGenerator.swift
//  kAir
//
//  On-device assistant text generation. The primary path is Apple Foundation
//  Models (on-device, free, private — iOS 26+); a deterministic generator is the
//  graceful fallback for devices without Apple Intelligence and the test double.
//  Generation is on-device only — no prompt/health/private context is sent off
//  the device here.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// A request to generate an assistant reply.
struct KAirGenerationRequest: Hashable, Sendable {
    let systemInstructions: String
    let prompt: String

    init(systemInstructions: String, prompt: String) {
        self.systemInstructions = systemInstructions
        self.prompt = prompt
    }
}

enum KAirTextGeneratorError: Error, Sendable {
    case unavailable
    case generationFailed
}

/// UI-agnostic metadata about a server model-gateway reply. Carried alongside
/// the reply text so the chat layer can render a tool-result card (model name,
/// token usage, latency, citations) without `Core` depending on any UI type.
struct KAirServerModelInfo: Hashable, Sendable {
    let model: String?
    let finishReason: String?
    let promptTokens: Int?
    let completionTokens: Int?
    let reasoningTokens: Int?
    let totalTokens: Int?
    let latencyMs: Int?
    let citationCount: Int
    let selectedProviderId: String?
}

/// A generated assistant reply. `serverModelInfo` is non-nil only for the
/// server model-gateway path; on-device generators leave it `nil`.
struct KAirGeneratedReply: Hashable, Sendable {
    let text: String
    let serverModelInfo: KAirServerModelInfo?

    init(text: String, serverModelInfo: KAirServerModelInfo? = nil) {
        self.text = text
        self.serverModelInfo = serverModelInfo
    }
}

/// Generates an assistant reply, on-device only.
protocol KAirTextGenerator: Sendable {
    /// Whether on-device generation is ready right now.
    func isAvailable() async -> Bool
    func generate(_ request: KAirGenerationRequest) async throws -> String
    /// Richer variant that may carry structured metadata (e.g. server model
    /// usage) for card rendering. Has a default implementation that wraps
    /// `generate(_:)` with no metadata, so on-device generators need not
    /// implement it.
    func generateReply(_ request: KAirGenerationRequest) async throws -> KAirGeneratedReply
}

extension KAirTextGenerator {
    func generateReply(_ request: KAirGenerationRequest) async throws -> KAirGeneratedReply {
        KAirGeneratedReply(text: try await generate(request))
    }
}

/// Deterministic, always-available, offline reply generator. Honest + grounded:
/// never fabricates facts or gives medical advice. Used as the fallback when
/// Foundation Models is unavailable, and as the test double.
struct DeterministicTextGenerator: KAirTextGenerator {
    func isAvailable() async -> Bool { true }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        let prompt = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else {
            return "I'm here. Ask about your Apple Health overview, or how kAir's on-device AI keeps things private."
        }
        return """
        On-device assistant (offline mode): I can ground answers in your Apple \
        Health snapshot and explain how kAir keeps your data on this device. \
        For "\(Self.summarize(prompt))", tell me a little more and we'll work \
        through it together.
        """
    }

    private static func summarize(_ prompt: String) -> String {
        let collapsed = prompt.replacingOccurrences(of: "\n", with: " ")
        return collapsed.count <= 80 ? collapsed : String(collapsed.prefix(77)) + "…"
    }
}

/// Apple Foundation Models on-device generator (iOS 26+). Throws `.unavailable`
/// when Apple Intelligence is not enabled/supported on the device.
struct FoundationModelsTextGenerator: KAirTextGenerator {
    func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw KAirTextGeneratorError.unavailable
            }
            let session = LanguageModelSession(instructions: request.systemInstructions)
            let response = try await session.respond(to: request.prompt)
            return response.content
        }
        #endif
        throw KAirTextGeneratorError.unavailable
    }
}

/// Tries `primary` when available, else (or on a primary failure) uses
/// `fallback`. The default app generator: Foundation Models with a deterministic
/// fallback so chat always produces a reply.
struct FallbackTextGenerator: KAirTextGenerator {
    let primary: any KAirTextGenerator
    let fallback: any KAirTextGenerator

    func isAvailable() async -> Bool { true }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        if await primary.isAvailable() {
            do {
                return try await primary.generate(request)
            } catch {
                return try await fallback.generate(request)
            }
        }
        return try await fallback.generate(request)
    }

    func generateReply(_ request: KAirGenerationRequest) async throws -> KAirGeneratedReply {
        if await primary.isAvailable() {
            do {
                return try await primary.generateReply(request)
            } catch {
                return try await fallback.generateReply(request)
            }
        }
        return try await fallback.generateReply(request)
    }
}

enum KAirTextGeneratorFactory {
    /// On-device Foundation Models primary, deterministic fallback.
    static func makeDefault() -> any KAirTextGenerator {
        FallbackTextGenerator(
            primary: FoundationModelsTextGenerator(),
            fallback: DeterministicTextGenerator()
        )
    }
}
