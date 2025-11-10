import SwiftUI
import UIKit
import Combine
import Network
import CoreData

@main
struct App: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            TabbarView()
                .environmentObject(themeManager)
                .environmentObject(AppStore.this)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    // 后台完成处理
    var backgroundSessionCompletionHandler: (() -> Void)?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化代码
        return true
    }
    
    // 处理后台URL会话事件
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        
        // 存储完成处理器，供下载管理器使用
        self.backgroundSessionCompletionHandler = completionHandler
        
        // 确保下载管理器被初始化，以便它可以处理后台会话
        let _ = AppStoreDownloadManager.shared
    }
}

// MARK: - Previews
struct App_Previews: SwiftUI.PreviewProvider {
    static var previews: some SwiftUI.View {
        let themeManager = ThemeManager.shared
        TabbarView()
            .environmentObject(themeManager)
            .environmentObject(AppStore.this)
    }
}
