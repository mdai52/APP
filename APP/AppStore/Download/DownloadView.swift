//
//  DownloadView.swift
//  Created by pxx917144686 on 2025/09/04.
//

import SwiftUI
import Combine
import Foundation
import Network

#if canImport(UIKit)
import UIKit
import SafariServices
#endif
#if canImport(Vapor)
import Vapor
#endif


public struct AppInfo {
    public let name: String
    public let version: String
    public let bundleIdentifier: String
    public let path: String
    public let localPath: String?
    
    public init(name: String, version: String, bundleIdentifier: String, path: String, localPath: String? = nil) {
        self.name = name
        self.version = version
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.localPath = localPath
    }
    
    // 兼容性属性
    public var bundleId: String {
        return bundleIdentifier
    }
}


// DownloadStatus枚举
enum DownloadStatus: String, Codable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

// 全局安装状态管理
@MainActor
class GlobalInstallationManager: ObservableObject, @unchecked Sendable {
    static let shared = GlobalInstallationManager()
    @Published var isAnyInstalling = false
    @Published var currentInstallingRequestId: UUID? = nil
    
    private init() {}
    
    func startInstallation(for requestId: UUID) -> Bool {
        guard !isAnyInstalling else { return false }
        isAnyInstalling = true
        currentInstallingRequestId = requestId
        return true
    }
    
    func finishInstallation() {
        isAnyInstalling = false
        currentInstallingRequestId = nil
    }
    
    // 带requestId参数的重载方法，用于验证当前安装任务
    func finishInstallation(for requestId: UUID) {
        // 只有当前正在安装的任务才能被完成
        if currentInstallingRequestId == requestId || currentInstallingRequestId == nil {
            isAnyInstalling = false
            currentInstallingRequestId = nil
        }
    }
}

// HTTP服务器管理器
@MainActor
class HTTPServerManager: ObservableObject, @unchecked Sendable {
    static let shared = HTTPServerManager()
    private var activeServers: [UUID: SimpleHTTPServer] = [:]
    
    private init() {}
    
    func startServer(for requestId: UUID, port: Int, ipaPath: String, appInfo: AppInfo) {
        let server = SimpleHTTPServer(port: port, ipaPath: ipaPath, appInfo: appInfo)
        server.start()
        activeServers[requestId] = server
        NSLog("🚀 [HTTPServerManager] 启动服务器，端口: \(port)，请求ID: \(requestId)")
    }
    
    func stopServer(for requestId: UUID) {
        if let server = activeServers[requestId] {
            server.stop()
            activeServers.removeValue(forKey: requestId)
            NSLog("🛑 [HTTPServerManager] 停止服务器，请求ID: \(requestId)")
        }
    }
    
    func stopAllServers() {
        for (requestId, server) in activeServers {
            server.stop()
            NSLog("🛑 [HTTPServerManager] 停止服务器，请求ID: \(requestId)")
        }
        activeServers.removeAll()
        NSLog("🛑 [HTTPServerManager] 已停止所有服务器")
    }
}
#if canImport(ZipArchive)
import ZipArchive
#endif

// MARK: - 现代卡片样式
struct ModernCard<Content: SwiftUI.View>: SwiftUI.View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some SwiftUI.View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
    }
}

// MARK: - Safari网页视图
#if canImport(UIKit)
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    
    init(url: URL, isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.url = url
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC.delegate = context.coordinator
        
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // 更新UI控制器
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariWebView
        
        init(_ parent: SafariWebView) {
            self.parent = parent
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.isPresented = false
            parent.onDismiss?()
        }
        
        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            if didLoadSuccessfully {
                NSLog("✅ [Safari WebView] 页面加载成功: \(parent.url)")
            } else {
                NSLog("❌ [Safari WebView] 页面加载失败: \(parent.url)")
            }
        }
    }
}
#endif

// MARK: - 必要的类型定义
public enum PackageInstallationError: Error, LocalizedError {
    case invalidIPAFile
    case installationFailed(String)
    case networkError
    case timeoutError
    
    public var errorDescription: String? {
        switch self {
        case .invalidIPAFile:
            return "无效的IPA文件"
        case .installationFailed(let reason):
            return "安装失败: \(reason)"
        case .networkError:
            return "网络错误"
        case .timeoutError:
            return "安装超时"
        }
    }
}

// MARK: - CORS中间件
#if canImport(Vapor)
struct CORSMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return next.respond(to: request).map { response in
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, OPTIONS")
            response.headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type, Authorization")
            return response
        }
    }
}
#endif

// MARK: - HTTP功能器
#if canImport(Vapor)
class SimpleHTTPServer: NSObject, @unchecked Sendable {
    public let port: Int
    private let ipaPath: String
    private let appInfo: AppInfo
    private var app: Application?
    private var isRunning = false
    private let serverQueue = DispatchQueue(label: "simple.server.queue", qos: .userInitiated)
    private var plistData: Data?
    private var plistFileName: String?
    
    // 使用随机端口范围
    static func randomPort() -> Int {
        return Int.random(in: 4000...8000)
    }
    
    init(port: Int, ipaPath: String, appInfo: AppInfo) {
        self.port = port
        self.ipaPath = ipaPath
        self.appInfo = appInfo
        super.init()
    }
    
    // MARK: - UserDefaults相关方法
    static let userDefaultsKey = "SimpleHTTPServer"
    
    static func getSavedPort() -> Int? {
        return UserDefaults.standard.integer(forKey: "\(userDefaultsKey).port")
    }
    
    static func savePort(_ port: Int) {
        UserDefaults.standard.set(port, forKey: "\(userDefaultsKey).port")
        UserDefaults.standard.synchronize()
    }
    
    func start() {
        NSLog("🚀 [HTTP服务器] 启动服务器，端口: \(port)")
        
        // 请求本地网络权限
        requestLocalNetworkPermission { [weak self] granted in
            if granted {
                self?.serverQueue.async { [weak self] in
                    Task { @MainActor in
                        await self?.startSimpleServer()
                    }
                }
            }
        }
    }
    
