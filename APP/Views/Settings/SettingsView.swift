import SwiftUI
import UIKit
import Darwin

struct SettingsView: View {
    private let _githubUrl = "https://github.com/pxx917144686/APP"
    @State private var currentIcon = UIApplication.shared.alternateIconName
    
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

extension SettingsView {
    @ViewBuilder
    private func _feedback() -> some View {
        Section {
            Button("提交反馈", systemImage: "safari") {
                if let url = URL(string: "\(_githubUrl)/issues") {
                    UIApplication.shared.open(url)
                }
            }
            Button("👉看看源代码", systemImage: "safari") {
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
            }
            NavigationLink(destination: AppIconView(currentIcon: $currentIcon)) {
                Label("图标", systemImage: "app.badge")
            }
        }
    }
}
