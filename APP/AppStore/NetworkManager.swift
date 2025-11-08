//
//  NetworkManager.swift
//  APP
//
//  网络管理模块 - 合并了网络状态监控和网络请求功能
//

import Foundation
import Network
import Combine

/// 网络管理类，负责处理网络请求和监控网络状态
@MainActor
public final class NetworkManager: ObservableObject, @unchecked Sendable {
    /// 单例实例
    public static let shared = NetworkManager()
    
    // MARK: - 网络状态相关属性
    
    /// 当前网络是否连接
    @Published public var isConnected = false
    
    /// 当前连接类型
    @Published public var connectionType: ConnectionType = .unknown
    
    /// 网络状态变更发布者
    public let networkStatePublisher = PassthroughSubject<NWPath, Never>()
    
    /// 连接类型枚举
    public enum ConnectionType: Equatable {
        /// WiFi连接
        case wifi
        /// 蜂窝网络
        case cellular
        /// 有线网络
        case ethernet
        /// 未知网络类型
        case unknown
        
        /// 获取连接类型描述
        public var description: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "蜂窝网络"
            case .ethernet: return "有线网络"
            case .unknown: return "未知网络"
            }
        }
    }
    
    // MARK: - 私有属性
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.feather.app.network")
    private var session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化方法
    
    private init() {
        // 配置URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // 开始监控网络状态
        startMonitoring()
    }
    
    // MARK: - 网络状态监控
    
    /// 开始监控网络状态
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let isConnected = path.status == .satisfied
                let connectionType = self.getConnectionType(path)
                
                // 只在状态变化时更新
                if self.isConnected != isConnected || self.connectionType != connectionType {
                    self.isConnected = isConnected
                    self.connectionType = connectionType
                    self.networkStatePublisher.send(path)
                    
                    if isConnected {
                        print("网络已连接 - 类型: \(connectionType.description)")
                    } else {
                        print("网络连接已断开")
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    /// 获取连接类型
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    // MARK: - 网络请求方法
    
    /// 发送网络请求
    /// - Parameter request: URLRequest 对象
    /// - Returns: 返回 AnyPublisher 包含 Data 和 URLResponse
    public func request(_ request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        return session.dataTaskPublisher(for: request)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    /// 发送 GET 请求
    /// - Parameter url: 请求URL
    /// - Returns: 返回 AnyPublisher 包含 Data 和 URLResponse
    public func get(_ url: URL) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return self.request(request)
    }
    
    /// 发送 POST 请求
    /// - Parameters:
    ///   - url: 请求URL
    ///   - body: 请求体
    /// - Returns: 返回 AnyPublisher 包含 Data 和 URLResponse
    public func post(_ url: URL, body: Data?) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return self.request(request)
    }
    
    /// 发送 JSON 请求
    /// - Parameters:
    ///   - url: 请求URL
    ///   - method: HTTP方法
    ///   - parameters: 参数字典
    /// - Returns: 返回 AnyPublisher 包含 Data 和 URLResponse
    public func jsonRequest(
        url: URL,
        method: String = "GET",
        parameters: [String: Any]? = nil
    ) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }
        
        return self.request(request)
    }
    
    // MARK: - 取消所有请求
    
    /// 取消所有网络请求
    public func cancelAllRequests() {
        session.invalidateAndCancel()
        
        // 重新创建session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    deinit {
        monitor.cancel()
    }
}
