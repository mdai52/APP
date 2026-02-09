import SwiftUI
import UIKit
import Darwin
import Foundation

struct SettingsView: View {
    private let _githubUrl = "https://github.com/pxx917144686/APP"
    @State private var currentIcon = UIApplication.shared.alternateIconName
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                _feedback()
                appearanceSection
            }
            .navigationTitle("设置")
        }
    }
}

// 预览扩展
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

extension SettingsView {
    @ViewBuilder
    private func _feedback() -> some View {
        Section {
            Button("提交反馈", systemImage: "safari") {
                if let url = URL(string: "\(_githubUrl)/issues") {
                    UIApplication.shared.open(url)
                }
            }
            Button("看看源代码", systemImage: "safari") {
                if let url = URL(string: _githubUrl) {
                    UIApplication.shared.open(url)
                }
            }
        } footer: {
            Text("有任何问题，或建议，请随时提交。")
        }
    }
    
    private var appearanceSection: some View {
        Section {
            NavigationLink(destination: AppearanceView().environmentObject(ThemeManager.shared)) {
                Label("外观", systemImage: "paintbrush")
                    .foregroundStyle(themeManager.accentColor)
            }
            NavigationLink(destination: AppIconView(currentIcon: $currentIcon)) {
                Label("图标", systemImage: "app.badge")
                    .foregroundStyle(themeManager.accentColor)
            }
        }
    }
}
