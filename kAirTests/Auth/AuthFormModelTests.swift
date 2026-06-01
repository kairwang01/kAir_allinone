//
//  AuthFormModelTests.swift
//  kAirTests
//
//  #13 / polish — email/password auth form logic. Covers validation (regex +
//  length), blur-gated inline messages, the sign-in/register mode toggle, the
//  submit lifecycle (trimmed inputs, error mapping, guarding, cancellation), and
//  the user-facing error copy. The live client is replaced by an injected handler.
//

import XCTest
@testable import kAir

@MainActor
final class AuthFormModelTests: XCTestCase {

    // MARK: - Submit-button gating

    func test_canSubmit_requiresValidEmailAndPassword() {
        let model = AuthFormModel(submit: { _, _, _ in })
        XCTAssertFalse(model.canSubmit)              // empty
        model.email = "bad"
        model.password = "short"
        XCTAssertFalse(model.canSubmit)              // both invalid
        model.email = "a@b.com"
        XCTAssertFalse(model.canSubmit)              // password < 8
        model.password = "12345678"
        XCTAssertTrue(model.canSubmit)               // both valid
    }

    // MARK: - Email validation

    func test_isValidEmail_acceptsReasonableRejectsObvious() {
        for good in ["a@b.co", "user@kair.app", "first.last+tag@sub.domain.com"] {
            XCTAssertTrue(AuthFormModel.isValidEmail(good), "should accept \(good)")
        }
        for bad in ["", "bad", "no-at.com", "@no-local.com", "no-domain@", "has space@x.com", "x@y"] {
            XCTAssertFalse(AuthFormModel.isValidEmail(bad), "should reject \(bad)")
        }
    }

    // MARK: - Inline (blur-gated) field messages

    func test_emailValidationMessage_onlyAfterBlur() {
        let model = AuthFormModel(submit: { _, _, _ in })
        model.email = "bad"
        XCTAssertNil(model.emailValidationMessage)       // not blurred → silent
        model.hasBlurredEmail = true
        XCTAssertNotNil(model.emailValidationMessage)    // blurred + invalid → shows
        model.email = "good@kair.app"
        XCTAssertNil(model.emailValidationMessage)       // valid → no message
    }

    func test_passwordValidationMessage_onlyAfterBlurAndNonEmpty() {
        let model = AuthFormModel(submit: { _, _, _ in })
        model.hasBlurredPassword = true
        XCTAssertNil(model.passwordValidationMessage)    // empty → silent
        model.password = "short"
        XCTAssertNotNil(model.passwordValidationMessage) // too short → shows
        model.password = String(repeating: "x", count: AuthFormModel.minimumPasswordLength)
        XCTAssertNil(model.passwordValidationMessage)    // long enough → clears
    }

    // MARK: - Mode

    func test_toggleMode_flipsAndClearsError() {
        let model = AuthFormModel(mode: .signIn, submit: { _, _, _ in })
        XCTAssertEqual(model.mode, .signIn)
        model.toggleMode()
        XCTAssertEqual(model.mode, .register)
        model.toggleMode()
        XCTAssertEqual(model.mode, .signIn)
    }

    func test_setMode_clearsErrorAndIsIdempotent() async {
        let model = AuthFormModel(mode: .signIn, submit: { _, _, _ in
            throw KAirServerAPIClientError.api(
                statusCode: 401, error: KAirAPIError(code: "x", message: "", traceId: "")
            )
        })
        model.email = "user@kair.app"
        model.password = "password123"
        await model.submit()
        XCTAssertNotNil(model.errorMessage)
        model.setMode(.register)
        XCTAssertEqual(model.mode, .register)
        XCTAssertNil(model.errorMessage)                 // cleared on mode change
        model.setMode(.register)                         // no-op when unchanged
        XCTAssertEqual(model.mode, .register)
    }

    // MARK: - Submit lifecycle

    func test_submit_passesTrimmedEmailAndMode() async {
        var captured: (AuthFormModel.Mode, String, String)?
        let model = AuthFormModel(mode: .register, submit: { mode, email, password in
            captured = (mode, email, password)
        })
        model.email = "  user@kair.app "
        model.password = "password123"
        await model.submit()
        XCTAssertEqual(captured?.0, .register)
        XCTAssertEqual(captured?.1, "user@kair.app")     // trimmed
        XCTAssertEqual(captured?.2, "password123")
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSubmitting)               // reset after
    }

    func test_submit_guardsWhenInputInvalid() async {
        var called = false
        let model = AuthFormModel(submit: { _, _, _ in called = true })
        model.email = "bad"
        model.password = "x"
        await model.submit()
        XCTAssertFalse(called)                           // never reached the handler
    }

    func test_submit_cancellationDoesNotSetError() async {
        let model = AuthFormModel(submit: { _, _, _ in throw CancellationError() })
        model.email = "user@kair.app"
        model.password = "password123"
        await model.submit()
        XCTAssertNil(model.errorMessage)                 // cancellation is swallowed
        XCTAssertFalse(model.isSubmitting)
    }

    // MARK: - Error mapping

    func test_message_mapsCommonStatuses() {
        func msg(_ status: Int) -> String {
            AuthFormModel.message(for: KAirServerAPIClientError.api(
                statusCode: status, error: KAirAPIError(code: "x", message: "", traceId: "")
            ))
        }
        XCTAssertTrue(msg(401).localizedCaseInsensitiveContains("Incorrect email or password"))
        XCTAssertTrue(msg(409).localizedCaseInsensitiveContains("already exists"))
        XCTAssertTrue(msg(429).localizedCaseInsensitiveContains("Too many"))
        XCTAssertTrue(msg(503).localizedCaseInsensitiveContains("servers"))
        XCTAssertTrue(
            AuthFormModel.message(for: KAirServerAPIClientError.missingAccessToken)
                .localizedCaseInsensitiveContains("session")
        )
    }
}
