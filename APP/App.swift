import SwiftUI
import UIKit

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

class AppDelegate: NSObject, UIApplicationDelegate {

    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {

        self.backgroundSessionCompletionHandler = completionHandler

        let _ = AppStoreDownloadManager.shared
    }
}

struct App_Previews: SwiftUI.PreviewProvider {
    static var previews: some SwiftUI.View {
        let themeManager = ThemeManager.shared
        TabbarView()
            .environmentObject(themeManager)
            .environmentObject(AppStore.this)
    }
}
