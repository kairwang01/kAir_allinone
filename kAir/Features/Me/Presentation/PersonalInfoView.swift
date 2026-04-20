//
//  PersonalInfoView.swift
//  kAir
//
//  Personal information editor styled after the provided reference.
//

import SwiftUI

struct PersonalInfoView: View {
    @Binding var profile: UserProfileDraft

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AvatarEditorView()
                } label: {
                    ProfileInfoRow(title: "头像")
                }

                NavigationLink {
                    TextFieldEditorView(
                        title: "名字",
                        text: $profile.displayName,
                        placeholder: "输入名字"
                    )
                } label: {
                    ProfileInfoRow(title: "名字", value: profile.displayName)
                }

                NavigationLink {
                    SelectionEditorView(
                        title: "性别",
                        selection: $profile.gender,
                        options: ["", "男", "女", "保密"]
                    )
                } label: {
                    ProfileInfoRow(title: "性别", value: profile.gender)
                }

                NavigationLink {
                    TextFieldEditorView(
                        title: "地区",
                        text: $profile.region,
                        placeholder: "输入地区"
                    )
                } label: {
                    ProfileInfoRow(title: "地区", value: profile.region)
                }

                NavigationLink {
                    TextFieldEditorView(
                        title: "手机号",
                        text: $profile.phoneNumber,
                        placeholder: "输入手机号",
                        keyboardType: .phonePad
                    )
                } label: {
                    ProfileInfoRow(title: "手机号", value: profile.phoneNumber)
                }

                NavigationLink {
                    TextFieldEditorView(
                        title: "ID",
                        text: $profile.userID,
                        placeholder: "输入 ID"
                    )
                } label: {
                    ProfileInfoRow(title: "ID", value: profile.userID)
                }

                NavigationLink {
                    QRCodePlaceholderView(profile: profile)
                } label: {
                    ProfileInfoRow(title: "我的二维码", trailingIcon: "qrcode")
                }

                NavigationLink {
                    SelectionEditorView(
                        title: "模型选择",
                        selection: $profile.preferredModel,
                        options: ["", "Local Mix 8B", "Health Ranker", "Tool Planner"]
                    )
                } label: {
                    ProfileInfoRow(title: "模型选择", value: profile.preferredModel)
                }

                NavigationLink {
                    TextFieldEditorView(
                        title: "签名",
                        text: $profile.signature,
                        placeholder: "输入签名"
                    )
                } label: {
                    ProfileInfoRow(title: "签名", value: profile.signature)
                }
            }

            Section {
                NavigationLink {
                    SelectionEditorView(
                        title: "来电铃声",
                        selection: $profile.ringtone,
                        options: ["默认", "简洁", "静音"]
                    )
                } label: {
                    ProfileInfoRow(title: "来电铃声", value: profile.ringtone)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileInfoRow: View {
    let title: String
    var value: String? = nil
    var trailingIcon: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Color.black)

            Spacer()

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.body)
                    .foregroundStyle(Color.black.opacity(0.32))
            } else if let value, value.isEmpty == false {
                Text(value)
                    .foregroundStyle(Color.black.opacity(0.38))
                    .lineLimit(1)
            }
        }
    }
}

private struct AvatarEditorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.84, blue: 0.89),
                            Color(red: 0.63, green: 0.66, blue: 0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 108, height: 108)
                .overlay(
                    Text("K")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                )

            Text("头像编辑会在下一步接入图片选择和裁剪。")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.46))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 48)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("头像")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QRCodePlaceholderView: View {
    let profile: UserProfileDraft

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .frame(width: 220, height: 220)
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.system(size: 84))
                        .foregroundStyle(Color.black.opacity(0.78))
                )
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)

            Text(profile.userID)
                .font(.headline)
                .foregroundStyle(Color.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("我的二维码")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TextFieldEditorView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        List {
            Section {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SelectionEditorView: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(option.isEmpty ? "未设置" : option)
                            .foregroundStyle(Color.black)

                        Spacer()

                        if selection == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
