//
//  KAirTextGeneratorTests.swift
//  kAirTests
//
//  B6a — on-device text generation layer. Tests the deterministic generator +
//  the fallback composition with stubs. Foundation Models itself is runtime-
//  dependent (Apple Intelligence) and is not invoked here.
//

import XCTest
@testable import kAir

final class KAirTextGeneratorTests: XCTestCase {

    private func request(_ prompt: String) -> KAirGenerationRequest {
        KAirGenerationRequest(systemInstructions: "You are kAir.", prompt: prompt)
    }

    // MARK: - Deterministic generator

    func test_deterministic_isAlwaysAvailable() async {
        let available = await DeterministicTextGenerator().isAvailable()
        XCTAssertTrue(available)
    }

    func test_deterministic_emptyPrompt_returnsInvite() async throws {
        let text = try await DeterministicTextGenerator().generate(request("   \n  "))
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("I'm here"))
    }

    func test_deterministic_groundedReply_isNonDiagnostic() async throws {
        let text = try await DeterministicTextGenerator().generate(request("how is my sleep"))
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("Apple Health"))
        for banned in ["diagnose", "diagnosis", "prescribe", "treatment", "cure"] {
            XCTAssertFalse(text.lowercased().contains(banned), "must stay non-diagnostic: \(banned)")
        }
    }

    // MARK: - Fallback composition

    func test_fallback_usesPrimaryWhenAvailable() async throws {
        let generator = FallbackTextGenerator(
            primary: StubTextGenerator(available: true, result: .success("PRIMARY")),
            fallback: StubTextGenerator(available: true, result: .success("FALLBACK"))
        )
        let text = try await generator.generate(request("hi"))
        XCTAssertEqual(text, "PRIMARY")
    }

    func test_fallback_usesFallbackWhenPrimaryUnavailable() async throws {
        let generator = FallbackTextGenerator(
            primary: StubTextGenerator(available: false, result: .success("PRIMARY")),
            fallback: StubTextGenerator(available: true, result: .success("FALLBACK"))
        )
        let text = try await generator.generate(request("hi"))
        XCTAssertEqual(text, "FALLBACK")
    }

    func test_fallback_usesFallbackWhenPrimaryThrows() async throws {
        let generator = FallbackTextGenerator(
            primary: StubTextGenerator(available: true, result: .failure(.generationFailed)),
            fallback: StubTextGenerator(available: true, result: .success("FALLBACK"))
        )
        let text = try await generator.generate(request("hi"))
        XCTAssertEqual(text, "FALLBACK")
    }

    func test_fallback_isAlwaysAvailable() async {
        let generator = FallbackTextGenerator(
            primary: StubTextGenerator(available: false, result: .success("p")),
            fallback: StubTextGenerator(available: true, result: .success("f"))
        )
        let available = await generator.isAvailable()
        XCTAssertTrue(available)
    }

    // MARK: - Default factory

    func test_factoryDefault_isAvailable() async {
        // FM primary + deterministic fallback → always available.
        let available = await KAirTextGeneratorFactory.makeDefault().isAvailable()
        XCTAssertTrue(available)
    }
}

private struct StubTextGenerator: KAirTextGenerator {
    let available: Bool
    let result: Result<String, KAirTextGeneratorError>

    func isAvailable() async -> Bool { available }

    func generate(_ request: KAirGenerationRequest) async throws -> String {
        try result.get()
    }
}
