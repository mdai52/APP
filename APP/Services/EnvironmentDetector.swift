import Foundation
import UIKit

@objc
enum AppEnvironment: Int {
    case appStore
    case testFlight
    case trollStore
    case jailbroken
    case simulator
    case unknown
}

@objcMembers
final class EnvironmentDetector: NSObject {
    static let shared = EnvironmentDetector()

    let isTrollStore: Bool
    let isJailbroken: Bool
    let isSimulator: Bool
    let currentEnvironment: AppEnvironment

    private override init() {
        #if targetEnvironment(simulator)
        self.isSimulator = true
        self.isTrollStore = false
        self.isJailbroken = false
        self.currentEnvironment = .simulator
        #else
        self.isSimulator = false

        var trollStore = false
        let trollStorePaths = [
            "/Applications/TrollStore.app",
            "/var/mobile/Library/TrollStore"
        ]
        for path in trollStorePaths {
            if FileManager.default.fileExists(atPath: path) {
                trollStore = true
                break
            }
        }
        if !trollStore {
            let bundlePath = Bundle.main.bundlePath
            if bundlePath.hasPrefix("/Applications/") {
                trollStore = true
            }
        }
        self.isTrollStore = trollStore

        var jailbroken = false
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/private/var/stash",
            "/private/var/lib/apt"
        ]
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                jailbroken = true
                break
            }
        }
        self.isJailbroken = jailbroken

        if trollStore {
            self.currentEnvironment = .trollStore
        } else if jailbroken {
            self.currentEnvironment = .jailbroken
        } else if let receiptPath = Bundle.main.appStoreReceiptURL?.path,
                  receiptPath.contains("sandboxReceipt") {
            self.currentEnvironment = .testFlight
        } else if let receiptPath = Bundle.main.appStoreReceiptURL?.path,
                  receiptPath.contains("receipt") {
            self.currentEnvironment = .appStore
        } else {
            self.currentEnvironment = .unknown
        }
        #endif

        super.init()
    }

    var environmentDescription: String {
        switch currentEnvironment {
        case .appStore: return "App Store"
        case .testFlight: return "TestFlight"
        case .trollStore: return "TrollStore"
        case .jailbroken: return "Jailbroken"
        case .simulator: return "Simulator"
        case .unknown: return "Unknown"
        }
    }
}
