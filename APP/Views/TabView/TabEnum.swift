import SwiftUI

enum TabEnum: String, CaseIterable, Hashable {
	case appstore
	case downloads
	case tfapps
	case settings
	
	var title: String {
		switch self {
		case .settings: 	return "设置"
		case .appstore:		return "AppStore降级"
		case .downloads:	return "下载任务"
		case .tfapps:		return "TF版获取"
		}
	}
	
	var icon: String {
		switch self {
		case .settings: 	return "gearshape.2"
		case .appstore:		return "arrow.down.circle"
		case .downloads:	return "tray.and.arrow.down"
		case .tfapps:		return "star.circle"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .settings: SettingsView()
		case .appstore: SearchView()
		case .downloads: NavigationView { DownloadView() }
		case .tfapps: NavigationView { TFAppsView() }
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.appstore,
			.downloads,
			.tfapps,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return []
	}
}
