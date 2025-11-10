//
//  TabView.swift
//

import SwiftUI


// 标签枚举定义
enum TabEnum: String, CaseIterable, Hashable {
    case settings
    case tfapps
    case downloads
    case search
    
    // 标签标题
    var title: String {
        switch self {
        case .settings:  return "设置"
        case .tfapps:     return "TF版获取"
        case .downloads:  return "下载任务"
        case .search:     return ""
        }
    }
    
    // 标签图标
    var icon: String {
        switch self {
        case .settings:  return "gearshape.2"
        case .downloads:  return "tray.and.arrow.down"
        case .tfapps:     return "star.circle"
        case .search:     return "magnifyingglass"
        }
    }
    
    // 根据标签类型返回对应的视图
    @ViewBuilder
    static func view(for tab: TabEnum, themeManager: ThemeManager) -> some View {
        switch tab {
        case .settings: 
            SettingsView()
                .environmentObject(themeManager)
        case .downloads: 
            DownloadView()
                .environmentObject(themeManager)
        case .tfapps: 
            TFAppsView()
                .environmentObject(themeManager)
        case .search:
            SearchView()
                .environmentObject(themeManager)
        }
    }
}

// 主标签栏视图
struct TabbarView: View {
    @State private var selectedTab: TabEnum = .settings
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        TabView(selection: $selectedTab) {
            // 设置标签
            Tab(TabEnum.settings.title, systemImage: TabEnum.settings.icon, value: TabEnum.settings) {
                TabEnum.view(for: .settings, themeManager: themeManager)
            }
            
            // TF版获取标签
            Tab(TabEnum.tfapps.title, systemImage: TabEnum.tfapps.icon, value: TabEnum.tfapps) {
                TabEnum.view(for: .tfapps, themeManager: themeManager)
            }
            
            // 下载任务标签
            Tab(TabEnum.downloads.title, systemImage: TabEnum.downloads.icon, value: TabEnum.downloads) {
                TabEnum.view(for: .downloads, themeManager: themeManager)
            }
            
            // 搜索标签（独立在右侧）
            Tab(TabEnum.search.title, systemImage: TabEnum.search.icon, value: TabEnum.search, role: .search) {
                TabEnum.view(for: .search, themeManager: themeManager)
            }
        }
        .accentColor(themeManager.accentColor)
        .background(themeManager.backgroundColor)
    }
}
