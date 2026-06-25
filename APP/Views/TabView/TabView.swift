import SwiftUI

enum TabEnum: String, CaseIterable, Hashable {
    case settings
    case tfapps
    case downloads
    case search

    var title: String {
        switch self {
        case .settings:  return "设置"
        case .tfapps:     return "TF版"
        case .downloads:  return "下载"
        case .search:     return "搜索"
        }
    }

    var icon: String {
        switch self {
        case .settings:  return "gearshape.2"
        case .downloads:  return "tray.and.arrow.down"
        case .tfapps:     return "star.circle"
        case .search:     return "magnifyingglass"
        }
    }

    @ViewBuilder
    static func view(for tab: TabEnum, themeManager: ThemeManager) -> some View {
        switch tab {
        case .settings:
            SettingsView()
                .environmentObject(themeManager)
        case .downloads:
            NavigationView {
                DownloadView()
                    .environmentObject(themeManager)
            }
        case .tfapps:
            NavigationView {
                TFAppsView()
                    .environmentObject(themeManager)
            }
        case .search:
            NavigationView {
                SearchView()
                    .environmentObject(themeManager)
            }
        }
    }
}

struct TabbarView: View {
    @State private var selectedTab: TabEnum = .settings
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        TabView(selection: $selectedTab) {

            TabEnum.view(for: .settings, themeManager: themeManager)
                .tabItem {
                    Image(systemName: TabEnum.settings.icon)
                    Text(TabEnum.settings.title)
                }
                .tag(TabEnum.settings)

            TabEnum.view(for: .tfapps, themeManager: themeManager)
                .tabItem {
                    Image(systemName: TabEnum.tfapps.icon)
                    Text(TabEnum.tfapps.title)
                }
                .tag(TabEnum.tfapps)

            TabEnum.view(for: .downloads, themeManager: themeManager)
                .tabItem {
                    Image(systemName: TabEnum.downloads.icon)
                    Text(TabEnum.downloads.title)
                }
                .tag(TabEnum.downloads)

            TabEnum.view(for: .search, themeManager: themeManager)
                .tabItem {
                    Image(systemName: TabEnum.search.icon)
                    Text(TabEnum.search.title)
                }
                .tag(TabEnum.search)
        }
        .tint(themeManager.accentColor)
        .background(themeManager.backgroundColor)
    }
}
