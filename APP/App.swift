import SwiftUI
import OSLog
import UIKit
import Combine

@main
struct FeatherApp: App {
    private let logger = Logger(subsystem: "com.feather.app", category: "FeatherApp")
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var themeManager: ThemeManager
    @StateObject var appStore: AppStore
    
    init() {
        _themeManager = StateObject(wrappedValue: ThemeManager.shared)
        _appStore = StateObject(wrappedValue: AppStore.this)
    }

    func _handleURL(_ url: URL) {
        logger.info("Handling URL: \(url.absoluteString)")
        if url.scheme?.hasPrefix("feather") == true {
            handleFeatherURL(url)
        }
    }
    
    private func handleFeatherURL(_ url: URL) {
        logger.info("Handling Feather URL: \(url.absoluteString)")
    }
	
	var body: some Scene {
		WindowGroup {
			VariedTabbarView()
				.environmentObject(themeManager)
				.environmentObject(appStore)
				.onOpenURL(perform: _handleURL)
				.onAppear {
					if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "Feather.userInterfaceStyle")) {
						UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
					}
					
					UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: UserDefaults.standard.string(forKey: "Feather.userTintColor") ?? "#B496DC"))
				}
		}
	}
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.feather.app", category: "AppDelegate")
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        logger.info("Application did finish launching")
        
        // 应用启动初始化
        self.setupLibraryPaths()
        self.createDocumentsDirectories()
        
        return true
    }
        
    private func setupLibraryPaths() {
        // Tools文件夹已删除，不再需要设置库文件路径
    }
        
    private func createDocumentsDirectories() {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let directories: [URL] = [
            documents.appendingPathComponent("Archives", isDirectory: true),
            documents.appendingPathComponent("Certificates", isDirectory: true),
            documents.appendingPathComponent("Signed", isDirectory: true),
            documents.appendingPathComponent("Unsigned", isDirectory: true)
        ]
        
        for url in directories {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - UIApplication Extension
public extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
