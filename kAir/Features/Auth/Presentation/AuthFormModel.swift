//
//  AuthFormModel.swift
//  kAir
//
//  Presentation logic for the optional email/password account form (#13).
//
//  kAir is local-first: an account is never required to use the app. Signing in
//  only syncs server-side entitlements across devices, and the whole feature is
//  gated behind `FeatureFlag.serverAuthEnabled` (off in the local-first v1).
//  Because kAir offers no third-party / social login, Sign in with Apple is not
//  required (App Store Guideline 4.8).
//
//  This model is intentionally decoupled from the network layer: the actual
//  authentication is performed by an injected `Submit` closure, so validation,
//  the sign-in/register mode, inline field errors, and the submit lifecycle are
//  all unit-testable without a live `KAirServerAPIClient`.
//

import Foundation
import Observation

@MainActor
@Observable
final class AuthFormModel {

    // MARK: - Mode

    /// Whether the form signs into an existing account or creates a new one.
    enum Mode: Hashable, Sendable, CaseIterable {
        case signIn
        case register

        /// Navigation-title / large-title text for the form.
        var title: String {
            switch self {
            case .signIn: return "Welcome back"
            case .register: return "Create your account"
            }
        }

        /// Primary call-to-action button label.
        var actionTitle: String {
            switch self {
            case .signIn: return "Sign in"
            case .register: return "Create account"
            }
        }

        /// Short label used by the mode selector segments.
        var segmentTitle: String {
            switch self {
            case .signIn: return "Sign in"
            case .register: return "Register"
            }
        }

        /// Inline link prompting the user to switch to the other mode.
        var switchPrompt: String {
            switch self {
            case .signIn: return "New to kAir? Create an account"
            case .register: return "Already have an account? Sign in"
            }
        }

        var opposite: Mode { self == .signIn ? .register : .signIn }
    }

    /// Performs authentication for `(mode, email, password)`. Injected so the
    /// model is independent of the live client → unit-testable. Inputs are
    /// pre-trimmed (email) before the handler is called.
    typealias Submit = @MainActor (Mode, String, String) async throws -> Void

    // MARK: - Tunables

    /// Minimum accepted password length. Mirrors the server policy; surfaced in
    /// the inline hint so the two never drift silently.
    static let minimumPasswordLength = 8

    // MARK: - Observable state

    private(set) var mode: Mode
    var email = ""
    var password = ""

    /// Set true once the email / password field has lost focus at least once, so
    /// inline validation errors appear only *after* the user has interacted —
    /// never while they are still typing the first characters.
    var hasBlurredEmail = false
    var hasBlurredPassword = false

    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    private let submitHandler: Submit

    init(mode: Mode = .signIn, submit: @escaping Submit) {
        self.mode = mode
        self.submitHandler = submit
    }

    // MARK: - Validation

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmailValid: Bool { Self.isValidEmail(trimmedEmail) }

    var isPasswordValid: Bool { password.count >= Self.minimumPasswordLength }

    /// The submit button is enabled only when both fields are valid and no
    /// request is in flight.
    var canSubmit: Bool { isEmailValid && isPasswordValid && isSubmitting == false }

    /// Inline error under the email field, or `nil` when there is nothing to show
    /// yet (field empty, valid, or not blurred). Showing it only after a blur
    /// keeps the form calm while typing.
    var emailValidationMessage: String? {
        guard hasBlurredEmail, trimmedEmail.isEmpty == false, isEmailValid == false else {
            return nil
        }
        return "Enter a valid email address."
    }

    /// Inline error under the password field; see `emailValidationMessage`.
    var passwordValidationMessage: String? {
        guard hasBlurredPassword, password.isEmpty == false, isPasswordValid == false else {
            return nil
        }
        return "Use at least \(Self.minimumPasswordLength) characters."
    }

    // MARK: - Intents

    /// Switch mode (sign-in ⇄ register), clearing any stale submit error.
    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        errorMessage = nil
    }

    func toggleMode() { setMode(mode.opposite) }

    /// Run the injected authentication handler. No-op if the form is invalid or a
    /// request is already in flight. On failure, maps the error to a friendly
    /// message; on success the caller observes the session state changing.
    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await submitHandler(mode, trimmedEmail, password)
        } catch is CancellationError {
            // Swallow cancellation (e.g. the sheet was dismissed mid-flight).
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Error mapping

    /// Maps a thrown error to a concise, user-facing message. Server error codes
    /// are intentionally NOT echoed verbatim for auth failures (no account
    /// enumeration via distinct 401/404 copy).
    static func message(for error: Error) -> String {
        if let apiError = error as? KAirServerAPIClientError {
            switch apiError {
            case .invalidResponse:
                return "The server returned an unexpected response. Please try again."
            case .missingAccessToken:
                return "Your session expired. Please sign in again."
            case .api(let statusCode, let detail):
                switch statusCode {
                case 401, 403:
                    return "Incorrect email or password."
                case 409:
                    return "An account with that email already exists."
                case 429:
                    return "Too many attempts. Please wait a moment and try again."
                case 500...599:
                    return "kAir's servers are having trouble. Please try again shortly."
                default:
                    return detail.message.isEmpty
                        ? "Request failed (\(statusCode))."
                        : detail.message
                }
            }
        }
        if (error as? URLError) != nil {
            return "Network error. Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }

    // MARK: - Email validation

    /// Pragmatic single-line email check: one `@`, a dotted domain, no spaces.
    /// Deliberately permissive (final correctness is the server's job) but enough
    /// to catch obvious typos before a round-trip.
    static func isValidEmail(_ candidate: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return candidate.range(of: pattern, options: .regularExpression) != nil
    }
}
