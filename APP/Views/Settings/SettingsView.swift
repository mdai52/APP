import SwiftUI
import UIKit
import Foundation

private extension UIUserInterfaceStyle {
    static var allStyles: [UIUserInterfaceStyle] {
        return [.unspecified, .light, .dark]
    }

    var displayName: String {
        switch self {
        case .unspecified: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        @unknown default: return "未知"
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
        var icons: [AltIcon] = []

        let defaultIcon = AltIcon(displayName: "默认", author: "图标", key: "app")
        icons.append(defaultIcon)

        let alternateIcons = allIcons.filter { $0.key != "app" }
        icons.append(contentsOf: alternateIcons)

        if alternateIcons.isEmpty {
            icons.append(contentsOf: [
                AltIcon(displayName: "Love", author: "图标", key: "kana_love"),
                AltIcon(displayName: "Peek", author: "图标", key: "kana_peek")
            ])
        }

        return icons
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
                appearanceSection
                iconSection
                versionSection
            }
            .navigationTitle("设置")
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
        }
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
            Picker("外观", selection: selectedStyle) {
                ForEach(UIUserInterfaceStyle.allStyles, id: \.self) { style in
                    Text(style.displayName)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("外观")
        }

        Section {
            HStack {
                Label("整体颜色", systemImage: "paintpalette.fill")
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
            Text("颜色")
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
            Text("图标")
        }
    }

    private var versionSection: some View {
        Section {
            HStack {
                Text("版本号")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(version) (\(build))"
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

                    if (icon.key == "app" && currentIcon == nil) || currentIcon == icon.key {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.accentColor, lineWidth: 3)
                            .frame(width: 80, height: 80)

                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundColor(themeManager.accentColor)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 26, height: 26)
                            )
                            .offset(x: 28, y: -28)
                    }
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
