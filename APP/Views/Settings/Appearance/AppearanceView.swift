
import SwiftUI
import UIKit

// 提供UIUserInterfaceStyle的所有情况
private extension UIUserInterfaceStyle {
    static var allStyles: [UIUserInterfaceStyle] {
        return [.unspecified, .light, .dark]
    }
    
    var displayName: String {
        switch self {
        case .unspecified: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        @unknown default: return "未知"
        }
    }
}

struct AppearanceView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
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
    
    var body: some View {
        List {
            Section {
                Picker("外观", selection: selectedStyle) {
                    ForEach(UIUserInterfaceStyle.allStyles, id: \.self) { style in
                        Text(style.displayName)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                AppearanceTintColorView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(EmptyView())
            } header: {
                Text("颜色")
            }
        }
    }
}
