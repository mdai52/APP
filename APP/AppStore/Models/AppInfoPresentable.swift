import Foundation
import SwiftUI
import CoreData

/// 定义可显示应用信息的协议
public protocol AppInfoPresentable {
    /// 应用图标
    var icon: String? { get }
    /// 应用名称
    var name: String? { get }
    /// 应用包标识符
    var bundleIdentifier: String? { get }
}

/// 应用信息结构体
public struct PresentableAppInfo: AppInfoPresentable, Identifiable, Hashable {
    /// 唯一标识符
    public let id = UUID()
    
    /// 应用名称
    public let name: String?
    /// 应用版本
    public let version: String
    /// 应用包标识符
    public let bundleIdentifier: String?
    /// 应用路径
    public let path: String
    /// 本地路径
    public let localPath: String?
    /// 应用图标
    public let icon: String?
    
    /// 初始化方法
    public init(
        name: String?,
        version: String,
        bundleIdentifier: String?,
        path: String,
        localPath: String? = nil,
        icon: String? = nil
    ) {
        self.name = name
        self.version = version
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.localPath = localPath
        self.icon = icon
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PresentableAppInfo, rhs: PresentableAppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// 处理过期信息的扩展
extension Date {
    /// 过期信息
    public struct ExpirationInfo {
        /// 过期状态
        public enum Status {
            /// 有效
            case valid
            /// 即将过期
            case expiringSoon
            /// 已过期
            case expired
            
            /// 状态对应的颜色
            var color: Color {
                switch self {
                case .valid: return .green
                case .expiringSoon: return .orange
                case .expired: return .red
                }
            }
        }
        
        /// 过期日期
        public let date: Date
        /// 过期状态
        public let status: Status
        /// 格式化后的日期字符串
        public let formatted: String
        
        /// 状态颜色
        public var color: Color { status.color }
        
        /// 初始化方法
        /// - Parameters:
        ///   - date: 过期日期
        ///   - status: 过期状态
        ///   - formatted: 格式化后的日期字符串
        public init(date: Date, status: Status, formatted: String) {
            self.date = date
            self.status = status
            self.formatted = formatted
        }
    }
}
