//
//  AuthView.swift
//  kAir
//
//  Optional email/password sign-in & registration (#13). kAir is fully usable
//  on-device without an account; this surface only appears from Settings when
//  `FeatureFlag.serverAuthEnabled` is on, and is dormant in the local-first v1.
//
//  The view is a thin, fully-validated shell over `AuthFormModel`: it owns only
//  presentation concerns (focus, password reveal) and delegates all logic to the
//  model. Designed for Dynamic Type, VoiceOver, and iPad width.
//

import SwiftUI

struct AuthView: View {
    @Bindable var model: AuthFormModel
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?
    @State private var isPasswordRevealed = false

    private enum Field: Hashable { case email, password }

    /// Read-through binding for the mode segments (model owns the setter so it
    /// can clear stale errors on a mode change).
    private var modeBinding: Binding<AuthFormModel.Mode> {
        Binding(get: { model.mode }, set: { model.setMode($0) })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        modePicker
                        fieldCard
                        if let error = model.errorMessage {
                            errorBanner(error)
                        }
                        submitButton
                        switchModeLink
                        footnote
                    }
                    .padding(24)
                    .frame(maxWidth: 480)                 // keep the form readable on iPad
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(model.mode.actionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }
            }
            .onChange(of: focusedField) { previous, _ in
                // Reveal inline validation only after a field has been left.
                if previous == .email { model.hasBlurredEmail = true }
                if previous == .password { model.hasBlurredPassword = true }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Palette.accentStrong)
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppTheme.Palette.textOnStrong)
            }
            .accessibilityHidden(true)

            Text(model.mode.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Text("An account is optional — it only syncs your membership across devices.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        Picker("Account mode", selection: modeBinding) {
            ForEach(AuthFormModel.Mode.allCases, id: \.self) { mode in
                Text(mode.segmentTitle).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("auth.modePicker")
    }

    // MARK: - Fields

    private var fieldCard: some View {
        KAirSurface {
            VStack(spacing: 0) {
                fieldRow(
                    icon: "envelope",
                    error: model.emailValidationMessage,
                    trailing: { EmptyView() }
                ) {
                    TextField("you@example.com", text: $model.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }
                        .accessibilityLabel("Email")
                        .accessibilityIdentifier("auth.email")
                }

                Divider().overlay(AppTheme.Palette.line)

                fieldRow(
                    icon: "lock",
                    error: model.passwordValidationMessage,
                    trailing: { passwordRevealToggle }
                ) {
                    passwordField
                        .textContentType(model.mode == .signIn ? .password : .newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .onSubmit { Task { await submit() } }
                        .accessibilityLabel("Password")
                        .accessibilityIdentifier("auth.password")
                }
            }
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        let placeholder = "At least \(AuthFormModel.minimumPasswordLength) characters"
        if isPasswordRevealed {
            TextField(placeholder, text: $model.password)
        } else {
            SecureField(placeholder, text: $model.password)
        }
    }

    private var passwordRevealToggle: some View {
        Button {
            isPasswordRevealed.toggle()
        } label: {
            Image(systemName: isPasswordRevealed ? "eye.slash" : "eye")
                .foregroundStyle(AppTheme.Palette.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPasswordRevealed ? "Hide password" : "Show password")
    }

    /// One labelled input row: leading glyph, the field, an optional trailing
    /// control, and an animated inline validation message beneath it.
    private func fieldRow<FieldContent: View, Trailing: View>(
        icon: String,
        error: String?,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder field: () -> FieldContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .frame(width: 22)

                field()
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                trailing()
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.danger)
                    .padding(.leading, 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.18), value: error)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(AppTheme.Palette.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            AppTheme.Palette.danger.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityIdentifier("auth.error")
        .transition(.opacity)
    }

    // MARK: - Actions

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if model.isSubmitting {
                    ProgressView().tint(AppTheme.Palette.textOnStrong)
                }
                Text(model.mode.actionTitle)
                    .font(.headline)
            }
            .foregroundStyle(AppTheme.Palette.textOnStrong)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                AppTheme.Palette.accentStrong.opacity(model.canSubmit ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(model.canSubmit == false)
        .accessibilityIdentifier("auth.submit")
    }

    private var switchModeLink: some View {
        Button(model.mode.switchPrompt) {
            withAnimation(.easeInOut(duration: 0.2)) { model.toggleMode() }
            focusedField = nil
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.Palette.accent)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("auth.switchMode")
    }

    private var footnote: some View {
        Text("kAir stores only your email. Your chats and Apple Health data stay on this device.")
            .font(.caption)
            .foregroundStyle(AppTheme.Palette.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Resign focus (so the keyboard dismisses) and run the model's submit.
    private func submit() async {
        focusedField = nil
        await model.submit()
    }
}

#Preview("Sign in") {
    AuthView(model: AuthFormModel(submit: { _, _, _ in }))
}

#Preview("Register") {
    AuthView(model: AuthFormModel(mode: .register, submit: { _, _, _ in }))
}
