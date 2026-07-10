import SwiftUI
import UIKit
import Foundation

private extension UIUserInterfaceStyle {
    static var allStyles: [UIUserInterfaceStyle] {
        return [.unspecified, .light, .dark]
    }

    var displayName: String {
        switch self {
        case .unspecified: return "follow_system".localized
        case .light: return "light_mode".localized
        case .dark: return "dark_mode".localized
        @unknown default: return "none".localized
        }
    }
}

struct SettingsView: View {
    @State private var currentIcon = UIApplication.shared.alternateIconName
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appStore: AppStore

    @AppStorage("APP.userTintColor") private var selectedColorHex: String = "#007AFF"
    @State private var selectedColor = Color(hex: "#007AFF")
    @State private var showingIconSuccess = false
    @State private var isIconLoading = false
    @State private var showAccountSheet = false

    private var selectedStyle: Binding<UIUserInterfaceStyle> {
        Binding(
            get: {
                switch themeManager.selectedTheme {
            case .system: return .unspecified
            case .light: return .light
            case .dark: return .dark
                }
            },
            set: { newStyle in
                switch newStyle {
                case .unspecified: themeManager.selectedTheme = .system
                case .light: themeManager.selectedTheme = .light
                case .dark: themeManager.selectedTheme = .dark
                @unknown default: break
                }
            }
        )
    }

    var allIcons: [AltIcon] {
        let allIcons = AppIconView.getAllIconsFromFolder()

        if !allIcons.isEmpty {
            return allIcons.sorted { icon1, icon2 in
                if icon1.key == "app" { return true }
                if icon2.key == "app" { return false }
                return icon1.key ?? "" < icon2.key ?? ""
            }
        }

        return [
            AltIcon(
                displayName: "icon_default".localized,
                author: "icon_author".localized,
                key: "app"
            ),
            AltIcon(
                displayName: "icon_love".localized,
                author: "icon_author".localized,
                key: "kana_love"
            ),
            AltIcon(
                displayName: "icon_peek".localized,
                author: "icon_author".localized,
                key: "kana_peek"
            )
        ]
    }

    private let presetColorHexes: [String] = [
        "#B496DC", "#848ef9", "#ff7a83", "#4161F1", "#FF00FF",
        "#4CD964", "#FF2D55", "#FF9500", "#4860e8", "#5394F7",
        "#e18aab", "#00CED1", "#228B22", "#FF6347", "#191970",
        "#FFB6C1", "#98FB98", "#E6E6FA", "#FF7F50", "#50C878"
    ]

    private var presetColors: [Color] {
        presetColorHexes.map { Color(hex: $0) }
    }

    var body: some View {
        NavigationView {
            Form {
                accountHeaderSection
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))

                appearanceSection
                languageSection
                iconSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedColor = Color(hex: selectedColorHex)
                currentIcon = UIApplication.shared.alternateIconName
            }
            .onChange(of: selectedColorHex, perform: { newValue in
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    for window in windowScene.windows {
                        window.tintColor = UIColor(Color(hex: newValue))
                    }
                }
                themeManager.objectWillChange.send()
            })
            .sheet(isPresented: $showAccountSheet) {
                AccountSheetView()
                    .environmentObject(appStore)
                    .environmentObject(themeManager)
            }
        }
    }

    private var accountHeaderSection: some View {
        Button(action: {
            showAccountSheet = true
        }) {
            if let account = appStore.selectedAccount {
                HStack(spacing: 16) {
                    ZStack {
                        AccountAvatarButton(size: 64)

                        Circle()
                            .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 72, height: 72)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name.isEmpty ? account.email : account.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if !account.name.isEmpty {
                            Text(account.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Text(flag(country: account.countryCode))
                                .font(.caption)
                            Text(countryName(account.countryCode))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("sign_in_apple_id".localized)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("sign_in_apple_id_desc".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
    }

    private func flag(country: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in country.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s
    }

    private func countryName(_ code: String) -> String {
        let locale = LanguageManager.shared.locale
        return locale.localizedString(forRegionCode: code) ?? code.uppercased()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(AppStore.this)
    }
}

extension SettingsView {
    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            Picker("appearance".localized, selection: selectedStyle) {
                ForEach(UIUserInterfaceStyle.allStyles, id: \.self) { style in
                    Text(style.displayName)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("appearance".localized)
        }

        Section {
            HStack {
                Label("".localized, systemImage: "paintpalette.fill")
                    .foregroundStyle(themeManager.accentColor)

                Spacer()

                HStack(spacing: 12) {
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 2)
                        )

                    Text(selectedColorHex)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedColor == color ? Color.primary : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                            .overlay(
                                selectedColor == color ?
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.4))
                                            .frame(width: 20, height: 20)
                                    ) : nil
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedColor = color
                                    selectedColorHex = color.toHex()
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } header: {
            Text("color".localized)
        }
    }

    private var iconSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(allIcons) { icon in
                    iconItem(icon: icon)
                }
            }
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal, 16)
        } header: {
            Text("icon".localized)
        }
    }

    private var languageSection: some View {
        Section {
            NavigationLink(destination: LanguageSettingsView().environmentObject(themeManager)) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                        )

                    Text("language".localized)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)

                    Spacer()

                    HStack(spacing: 6) {
                        Text(LanguageManager.shared.currentLanguage.flag)
                        Text(LanguageManager.shared.currentLanguage.nativeName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("general".localized)
        }
    }

    @ViewBuilder
    private func iconItem(icon: AltIcon) -> some View {
        Button {
            isIconLoading = true

            let iconNameToSet = icon.key == "app" ? nil : icon.key

            UIApplication.shared.setAlternateIconName(iconNameToSet) { error in
                DispatchQueue.main.async {
                    isIconLoading = false
                    currentIcon = UIApplication.shared.alternateIconName
                    if error == nil {
                        showingIconSuccess = true
                    } else {
                        print("❌ [AppIcon] 设置图标失败: \(error!.localizedDescription)")
                    }
                }
            }
        } label: {
            VStack(alignment: .center, spacing: 6) {
                ZStack {
                    Image(uiImage: icon.image)
                        .appIconStyle()
                }

                VStack(alignment: .center, spacing: 2) {
                    Text(icon.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    Text(icon.author)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
