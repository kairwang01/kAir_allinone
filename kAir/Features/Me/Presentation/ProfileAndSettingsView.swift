//
//  ProfileAndSettingsView.swift
//  kAir
//
//  Profile and control surface for the rebuilt kAir shell.
//

import SwiftUI

struct ProfileAndSettingsView: View {
    let bootstrap: AppBootstrap

    @Environment(\.dismiss) private var dismiss

    @State private var isAuthPresented = false
    @State private var isDeleteConfirmPresented = false

    /// Built once per presentation (see `presentAuth()`). Holding it in `@State`
    /// rather than constructing it inside the `.sheet` builder prevents SwiftUI
    /// from re-creating the form — and discarding in-progress input — on every
    /// re-render while the sheet is open.
    @State private var authModel: AuthFormModel?
    @State private var deleteErrorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppTheme.Metrics.sectionSpacing) {
                    KAirPageHeader(
                        title: "Settings",
                        summary: "kAir runs on your device."
                    )

                    if FeatureFlag.serverAuthEnabled {
                        accountSection
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Privacy")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(KAirLegalCopy.privacyStatement)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            deviceRow(
                                title: "Apple Health",
                                value: bootstrap.healthStore.supportsHealthData ? "Connected" : "Not available"
                            )
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Health & safety")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(KAirLegalCopy.healthDisclaimer)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    KAirSurface(style: .sunken) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            deviceRow(title: "Version", value: Self.appVersion)
                            deviceRow(title: "On-device AI", value: "Apple Foundation Models")
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    bootstrap.isProfilePresented = false
                    dismiss()
                }
                .foregroundStyle(AppTheme.Palette.textPrimary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAuthPresented, onDismiss: { authModel = nil }) {
            if let authModel {
                AuthView(model: authModel)
            }
        }
        .alert("Delete account?", isPresented: $isDeleteConfirmPresented) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await bootstrap.authSession.deleteAccount(using: bootstrap.makeServerClient())
                    } catch {
                        // Surface the failure instead of silently leaving the
                        // user signed in but believing the account was deleted.
                        deleteErrorMessage = "We couldn't delete your account. Check your connection and try again."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently erases your kAir account and server data. Your on-device data is unaffected and this cannot be undone.")
        }
        .alert(
            "Couldn't delete account",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if $0 == false { deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if bootstrap.authSession.isSignedIn {
                    Text("You're signed in. Your membership syncs across your devices.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Sign out") { bootstrap.authSession.signOut() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Button("Delete account", role: .destructive) {
                        isDeleteConfirmPresented = true
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    Text("kAir works fully on-device. Sign in only to sync your membership across devices.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Sign in or create account") { presentAuth() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.accentStrong)
                }
            }
        }
    }

    private func presentAuth() {
        authModel = makeAuthModel()
        isAuthPresented = true
    }

    private func makeAuthModel() -> AuthFormModel {
        AuthFormModel { mode, email, password in
            let client = bootstrap.makeServerClient()
            switch mode {
            case .signIn:
                let pair = try await client.login(email: email, password: password)
                bootstrap.authSession.apply(pair)
            case .register:
                _ = try await client.register(email: email, password: password)
                let pair = try await client.login(email: email, password: password)
                bootstrap.authSession.apply(pair)
            }
            isAuthPresented = false
        }
    }

    private func deviceRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
    }

    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
