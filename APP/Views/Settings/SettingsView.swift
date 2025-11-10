import SwiftUI
import UIKit
import Darwin
import Foundation

struct SettingsView: View {
    private let _githubUrl = "https://github.com/pxx917144686/APP"
    private let _releasesUrl = "https://api.github.com/repos/pxx917144686/APP/releases/latest"
    @State private var currentIcon = UIApplication.shared.alternateIconName
    @State private var isCheckingVersion = false
    @State private var showUpdateAlert = false
    @State private var updateMessage = ""
    @State private var latestVersion = ""
    @EnvironmentObject private var themeManager: ThemeManager
    
    // 从Info.plist读取当前版本信息
    private var currentVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                return "\(version) (Build \(build))"
            }
            return version
        }
        return "未知版本"
    }
    
    var body: some View {
        NavigationView {
            Form {
                _feedback()
                appearanceSection
            }
            .navigationTitle("设置")
            .alert("版本检查", isPresented: $showUpdateAlert) { 
                Button("确定", role: .cancel) {}
                // 如果有新版本，添加一个去下载的按钮
                if !updateMessage.contains("当前已是最新版本") && !updateMessage.contains("失败") && !updateMessage.contains("无法获取") {
                    Button("查看更新") { 
                        if let url = URL(string: "\(_githubUrl)/releases") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } message: {
                Text(updateMessage)
            }
        }
    }
    
    private func checkVersion() async {
        isCheckingVersion = true
        defer { isCheckingVersion = false }
        
        do {
            // 获取当前版本（只使用版本号部分，不包含build号）
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
            
            // 请求最新版本信息
            let (data, _) = try await URLSession.shared.data(from: URL(string: _releasesUrl)!)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let tagName = json?["tag_name"] as? String {
                // 处理标签名，去除v前缀（如果有）
                latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                
                // 比较版本
                if isNewVersion(latestVersion, currentVersion) {
                    updateMessage = "发现新版本：\(latestVersion)\n当前版本：\(currentVersion)"
                    showUpdateAlert = true
                } else {
                    updateMessage = "当前已是最新版本：\(currentVersion)"
                    showUpdateAlert = true
                }
            } else {
                updateMessage = "无法获取版本信息"
                showUpdateAlert = true
            }
        } catch {
            print("检查版本失败：\(error.localizedDescription)")
            updateMessage = "检查版本失败，请稍后重试"
            showUpdateAlert = true
        }
    }
    
    private func isNewVersion(_ latest: String, _ current: String) -> Bool {
        // 简单的版本比较逻辑
        let latestComponents = latest.components(separatedBy: ".")
        let currentComponents = current.components(separatedBy: ".")
        
        for i in 0..<min(latestComponents.count, currentComponents.count) {
            if let latestNum = Int(latestComponents[i]), let currentNum = Int(currentComponents[i]) {
                if latestNum > currentNum {
                    return true
                } else if latestNum < currentNum {
                    return false
                }
            }
        }
        
        // 如果前面的部分都相同，那么较长的版本号更新
        return latestComponents.count > currentComponents.count
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
            Button("👉看看源代码", systemImage: "safari") {
                if let url = URL(string: _githubUrl) {
                    UIApplication.shared.open(url)
                }
            }
            Button("检查版本更新", systemImage: "arrow.triangle.2.circlepath") {
                Task {
                    await checkVersion()
                }
            }
            .disabled(isCheckingVersion)
            
            // 显示当前版本号
            Text("当前版本 " + currentVersion)
                .foregroundStyle(.secondary)
                .font(.subheadline)
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