    private func requestLocalNetworkPermission(completion: @escaping @Sendable (Bool) -> Void) {
        // 创建网络监听器来触发权限对话框
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkPermission")
        
        monitor.pathUpdateHandler = { path in
            // 检查网络可用性
            let hasPermission = path.status == .satisfied || path.status == .requiresConnection
            DispatchQueue.main.async {
                completion(hasPermission)
            }
            monitor.cancel()
        }
        
        monitor.start(queue: queue)
        
        // 5秒后超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            monitor.cancel()
            completion(true) // 默认允许继续
        }
    }
    
    private func startSimpleServer() async {
        do {
            // 创建Vapor应用
            let config = Environment(name: "development", arguments: ["serve"])
            app = try await Application.make(config)
            
            // 配置服务器
            app?.http.server.configuration.port = port
            app?.http.server.configuration.address = .hostname("0.0.0.0", port: port)
            app?.http.server.configuration.tcpNoDelay = true
            app?.http.server.configuration.requestDecompression = .enabled
            app?.http.server.configuration.responseCompression = .enabled
            app?.threadPool = .init(numberOfThreads: 2)
            app?.http.server.configuration.tlsConfiguration = nil
            
            // 设置CORS中间件
            app?.middleware.use(CORSMiddleware())
            
            // 设置路由
            setupSimpleRoutes()
            
            // 启动服务器
            try await app?.execute()
            isRunning = true
            NSLog("✅ [HTTP服务器] 服务器已启动，端口: \(port)")
            
        } catch {
            NSLog("❌ [HTTP服务器] 启动失败: \(error)")
            isRunning = false
        }
    }
    
    private func setupSimpleRoutes() {
        guard let app = app else { return }
        
        // 健康检查端点
        app.get("health") { req -> String in
            return "OK"
        }
        
        // 提供IPA文件功能
        app.get("ipa", ":filename") { [weak self] req -> Response in
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == self.appInfo.bundleIdentifier else {
                return Response(status: .notFound)
            }
            
            guard let ipaData = try? Data(contentsOf: URL(fileURLWithPath: self.ipaPath)) else {
                return Response(status: .notFound)
            }
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/octet-stream")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: ipaData)
            
            return response
        }
        
        // 提供IPA文件服务（直接通过bundleIdentifier访问）
        app.get(":filename") { [weak self] req -> Response in
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == "\(self.appInfo.bundleIdentifier).ipa" else {
                return Response(status: .notFound)
            }
            
            // 检查是否需要签名
            let shouldSign = req.parameters.get("sign") == "1"
            
            // 获取IPA数据
            var ipaData: Data
            if shouldSign {
                // 尝试对IPA文件进行签名
                do {
                    let signedIPAPath = try self.signIPAIfNeeded()
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: signedIPAPath)) else {
                        return Response(status: .internalServerError)
                    }
                    ipaData = data
                } catch {
                    // 如果签名失败，返回原始IPA文件
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: self.ipaPath)) else {
                        return Response(status: .notFound)
                    }
                    ipaData = data
                }
            } else {
                // 直接返回原始IPA文件
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: self.ipaPath)) else {
                    return Response(status: .notFound)
                }
                ipaData = data
            }
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/octet-stream")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: ipaData)
            
            return response
        }
        
        // 提供Plist文件功能
        app.get("plist", ":filename") { [weak self] req -> Response in
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == self.appInfo.bundleIdentifier else {
                return Response(status: .notFound)
            }
            
            let plistData = self.generatePlistData()
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/xml")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: plistData)
            
            return response
        }
        
        // 提供Plist文件功能（通过base64编码的路径）
        app.get("i", ":encodedPath") { [weak self] req -> Response in
            guard let self = self,
                  let encodedPath = req.parameters.get("encodedPath") else {
                return Response(status: .notFound)
            }
            
            // 解码base64路径
            guard let decodedData = Data(base64Encoded: encodedPath.replacingOccurrences(of: ".plist", with: "")),
                  let decodedPath = String(data: decodedData, encoding: .utf8) else {
                return Response(status: .notFound)
            }
            
            NSLog("📄 [APP] 请求plist文件，解码路径: \(decodedPath)")
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/xml")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: self.generatePlistData())
            
            return response
        }
        
        // 安装页面路由
        app.get("install") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // 生成外部manifest URL
            let externalManifestURL = self.generateExternalManifestURL()
            
            // 创建改进的自动安装页面
            let installPage = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>正在安装 \(self.appInfo.name)</title>
                <style>
                    * {
                        box-sizing: border-box;
                    }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        margin: 0;
                        padding: 20px;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        text-align: center;
                        min-height: 100vh;
                        display: flex;
                        flex-direction: column;
                        justify-content: center;
                        align-items: center;
                    }
                    .container {
                        background: rgba(255, 255, 255, 0.1);
                        padding: 30px;
                        border-radius: 20px;
                        backdrop-filter: blur(10px);
                        max-width: 400px;
                        width: 100%;
                        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                    }
                    .app-icon {
                        width: 80px;
                        height: 80px;
                        background: #007AFF;
                        border-radius: 16px;
                        margin: 0 auto 20px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        font-size: 40px;
                        box-shadow: 0 4px 16px rgba(0, 122, 255, 0.3);
                    }
                    .app-info {
                        margin-bottom: 20px;
                    }
                    .app-name {
                        font-size: 24px;
                        font-weight: 600;
                        margin: 0 0 8px 0;
                    }
                    .app-version {
                        font-size: 16px;
                        opacity: 0.8;
                        margin: 0 0 4px 0;
                    }
                    .app-bundle {
                        font-size: 12px;
                        opacity: 0.6;
                        margin: 0;
                    }
                    .status {
                        margin-top: 20px;
                        font-size: 16px;
                        opacity: 0.9;
                        min-height: 24px;
                    }
                    .loading {
                        display: inline-block;
                        width: 20px;
                        height: 20px;
                        border: 3px solid rgba(255,255,255,.3);
                        border-radius: 50%;
                        border-top-color: #fff;
                        animation: spin 1s ease-in-out infinite;
                        margin-right: 10px;
                    }
                    .success {
                        color: #4CAF50;
                    }
                    .error {
                        color: #f44336;
                    }
                    .manual-install {
                        margin-top: 20px;
                        padding: 15px;
                        background: rgba(255, 255, 255, 0.1);
                        border-radius: 10px;
                        font-size: 14px;
                    }
                    .install-button {
                        background: #007AFF;
                        color: white;
                        border: none;
                        padding: 12px 24px;
                        border-radius: 8px;
                        font-size: 16px;
                        font-weight: 600;
                        cursor: pointer;
                        margin-top: 10px;
                        transition: background 0.3s;
                    }
                    .install-button:hover {
                        background: #0056CC;
                    }
                    .install-button:disabled {
                        background: #666;
                        cursor: not-allowed;
                    }
                    @keyframes spin {
                        to { transform: rotate(360deg); }
                    }
                    @keyframes fadeIn {
                        from { opacity: 0; transform: translateY(20px); }
                        to { opacity: 1; transform: translateY(0); }
                    }
                    .fade-in {
                        animation: fadeIn 0.5s ease-out;
                    }
                </style>
            </head>
            <body>
                <div class="container fade-in">
                    <div class="app-icon">📱</div>
                    <div class="app-info">
                        <h1 class="app-name">\(self.appInfo.name)</h1>
                        <p class="app-version">版本 \(self.appInfo.version)</p>
                        <p class="app-bundle">\(self.appInfo.bundleIdentifier)</p>
                    </div>
                    
                    <div class="status" id="status">
                        <span class="loading"></span>正在启动安装程序...
                    </div>
                    
                    <div class="manual-install" id="manualInstall" style="display: none;">
                        <p>如果自动安装失败，请点击下方按钮手动安装：</p>
                        <button class="install-button" id="manualButton" onclick="manualInstall()">
                            手动安装
                        </button>
                    </div>
                </div>
                
                <script>
                    let manifestURL = '';
                    let itmsURL = '';
                    let isInstalling = false; // 防止重复安装
                    let installSuccess = false; // 标记是否已成功启动安装
                    
                    // 页面加载完成后立即自动执行安装
                    window.onload = function() {
                        console.log('页面加载完成，开始自动安装...');
                        initializeInstallation();
                    };
                    
                    function initializeInstallation() {
                        // 使用外部manifest URL
                        manifestURL = '\(externalManifestURL)';
                        itmsURL = 'itms-services://?action=download-manifest&url=' + encodeURIComponent(manifestURL);
                        
                        console.log('Manifest URL:', manifestURL);
                        console.log('ITMS URL:', itmsURL);
                        
                        // 延迟一点时间确保页面完全加载
                        setTimeout(function() {
                            autoInstall();
                        }, 1000);
                    }
                    
                    function autoInstall() {
                        // 防止重复安装
                        if (isInstalling || installSuccess) {
                            console.log('安装正在进行中或已成功，跳过重复调用');
                            return;
                        }
                        
                        const status = document.getElementById('status');
                        const manualInstall = document.getElementById('manualInstall');
                        
                        isInstalling = true;
                        status.innerHTML = '<span class="loading"></span>正在启动安装程序...';
                        
                        console.log('开始安装尝试');
                        
                        try {
                            // 只使用直接跳转方法触发安装
                            window.location.href = itmsURL;
                            status.innerHTML = '<span class="success">✅ 已启动安装程序...</span>';
                            installSuccess = true;
                            
                            console.log('安装程序启动成功');
                            
                            // 如果跳转成功，3秒后显示成功信息
                            setTimeout(function() {
                                if (installSuccess) {
                                    status.innerHTML = '<span class="success">✅ 请查看iPhone桌面~ 遇到问题联系代码作者pxx917144686</span>';
                                    document.body.innerHTML = '<div class="container fade-in" style="text-align: center; padding: 50px; color: white;"><div class="app-icon">✅</div><h1>安装成功</h1><p>请查看iPhone桌面，应用正在安装中...</p><p style="font-size: 12px; opacity: 0.6;">遇到问题请联系源代码作者 pxx917144686</p></div>';
                                }
                            }, 3000);
                            
                        } catch (error) {
                            console.error('安装失败:', error);
                            status.innerHTML = '<span class="error">❌ 安装启动失败</span>';
                            manualInstall.style.display = 'block';
                            isInstalling = false;
                        }
                    }
                    
                    function manualInstall() {
                        if (isInstalling || installSuccess) {
                            console.log('安装正在进行中或已成功，忽略手动安装');
                            return;
                        }
                        
                        const button = document.getElementById('manualButton');
                        const status = document.getElementById('status');
                        
                        button.disabled = true;
                        button.textContent = '正在安装...';
                        status.innerHTML = '<span class="loading"></span>手动触发安装...';
                        isInstalling = true;
                        
                        try {
                            window.location.href = itmsURL;
                            status.innerHTML = '<span class="success">✅ 手动安装已启动</span>';
                            installSuccess = true;
                        } catch (error) {
                            status.innerHTML = '<span class="error">❌ 手动安装失败: ' + error.message + '</span>';
                            button.disabled = false;
                            button.textContent = '重试安装';
                            isInstalling = false;
                        }
                    }
                </script>
            </body>
            </html>
            """
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "text/html")
            response.body = .init(string: installPage)
            
            return response
        }
        
        // 图标路由
        app.get("icon", "display") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // 返回默认图标或从IPA提取的图标
            let iconData = self.getDefaultIconData()
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "image/png")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: iconData)
            
            return response
        }
        
        app.get("icon", "fullsize") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // 返回默认图标或从IPA提取的图标
            let iconData = self.getDefaultIconData()
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "image/png")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: iconData)
            
            return response
        }
        
        
        // 健康检查路由
        app.get("health") { req -> Response in
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/json")
            response.body = .init(string: "{\"status\":\"healthy\",\"timestamp\":\"\(Date().timeIntervalSince1970)\"}")
            return response
        }
    }
    
    func stop() {
        NSLog("🛑 [Simple HTTP功能器] 停止功能器")
        
        serverQueue.async { [weak self] in
            self?.app?.shutdown()
            self?.isRunning = false
        }
    }
    
    func setPlistData(_ data: Data, fileName: String) {
        self.plistData = data
        self.plistFileName = fileName
    }
    
    // MARK: - 生成URL
    private func generateExternalManifestURL() -> String {
        // 创建本地IPA URL
        let localIP = "127.0.0.1"
        let ipaURL = "http://\(localIP):\(port)/\(appInfo.bundleIdentifier).ipa"
        
        // 创建完整的IPA下载URL（包含签名参数）
        let fullIPAURL = "\(ipaURL)?sign=1"
        
        // 使用公共代理服务转发本地URL
        let proxyURL = "https://api.palera.in/genPlist?bundleid=\(appInfo.bundleIdentifier)&name=\(appInfo.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appInfo.name)&version=\(appInfo.version)&fetchurl=\(fullIPAURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullIPAURL)"
        
        NSLog("🔗 [APP] 外部manifest URL: \(proxyURL)")
        
        return proxyURL
    }
    
    // MARK: - 生成Plist文件数据
    private func generatePlistData() -> Data {
        let ipaURL = "http://127.0.0.1:\(port)/\(appInfo.bundleIdentifier).ipa"
        
        let plistContent: [String: Any] = [
            "items": [[
                "assets": [
                    [
                        "kind": "software-package",
                        "url": ipaURL
                    ]
                ],
                "metadata": [
                    "bundle-identifier": appInfo.bundleIdentifier,
                    "bundle-version": appInfo.version,
                    "kind": "software",
                    "title": appInfo.name
                ]
            ]]
        ]
        
        guard let plistData = try? PropertyListSerialization.data(
            fromPropertyList: plistContent,
            format: .xml,
            options: .zero
        ) else {
            return Data()
        }
        
        return plistData
    }
    
    // MARK: - IPA签名方法
    private func signIPAIfNeeded() throws -> String {
        // 由于移除了Zsign依赖，直接返回原始IPA文件
        return ipaPath
    }
    
    // MARK: - 图标处理方法
    private func getDisplayImageURL() -> String {
        // 使用本地服务器提供图标
        return "http://127.0.0.1:\(port)/icon/display"
    }
    
    private func getFullSizeImageURL() -> String {
        // 使用本地服务器提供图标
        return "http://127.0.0.1:\(port)/icon/fullsize"
    }
    
    private func getDefaultIconData() -> Data {
        // 动态图标生成实现
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 57, height: 57))
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 57, height: 57))
        }
        return image.pngData() ?? Data()
        #else
        // 创建一个简单的1x1像素的PNG数据作为默认图标
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
            0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
            0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
        ])
        return pngData
        #endif
    }
}
#endif

struct DownloadView: SwiftUI.View {
    @StateObject private var vm: UnifiedDownloadManager = UnifiedDownloadManager.shared
    @State private var animateCards = false
    @State private var showThemeSelector = false
    @State private var scenePhase: ScenePhase = .active
    @State private var showSafariWebView = false
    @State private var safariURL: URL? = nil
    @State private var showIPAFilesView = false
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject private var globalInstallManager: GlobalInstallationManager

    var body: some SwiftUI.View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                downloadManagementSegmentView
            }
        }

        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showThemeSelector.toggle()
                }) {
                    Image(systemName: themeManager.selectedTheme == .light ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme == .light ? .orange : .blue)
                }
            }
        }
        .overlay(
            FloatingThemeSelector(isPresented: $showThemeSelector)
        )
        // 右下角悬浮按钮
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                showIPAFilesView.toggle()
            }) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding()
                    .background(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding()
            }
            .animation(.spring(), value: animateCards)
        }
        // 历史IPA文件列表视图
        .sheet(isPresented: $showIPAFilesView) {
            IPAListView(isPresented: $showIPAFilesView).environmentObject(themeManager)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[DownloadView] 强制刷新UI")
                withAnimation(.easeInOut(duration: 0.5)) {
                    animateCards = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshUI"))) { _ in
            print("[DownloadView] 接收到强制刷新通知")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[DownloadView] 真机适配强制刷新完成")
                withAnimation(.easeInOut(duration: 0.5)) {
                    animateCards = true
                }
            }
        }
        .onChange(of: scenePhase, perform: handleScenePhaseChange)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            handleAppEnteredBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleAppBecameActive()
        }
        .environmentObject(GlobalInstallationManager.shared)
    }
    
    /// 处理场景阶段变化
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            handleAppEnteredBackground()
        case .active:
            handleAppBecameActive()
        default:
            break
        }
    }
    
    /// 处理应用进入后台
    private func handleAppEnteredBackground() {
        // 保存下载任务状态
        vm.saveDownloadTasks()
        
        // 对于正在下载的任务，确保它们能够在后台继续
        if !vm.activeDownloads.isEmpty {
            print("[DownloadView] 应用进入后台，有\(vm.activeDownloads.count)个活跃下载任务")
        }
    }
    
    /// 处理应用回到前台
    private func handleAppBecameActive() {
        // 恢复下载任务
        vm.restoreDownloadTasks()
        
        // 刷新UI显示
        DispatchQueue.main.async {
            self.animateCards = true
        }
    }

    // MARK: - 下载任务分段视图
    var downloadManagementSegmentView: some SwiftUI.View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                Spacer(minLength: 16)
                
                if vm.downloadRequests.isEmpty {
                    emptyStateView
                        .scaleEffect(animateCards ? 1 : 0.9)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.spring().delay(0.1), value: animateCards)
                } else {
                    downloadRequestsView
                }
                
                Spacer(minLength: 65)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

        
    // MARK: - 下载请求视图
    private var downloadRequestsView: some SwiftUI.View {
        ForEach(Array(vm.downloadRequests.enumerated()), id: \.element.id) { enumeratedItem in
            let index = enumeratedItem.offset
            let request = enumeratedItem.element
            DownloadCardView(
                request: request
            )
            .scaleEffect(animateCards ? 1 : 0.9)
            .opacity(animateCards ? 1 : 0)
            .animation(Animation.spring().delay(Double(index) * 0.1), value: animateCards)
        }
    }

    private var emptyStateView: some SwiftUI.View {
        VStack(spacing: 32) {
            // 图标
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .cornerRadius(24)
                .scaleEffect(animateCards ? 1.1 : 1)
                .opacity(animateCards ? 1 : 0.7)
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: animateCards
                )
            
            Button(action: {
                guard let url = URL(string: "https://github.com/pxx917144686"),
                    UIApplication.shared.canOpenURL(url) else {
                    return
                }
                UIApplication.shared.open(url)
            }) {
                HStack(spacing: 16) {
                    Text("👉看看源代码")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            // 限制最大宽度并居中
            .frame(maxWidth: 200)  // 设置一个合适的最大宽度
            .padding(.horizontal, 8)
            
            // 空状态文本
            VStack(spacing: 8) {
                Text("暂无下载任务")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }

        // MARK: - 下载管理方法
    private func deleteDownload() {
        // 此方法在 DownloadView 中不需要直接实现，因为下载请求是在 DownloadCardView 中处理的
        print("[DownloadView] deleteDownload called")
    }
    
    private func retryDownload() {
        // 此方法在 DownloadView 中不需要直接实现，因为下载请求是在 DownloadCardView 中处理的
        print("[DownloadView] retryDownload called")
    }
    
    // MARK: - 错误检测和App Store跳转
    private func isUnpurchasedAppError() -> Bool {
        // 此方法在 DownloadView 中不需要直接实现，因为错误检测是在 DownloadCardView 中处理的
        return false
    }
    
    private func openAppStore() {
        // 构建通用App Store链接
        let appStoreURL = "https://apps.apple.com/"
        
        guard let url = URL(string: appStoreURL) else {
            print("❌ [App Store] 无法创建App Store链接: \(appStoreURL)")
            return
        }
        
        print("🔗 [App Store] 正在打开App Store链接: \(appStoreURL)")
        
        #if canImport(UIKit)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if success {
                    print("✅ [App Store] 成功打开App Store")
                } else {
                    print("❌ [App Store] 打开App Store失败")
                }
            }
        } else {
            print("❌ [App Store] 无法打开App Store链接")
        }
        #endif
    }
    
}

// MARK: - 下载卡片视图
struct DownloadCardView: SwiftUI.View {
    @ObservedObject var request: DownloadRequest
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var globalInstallManager = GlobalInstallationManager.shared
    
    // 添加状态变量
    @State private var showDetailView = false
    @State private var showInstallView = false
    
    // 安装相关状态
    @State private var isInstalling = false
    @State private var installationProgress: Double = 0.0
    @State private var installationMessage: String = ""
    
    // Safari WebView状态
    @State private var showSafariWebView = false
    @State private var safariURL: URL?
    
    var body: some SwiftUI.View {
        ModernCard {
            VStack(spacing: 16) {
                // APP信息行
                HStack(spacing: 16) {
                    // APP图标
                    AsyncImage(url: URL(string: request.package.iconURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "app.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(10)
                    
                    // APP详细信息 - 与图标紧密组合
                    VStack(alignment: .leading, spacing: 4) {
                        // APP名称
                        Text(request.package.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                         
                        // Bundle ID
                        Text(request.package.bundleIdentifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                         
                        // 版本信息
                        Text("版本 \(request.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                         
                        // 文件大小信息（如果可用）
                        if let localFilePath = request.localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath) {
                            if let fileSize = getFileSize(path: localFilePath) {
                                Text("文件大小: \(fileSize)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 右上角按钮组
                    VStack(spacing: 4) {
                        // 删除按钮
                        Button(action: {
                            deleteDownload()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 分享按钮（仅在下载完成时显示）
                        if request.runtime.status == DownloadStatus.completed,
                           let localFilePath = request.localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath) {
                            Button(action: {
                                shareIPAFile(path: localFilePath)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 进度条 - 显示所有下载相关状态
                if request.runtime.status == DownloadStatus.downloading || 
                   request.runtime.status == DownloadStatus.waiting || 
                   request.runtime.status == DownloadStatus.paused ||
                   request.runtime.progressValue >= 0 {
                    progressView
                }
                
                // 安装进度条 - 显示安装状态
                if isInstalling {
                    installationProgressView
                }
                
                // 操作按钮
                actionButtons
            }
            .padding(16)
        }
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some SwiftUI.View {
        VStack(spacing: 8) {
            // 主要操作按钮
            HStack(spacing: 8) {
                // 下载中、等待或暂停状态时显示取消按钮
                if request.runtime.status == DownloadStatus.downloading || 
                   request.runtime.status == DownloadStatus.waiting || 
                   request.runtime.status == DownloadStatus.paused {
                    Button(action: {
                        cancelDownload()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("取消")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                // 下载失败时显示相应按钮
                if request.runtime.status == DownloadStatus.failed {
                    if isUnpurchasedAppError() {
                        // 未购买应用，显示跳转App Store按钮
                        Button(action: {
                            openAppStore()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "app.badge")
                                Text("此APP疑似没有购买记录，跳转 App Store 购买")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    } else {
                        // 其他错误，显示重试按钮
                        Button(action: {
                            retryDownload()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("重试")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
                
                Spacer()
            }
            
            // 下载完成时显示额外信息和操作按钮
            if request.runtime.status == DownloadStatus.completed {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                         
                        Text("文件已保存到:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                         
                        Spacer()
                         
                        // 安装按钮
                        if let localFilePath = request.localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath) {
                            Button(action: {
                                startInstallation(for: request)
                            }) {
                                HStack(spacing: 6) {
                                    if isInstalling {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else if globalInstallManager.isAnyInstalling && globalInstallManager.currentInstallingRequestId != request.id {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.6))
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                     
                                    if isInstalling {
                                        Text("安装中...")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    } else if globalInstallManager.isAnyInstalling && globalInstallManager.currentInstallingRequestId != request.id {
                                        Text("等待中...")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.6))
                                    } else {
                                        Text("开始安装")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: isInstalling || (globalInstallManager.isAnyInstalling && globalInstallManager.currentInstallingRequestId != request.id) 
                                            ? [Color.gray, Color.gray.opacity(0.8)]
                                            : [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: isInstalling || (globalInstallManager.isAnyInstalling && globalInstallManager.currentInstallingRequestId != request.id) 
                                    ? Color.gray.opacity(0.3) 
                                    : Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isInstalling || (globalInstallManager.isAnyInstalling && globalInstallManager.currentInstallingRequestId != request.id))
                        }
                    }
                    
                    Text(request.localFilePath ?? "未知路径")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 16) // 缩进对齐
                }
                .padding(.horizontal, 4)
            }
        }
        .onTapGesture {
            handleCardTap()
        }
        .sheet(isPresented: $showSafariWebView) {
            if let url = safariURL {
                SafariWebView(
                    url: url,
                    isPresented: $showSafariWebView,
                    onDismiss: {
                        NSLog("🔒 [DownloadCardView] Safari WebView已关闭，清理安装状态")
                        isInstalling = false
                        installationProgress = 0.0
                        GlobalInstallationManager.shared.finishInstallation(for: request.id)
                    }
                )
            }
        }
    }
    
    // MARK: - 卡片点击处理
    private func handleCardTap() {
        switch request.runtime.status {
        case DownloadStatus.completed:
            // 下载完成时，显示安装选项
            if let localFilePath = request.localFilePath, FileManager.default.fileExists(atPath: localFilePath) {
                showInstallView = true
            } else {
                // 如果文件不存在，显示详情页面
                showDetailView = true
            }
        case DownloadStatus.failed:
            // 下载失败时，显示详情页面
            showDetailView = true
        case DownloadStatus.cancelled:
            // 下载取消时，显示详情页面
            showDetailView = true
        default:
            // 其他状态时，显示详情页面
            showDetailView = true
        }
    }
    
    // MARK: - 分享功能
    private func shareIPAFile(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ 文件不存在: \(path)")
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        #if os(iOS)
        // iOS平台使用UIActivityViewController
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // 设置分享标题
        activityViewController.setValue("分享IPA文件", forKey: "subject")
        
        // 获取当前窗口的根视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController { 
            // 在iPad上需要设置popoverPresentationController
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true) {
                print("✅ 分享界面已显示")
            }
        }
        #else
        #endif
    }
    
    private var statusIndicator: some SwiftUI.View {
        Group {
            switch request.runtime.status {
            case DownloadStatus.waiting:
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            case DownloadStatus.downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            case DownloadStatus.paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            case DownloadStatus.completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case DownloadStatus.failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case DownloadStatus.cancelled:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
    }
    
    // MARK: - 下载进度视图
    private var progressView: some SwiftUI.View {
        VStack(spacing: 4) {
            HStack {
                Label(getProgressLabel(), systemImage: getProgressIcon())
                    .font(.headline)
                    .foregroundColor(getProgressColor())
                
                Spacer()
                
                Text("\(Int(request.runtime.progressValue * 100))%")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor)
            }
            
            ProgressView(value: request.runtime.progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: getProgressColor()))
                .scaleEffect(y: 2.0)
            
            HStack {
                Spacer()
                
                Text(request.createdAt.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 安装进度视图
    private var installationProgressView: some SwiftUI.View {
        VStack(spacing: 4) {
            HStack {
                Label("安装进度", systemImage: "arrow.up.circle")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(Int(installationProgress * 100))%")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            ProgressView(value: installationProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 2.0)
            
            Text(installationMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 4)
    }
    
    // 辅助方法...
    private func getProgressLabel() -> String {
        switch request.runtime.status {
        case DownloadStatus.waiting:
            return "等待下载"
        case DownloadStatus.downloading:
            return "正在下载"
        case DownloadStatus.paused:
            return "已暂停"
        case DownloadStatus.completed:
            return "下载完成"
        case DownloadStatus.failed:
            return "下载失败"
        case DownloadStatus.cancelled:
            return "已取消"
        }
    }
    
    private func getProgressIcon() -> String {
        switch request.runtime.status {
        case DownloadStatus.waiting:
            return "clock"
        case DownloadStatus.downloading:
            return "arrow.down.circle"
        case DownloadStatus.paused:
            return "pause.circle"
        case DownloadStatus.completed:
            return "checkmark.circle"
        case DownloadStatus.failed:
            return "xmark.circle"
        case DownloadStatus.cancelled:
            return "xmark.circle"
        }
    }
    
    private func getProgressColor() -> Color {
        switch request.runtime.status {
        case DownloadStatus.waiting:
            return .orange
        case DownloadStatus.downloading:
            return themeManager.accentColor
        case DownloadStatus.paused:
            return .orange
        case DownloadStatus.completed:
            return .green
        case DownloadStatus.failed:
            return .red
        case DownloadStatus.cancelled:
            return .gray
        }
    }
    
    private func getFileSize(path: String) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useGB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("获取文件大小失败: \(error)")
        }
        return nil
    }
    
    private func isUnpurchasedAppError() -> Bool {
        // 检查是否是未购买的错误
        return false
    }
    
    private func openAppStore() {
        // 打开App Store链接
        // 由于DownloadArchive没有itunesItemIdentifier成员，使用通用链接
        if let appStoreURL = URL(string: "https://apps.apple.com/") {
            UIApplication.shared.open(appStoreURL)
        }
    }
    
    private func retryDownload() {
        // 重试下载
        request.runtime.status = DownloadStatus.waiting
        // 这里可以添加重新开始下载的逻辑
    }
    
    private func deleteDownload() {
        // 删除下载
        print("[DownloadCardView] 删除下载: \(request.package.name)")
        
        // 从下载管理器中移除该请求
        UnifiedDownloadManager.shared.deleteDownload(request: request)
        
        // 保存下载任务状态
        UnifiedDownloadManager.shared.saveDownloadTasks()
        
        // 如果有本地文件，删除本地文件
        if let localFilePath = request.localFilePath, FileManager.default.fileExists(atPath: localFilePath) {
            do {
                try FileManager.default.removeItem(atPath: localFilePath)
                print("[DownloadCardView] 已删除本地文件: \(localFilePath)")
            } catch {
                print("[DownloadCardView] 删除本地文件失败: \(error.localizedDescription)")
            }
        }
        
        // 更新UI状态
        NotificationCenter.default.post(name: NSNotification.Name("ForceRefreshUI"), object: nil)
    }
    
    private func cancelDownload() {
        // 取消下载
        print("[DownloadCardView] 取消下载: \(request.package.name)")
        request.runtime.status = DownloadStatus.cancelled
        // 可以添加额外的清理逻辑
    }
    
    private func startInstallation(for request: DownloadRequest) {
        guard let localFilePath = request.localFilePath, FileManager.default.fileExists(atPath: localFilePath) else {
            installationMessage = "IPA文件不存在，请重新下载"
            return
        }
        
        // 开始安装
        isInstalling = true
        installationProgress = 0.0
        installationMessage = "准备安装..."
        
        // 使用全局安装管理器记录正在安装的任务
        let canStart = globalInstallManager.startInstallation(for: request.id)
        guard canStart else {
            installationMessage = "已有安装任务在进行中"
            isInstalling = false
            return
        }
        
        // 创建后台任务，确保应用进入后台时仍能继续安装
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask {  
            // 后台任务即将过期
            NSLog("⏰ [DownloadView] 后台任务即将过期")
            // 直接清理安装
            NSLog("⚠️ [DownloadView] 后台任务过期，清理安装")
        }
        
        // 执行实际的安装逻辑
        Task {
            do {
                // 准备应用信息
                let appInfo = AppInfo(
                    name: request.name,
                    version: request.version,
                    bundleIdentifier: request.bundleIdentifier,
                    path: localFilePath,
                    localPath: localFilePath
                )
                
                // 更新UI：验证安装包
                await MainActor.run {
                    installationProgress = 0.2
                    installationMessage = "验证安装包..."
                }
                
                // 验证IPA文件（简单检查文件大小和扩展名）
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: localFilePath)
                guard let fileSize = fileAttributes[.size] as? Int64, fileSize > 0, 
                      localFilePath.hasSuffix(".ipa") else {
                    throw PackageInstallationError.invalidIPAFile
                }
                
                // 更新UI：启动HTTP服务器
                await MainActor.run {
                    installationProgress = 0.4
                    installationMessage = "启动安装服务..."
                }
                
                // 生成随机端口
                let port = SimpleHTTPServer.randomPort()
                
                // 启动HTTP服务器
                HTTPServerManager.shared.startServer(
                    for: request.id,
                    port: port,
                    ipaPath: localFilePath,
                    appInfo: appInfo
                )
                
                // 保存端口信息
                SimpleHTTPServer.savePort(port)
                
                // 更新UI：准备安装链接
                await MainActor.run {
                    installationProgress = 0.6
                    installationMessage = "准备安装链接..."
                }
                
                // 等待服务器启动（轮询健康检查端点）
                let healthURL = "http://127.0.0.1:\(port)/health"
                var serverReady = false
                for attempt in 1...20 { // 最多等待10秒（20次 * 0.5秒）
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    if let url = URL(string: healthURL) {
                        do {
                            let (_, response) = try await URLSession.shared.data(from: url)
                            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                                serverReady = true
                                NSLog("✅ [DownloadView] 服务器已就绪，第\(attempt)次尝试成功")
                                break
                            }
                        } catch {
                            NSLog("⏳ [DownloadView] 等待服务器启动... 第\(attempt)次尝试")
                        }
                    }
                }
                
                guard serverReady else {
                    NSLog("❌ [DownloadView] HTTP服务器启动超时")
                    await MainActor.run {
                        installationMessage = "安装服务启动超时，请重试"
                        cleanupInstallation(request.id)
                    }
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    return
                }
                
                // 构造安装URL
                let manifestURL = "http://127.0.0.1:\(port)/plist/\(request.bundleIdentifier)"
                guard URL(string: "itms-services://?action=download-manifest&url=\(manifestURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifestURL)") != nil else {
                    NSLog("❌ [DownloadView] 无效的安装链接")
                    await MainActor.run {
                        installationMessage = "无效的安装链接"
                        cleanupInstallation(request.id)
                    }
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    return
                }
                
                // 更新UI：打开安装链接
                await MainActor.run {
                    installationProgress = 0.8
                    installationMessage = "打开安装链接..."
                    
                    // 使用Safari WebView打开本地安装页面，而不是直接打开itms-services链接
                    let localInstallURL = "http://127.0.0.1:\(port)/install"
                    if let installURL = URL(string: localInstallURL) {
                        NSLog("🔗 [DownloadView] 打开本地安装页面: \(localInstallURL)")
                        safariURL = installURL
                        showSafariWebView = true
                    } else {
                        NSLog("❌ [DownloadView] 无效的安装页面URL")
                        installationMessage = "无法创建安装页面，请重试"
                        cleanupInstallation(request.id)
                    }
                }
                
                // Safari WebView已打开，让用户在其中完成安装操作
                // 30秒后自动清理状态，确保用户可以重新点击安装
                await MainActor.run {
                    installationProgress = 1.0
                    installationMessage = "请在Safari中完成安装操作"
                    
                    // 设置定时器，在30秒后清理安装状态（用户已有足够时间确认安装）
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 30) {
                        NSLog("⏰ [DownloadView] 30秒超时，清理安装状态，请求ID: \(request.id)")
                        Task {
                            await MainActor.run {
                                isInstalling = false
                                installationProgress = 0.0
                                GlobalInstallationManager.shared.finishInstallation(for: request.id)
                            }
                        }
                    }
                    
                    // 设置定时器，在5分钟后自动停止HTTP服务器
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 300) {
                        NSLog("⏰ [DownloadView] 自动停止HTTP服务器，请求ID: \(request.id)")
                        Task {
                            await MainActor.run {
                                HTTPServerManager.shared.stopServer(for: request.id)
                            }
                        }
                    }
                }
                
                // 正常流程结束后台任务
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                
            } catch {
                await MainActor.run {
                    installationMessage = error.localizedDescription
                    isInstalling = false
                    installationProgress = 0.0
                    
                    // 清理安装状态
                    GlobalInstallationManager.shared.finishInstallation(for: request.id)
                    HTTPServerManager.shared.stopServer(for: request.id)
                }
                // 错误流程结束后台任务
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }
    }
    

    
    /// 清理安装相关资源
    private func cleanupInstallation(_ requestId: UUID, keepServer: Bool = false) {
        // 使用MainActor更新UI相关属性
        Task {
            await MainActor.run {
                isInstalling = false
                installationProgress = 0.0
                
                // 只在没有其他安装任务时重置消息
                if !GlobalInstallationManager.shared.isAnyInstalling {
                    installationMessage = ""
                }
                
                // 传递requestId给finishInstallation方法
                GlobalInstallationManager.shared.finishInstallation(for: requestId)
                
                // 记录清理操作
                NSLog("🧹 [DownloadView] 清理安装资源，请求ID: \(requestId)，是否保留服务器: \(keepServer)")
                
                if !keepServer {
                    HTTPServerManager.shared.stopServer(for: requestId)
                } else {
                    // 如果保留服务器，设置一个定时器在5分钟后自动停止服务器
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 300) { // 5分钟后
                        NSLog("⏰ [DownloadView] 自动停止HTTP服务器，请求ID: \(requestId)")
                        // 使用Task确保在main actor上调用
                        Task {
                            await MainActor.run {
                                HTTPServerManager.shared.stopServer(for: requestId)
                            }
                        }
                    }
                }
            }
        }
    }
}


// MARK: - IPA文件列表视图
struct IPAListView: SwiftUI.View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @State private var ipaFiles: [(name: String, path: String, size: String, date: Date)] = []
    @State private var isLoading = false
    @State private var selectedFileIndex: Int? = nil
    @State private var showDeleteAlert = false
    @State private var deleteFilePath: String? = nil
    @State private var deleteFileName: String? = nil
    @State private var lastDeleteSuccess = false
    
    var body: some SwiftUI.View {
        NavigationView {
            ZStack {
                themeManager.backgroundColor
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentColor))
                        .scaleEffect(2)
                } else {
                    if ipaFiles.isEmpty {
                        emptyStateView
                    } else {
                        fileListView
                    }
                }
            }
            .navigationTitle("下载记录文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 关闭按钮已移除
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        loadIPAFiles()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            loadIPAFiles()
        }
        .actionSheet(isPresented: $showDeleteAlert) {
            ActionSheet(
                title: Text("删除文件"),
                message: Text("确定要删除文件 \(deleteFileName ?? "") 吗？此操作无法撤销。"),
                buttons: [
                    .destructive(Text("删除"), action: confirmDelete),
                    .cancel(Text("取消"))
                ]
            )
        }
        .alert(isPresented: $lastDeleteSuccess) {
            Alert(
                title: Text("删除成功"),
                message: Text("文件已成功删除。"),
                dismissButton: .default(Text("确定")) { loadIPAFiles() }
            )
        }
    }
    
    private var emptyStateView: some SwiftUI.View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundColor(themeManager.accentColor.opacity(0.5))
            Text("未找到IPA文件")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("未在应用存储目录中发现IPA文件")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var fileListView: some SwiftUI.View {
        List(ipaFiles.indices, id: \.self) { index in
            let file = ipaFiles[index]
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack {
                        Text(file.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(file.date.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button(action: {
                        shareIPAFile(path: file.path, name: file.name)
                    }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {
                        showDeleteConfirmation(for: file.path, name: file.name)
                    }) {
                        Label("删除", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(themeManager.accentColor)
                }
            }
            .padding(.vertical, 8)
        }
        .listStyle(.plain)
        .padding(.top, 8)
    }
    
    // 加载APP项目根目录中的IPA文件
    private func loadIPAFiles() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            // 获取APP文档目录
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            print("[IPAListView] 扫描目录: \(documentDirectory.path)")
            
            // 同时扫描应用沙盒目录下的其他可能包含IPA的目录
            let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            
            // 获取Application Support/Downloads目录（这是实际存储下载IPA文件的目录）
            let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let downloadsDirectory = applicationSupportDirectory.appendingPathComponent("Downloads")
            
            // 扫描多个可能的目录
            let directoriesToScan = [documentDirectory, libraryDirectory, cachesDirectory, downloadsDirectory]
            
            // 筛选IPA文件并获取详细信息
            var files: [(name: String, path: String, size: String, date: Date)] = []
            
            // 扫描所有目录
            for directory in directoriesToScan {
                do {
                    let directoryContents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: .skipsHiddenFiles)
                    
                    for url in directoryContents {
                        if url.pathExtension.lowercased() == "ipa" {
                            let fileName = url.lastPathComponent
                            let filePath = url.path
                            
                            // 获取文件大小
                            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                            let fileSize = attributes[.size] as? Int64 ?? 0
                            let formatter = ByteCountFormatter()
                            formatter.allowedUnits = [.useMB, .useGB]
                            formatter.countStyle = .file
                            let sizeString = formatter.string(fromByteCount: fileSize)
                            
                            // 获取创建日期
                            let creationDate = attributes[.creationDate] as? Date ?? Date()
                            
                            // 检查是否已添加相同路径的文件（避免重复）
                            if !files.contains(where: { $0.path == filePath }) {
                                files.append((name: fileName, path: filePath, size: sizeString, date: creationDate))
                            }
                        }
                    }
                } catch {
                    print("[IPAListView] 扫描目录失败: \(directory.path), 错误: \(error.localizedDescription)")
                }
            }
            
            // 按创建日期倒序排序
            files.sort { $0.date > $1.date }
            
            DispatchQueue.main.async {
                ipaFiles = files
                isLoading = false
            }
        }
    }
    
    // 分享IPA文件
    private func shareIPAFile(path: String, name: String) {
        print("[IPAListView] 分享文件: \(name), 路径: \(path)")
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: path) else {
            print("[IPAListView] 分享失败: 文件不存在: \(path)")
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        #if canImport(UIKit)
        // iOS平台的分享实现
        // 获取顶层视图控制器
        guard let topViewController = getTopViewController() else {
            print("[IPAListView] 分享失败: 无法获取顶层视图控制器")
            return
        }
        
        // 创建分享内容
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // 设置分享标题
        activityViewController.title = name
        
        // 在iPad上设置弹出位置
        if UIDevice.current.userInterfaceIdiom == .pad {
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = topViewController.view
                popover.sourceRect = CGRect(
                    x: topViewController.view.bounds.midX,
                    y: topViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
        }
        
        // 呈现分享界面
        topViewController.present(activityViewController, animated: true) {
            print("[IPAListView] 分享界面已显示: \(name)")
        }
        #else
        // macOS平台的分享实现
        print("[IPAListView] 分享功能在当前平台未实现")
        #endif
    }
    
    // 获取顶层视图控制器的辅助方法
    private func getTopViewController() -> UIViewController? {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topVC = keyWindow.rootViewController else {
            return nil
        }
        
        // 递归查找最顶层的presentedViewController
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        
        return topVC
        #else
        return nil
        #endif
    }
    
    // 显示删除确认
    private func showDeleteConfirmation(for path: String, name: String) {
        print("[IPAListView] 显示删除确认: \(name)")
        deleteFilePath = path
        deleteFileName = name
        showDeleteAlert = true
    }
    
    // 确认删除
    private func confirmDelete() {
        guard let filePath = deleteFilePath else {
            print("[IPAListView] 删除失败: 文件路径为空")
            return
        }
        
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: filePath) else {
                print("[IPAListView] 删除失败: 文件不存在 - \(filePath)")
                return
            }
            
            // 执行删除
            try FileManager.default.removeItem(atPath: filePath)
            print("[IPAListView] 已成功删除文件: \(filePath)")
            
            // 从列表中移除文件
            if let index = ipaFiles.firstIndex(where: { $0.path == filePath }) {
                ipaFiles.remove(at: index)
            }
            
            // 重置删除状态
            deleteFilePath = nil
            deleteFileName = nil
            
            // 显示成功提示
            lastDeleteSuccess = true
        } catch {
            print("[IPAListView] 删除文件失败: \(error.localizedDescription)")
            // 可以添加错误提示
        }
    }
}


struct DownloadView_Previews: PreviewProvider {
    static var previews: some SwiftUI.View {
        NavigationView {
            DownloadView()
        }
        .environmentObject(ThemeManager.shared)
    }
}
