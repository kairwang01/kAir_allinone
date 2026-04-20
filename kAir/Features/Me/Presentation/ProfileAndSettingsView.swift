//
//  ProfileAndSettingsView.swift
//  kAir
//
//  Account center sheet opened from the chat avatar.
//

import SwiftUI

struct ProfileAndSettingsView: View {
    let bootstrap: AppBootstrap

    @Environment(\.dismiss) private var dismiss

    @State private var profile = UserProfileDraft.sample

    var body: some View {
        ZStack {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    SettingsSheetHeader(onClose: close)

                    ProfileHeroSection(profile: $profile)

                    SettingsSectionLabel(title: "账户")

                    SettingsGroupCard {
                        SettingsStaticRow(
                            icon: "envelope",
                            title: "电子邮件",
                            value: profile.emailAddress
                        )

                        SettingsStaticRow(
                            icon: "phone",
                            title: "电话号码",
                            value: profile.phoneNumber
                        )

                        SettingsNavigationRow(
                            icon: "person.badge.shield.checkmark",
                            title: "年龄验证"
                        ) {
                            SettingsPlaceholderView(
                                title: "年龄验证",
                                summary: "年龄验证入口会在下一步接入实际的身份确认流程。"
                            )
                        }

                        SettingsStaticRow(
                            icon: "plus.square.on.square",
                            title: "订阅",
                            value: profile.subscriptionPlan
                        )

                        SettingsNavigationRow(
                            icon: "sparkles",
                            title: "升级到 kAir Pro"
                        ) {
                            SettingsPlaceholderView(
                                title: "升级到 kAir Pro",
                                summary: "后续这里会接入更强的本地模型、更多工具额度和高级能力管理。"
                            )
                        }

                        SettingsNavigationRow(
                            icon: "arrow.clockwise",
                            title: "恢复购买"
                        ) {
                            SettingsPlaceholderView(
                                title: "恢复购买",
                                summary: "购买恢复入口保留在这里，当前版本先作为占位页。"
                            )
                        }

                        SettingsNavigationRow(
                            icon: "doc.text",
                            title: "订单",
                            showsDivider: false
                        ) {
                            SettingsPlaceholderView(
                                title: "订单",
                                summary: "订单与订阅记录会在后续接入真实数据。"
                            )
                        }
                    }

                    SettingsSectionLabel(title: "应用")

                    SettingsGroupCard {
                        SettingsNavigationRow(
                            icon: "switch.2",
                            title: "个性化"
                        ) {
                            SettingsPlaceholderView(
                                title: "个性化",
                                summary: "这里将统一管理聊天偏好、默认工具、语言和界面细节。"
                            )
                        }

                        SettingsNavigationRow(
                            icon: "bell",
                            title: "通知"
                        ) {
                            SettingsPlaceholderView(
                                title: "通知",
                                summary: "消息提醒、任务通知和系统更新提醒会在这里统一配置。"
                            )
                        }

                        SettingsNavigationRow(
                            icon: "cpu",
                            title: "模型与运行",
                            value: "Local-first"
                        ) {
                            SettingsPlaceholderView(
                                title: "模型与运行",
                                summary: "当前策略是本地优先。后续这里会集中管理模型下载、默认运行时和设备兼容策略。"
                            )
                        }

                        SettingsStaticRow(
                            icon: "lock.shield",
                            title: "隐私策略",
                            value: "On-device",
                            showsDivider: false
                        )
                    }

                    SettingsSectionLabel(title: "开发者")

                    SettingsGroupCard {
                        SettingsNavigationRow(
                            icon: "waveform.path.ecg",
                            title: "Surface Entry Replay",
                            value: surfaceEntrySummaryLabel,
                            showsDivider: false
                        ) {
                            SurfaceEntryReplayPanel(lab: bootstrap.matchingReplayLab)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var surfaceEntrySummaryLabel: String {
        let summary = bootstrap.matchingReplayLab.surfaceEntryInvariantSummary
        return "\(summary.totalChains) chains • \(summary.allPassed ? "ok" : "check")"
    }

    private func close() {
        bootstrap.isProfilePresented = false
        dismiss()
    }
}

private struct SettingsSheetHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)

            Spacer()

            Text("设置")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Spacer()

            Button(action: onClose) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ProfileHeroSection: View {
    @Binding var profile: UserProfileDraft

    private var initials: String {
        let components = profile.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()

        if components.isEmpty == false {
            return components.uppercased()
        }

        return String(profile.userID.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color(red: 0.36, green: 0.69, blue: 0.61))
                .frame(width: 92, height: 92)
                .overlay(
                    Text(initials)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                )

            VStack(spacing: 4) {
                Text(profile.displayName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text(profile.userID)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }

            NavigationLink {
                PersonalInfoView(profile: $profile)
            } label: {
                Text("编辑个人资料")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.96))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.Palette.lineStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

private struct SettingsSectionLabel: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textMuted)

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

private struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SettingsStaticRow: View {
    let icon: String
    let title: String
    let value: String
    var showsDivider = true

    var body: some View {
        VStack(spacing: 0) {
            SettingsRowContent(
                icon: icon,
                title: title,
                value: value,
                showsChevron: false
            )

            if showsDivider {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }
}

private struct SettingsNavigationRow<Destination: View>: View {
    let icon: String
    let title: String
    let value: String?
    let showsDivider: Bool
    let destination: Destination

    init(
        icon: String,
        title: String,
        value: String? = nil,
        showsDivider: Bool = true,
        @ViewBuilder destination: () -> Destination
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.showsDivider = showsDivider
        self.destination = destination()
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                destination
            } label: {
                SettingsRowContent(
                    icon: icon,
                    title: title,
                    value: value,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            if showsDivider {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }
}

private struct SettingsRowContent: View {
    let icon: String
    let title: String
    let value: String?
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .frame(width: 22)

            Text(title)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Spacer(minLength: 12)

            if let value, value.isEmpty == false {
                Text(value)
                    .font(.body)
                    .foregroundStyle(AppTheme.Palette.textMuted)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textMuted.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

private struct SettingsPlaceholderView: View {
    let title: String
    let summary: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                KAirSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UserProfileDraft: Equatable {
    var displayName: String
    var emailAddress: String
    var gender: String
    var region: String
    var phoneNumber: String
    var userID: String
    var preferredModel: String
    var signature: String
    var ringtone: String
    var subscriptionPlan: String

    static let sample = UserProfileDraft(
        displayName: "test user",
        emailAddress: "test@kair.com",
        gender: "",
        region: "",
        phoneNumber: "+1 7808888888",
        userID: "test user",
        preferredModel: "Local Mix 8B",
        signature: "",
        ringtone: "默认",
        subscriptionPlan: "kAir Local"
    )
}
