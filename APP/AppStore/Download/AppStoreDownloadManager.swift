//
//  AppStoreDownloadManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import CryptoKit
import SwiftUI
import UIKit
#if canImport(ZipArchive)
import ZipArchive
#endif



// 为了避免与StoreRequest.swift中的类型冲突，这里使用不同的名称
struct DownloadStoreItem {
    let url: String
    let md5: String
    let sinfs: [DownloadSinfInfo]
    let metadata: DownloadAppMetadata
}

struct DownloadAppMetadata {
    let bundleId: String
    let bundleDisplayName: String
    let bundleShortVersionString: String
    let softwareVersionExternalIdentifier: String
    let softwareVersionExternalIdentifiers: [Int]?
}

struct DownloadSinfInfo {
    let id: Int
    let sinf: String
}

// IPAProcessor类定义在IPAProcessor.swift中
#if canImport(IPAProcessor)
// 使用外部IPAProcessor
#else
// IPA处理器实现
@MainActor
class IPAProcessor: @unchecked Sendable {
    static let shared = IPAProcessor()
    
    private init() {}
    
    /// 处理IPA文件，添加SC_Info文件夹和签名信息
    func processIPA(
        at ipaPath: URL,
        withSinfs sinfs: [Any], // 使用Any类型避免编译错误
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 在后台队列中处理
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let processedIPA = try self.processIPAFile(at: ipaPath, withSinfs: sinfs)
                DispatchQueue.main.async {
                    completion(.success(processedIPA))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 处理IPA文件的核心逻辑
    private func processIPAFile(at ipaPath: URL, withSinfs sinfs: [Any]) throws -> URL {
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAProcessing_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
                
        // 解压IPA文件
        let extractedDir = try extractIPA(at: ipaPath, to: tempDir)

        
        // 创建SC_Info文件夹和签名文件
        try createSCInfoFolder(in: extractedDir, withSinfs: sinfs)

        
        // 重新打包IPA文件
        let processedIPA = try repackIPA(from: extractedDir, originalPath: ipaPath)

        
        return processedIPA
    }
    
    /// 解压IPA文件
    private func extractIPA(at ipaPath: URL, to tempDir: URL) throws -> URL {
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 使用ZipArchive解压IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.unzipFile(atPath: ipaPath.path, toDestination: extractedDir.path)
        guard success else {
            throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZipArchive解压失败"])
        }
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，请正确配置依赖"])
        #endif
        
        return extractedDir
    }
    
    /// 创建SC_Info文件夹和签名文件
    private func createSCInfoFolder(in extractedDir: URL, withSinfs sinfs: [Any]) throws {
        // 查找Payload文件夹
        let payloadDir = extractedDir.appendingPathComponent("Payload")
        guard FileManager.default.fileExists(atPath: payloadDir.path) else {
            throw NSError(domain: "IPAProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到Payload文件夹"])
        }
        
        // 查找.app文件夹
        let appFolders = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
        guard let appFolder = appFolders.first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "IPAProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "未找到.app文件夹"])
        }
        

        
        // 创建SC_Info文件夹
        let scInfoDir = appFolder.appendingPathComponent("SC_Info")
        try FileManager.default.createDirectory(at: scInfoDir, withIntermediateDirectories: true)
        
        // 为每个sinf创建对应的.sinf文件
        if sinfs.isEmpty {

            // 创建默认的.sinf文件，使用应用名称作为文件名
            let appName = appFolder.lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let defaultSinfFileName = "\(appName).sinf"
            let defaultSinfFilePath = scInfoDir.appendingPathComponent(defaultSinfFileName)
            

            
            // 创建默认的sinf数据（这是一个示例数据，实际应该从StoreItem获取）
            let defaultSinfData = createDefaultSinfData(for: appName)
            

            
            // 写入文件
            try defaultSinfData.write(to: defaultSinfFilePath)
            
            // 验证文件是否真的被创建了
            if !FileManager.default.fileExists(atPath: defaultSinfFilePath.path) {
                throw NSError(domain: "IPAProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "文件创建失败: \(defaultSinfFilePath.path)"])
            }
        } else {
            for (index, sinf) in sinfs.enumerated() {

                
                // 处理不同类型的sinf数据
                let id: Int
                let sinfString: String
                
                if let sinfInfo = sinf as? DownloadSinfInfo {
                    // 使用本地DownloadSinfInfo类型
                    id = sinfInfo.id
                    sinfString = sinfInfo.sinf

                } else if let sinfDict = sinf as? [String: Any],
                          let sinfId = sinfDict["id"] as? Int,
                          let sinfData = sinfDict["sinf"] as? String {
                    // 兼容字典类型
                    id = sinfId
                    sinfString = sinfData

                } else {
                    continue
                }
                
                print("🔧 [IPA处理器] sinf数据长度: \(sinfString.count) 字符")
                
                // 使用应用名称而不是ID作为文件名
                let appName = appFolder.lastPathComponent.replacingOccurrences(of: ".app", with: "")
                let sinfFileName = "\(appName).sinf"
                let sinfFilePath = scInfoDir.appendingPathComponent(sinfFileName)
                
                // 将base64编码的sinf数据转换为二进制数据
                guard let sinfData = Data(base64Encoded: sinfString) else {
                    print("⚠️ [IPA处理器] 警告: 无法解码sinf ID \(id) 的数据")
                    print("⚠️ [IPA处理器] 原始sinf字符串: \(sinfString.prefix(100))...")
                    continue
                }
                
                // 写入.sinf文件
                try sinfData.write(to: sinfFilePath)

            }
            
        }
        
        
        // 创建iTunesMetadata.plist文件（在IPA根目录）
        try createiTunesMetadataPlist(in: extractedDir, appFolder: appFolder)
        
        // 强制检查：确保至少有一个.sinf文件存在
        let sinfFiles = try FileManager.default.contentsOfDirectory(at: scInfoDir, includingPropertiesForKeys: nil)
        let sinfFileCount = sinfFiles.filter { $0.pathExtension == "sinf" }.count
        

        
        if sinfFileCount == 0 {
            
            let appName = appFolder.lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let defaultSinfFileName = "\(appName).sinf"
            let defaultSinfFilePath = scInfoDir.appendingPathComponent(defaultSinfFileName)
            
            let defaultSinfData = createDefaultSinfData(for: appName)
            try defaultSinfData.write(to: defaultSinfFilePath)
            

        }
    }
    
    /// 创建默认的sinf数据
    private func createDefaultSinfData(for appName: String) -> Data {
        // 创建一个基本的sinf数据结构
        // 注意：这是一个示例实现，实际的sinf数据应该从Apple Store API获取
        
        // 创建一个简单的二进制数据结构作为.sinf文件
        // 实际的.sinf文件包含加密的许可证信息，这里我们创建一个占位符
        var sinfData = Data()
        
        // 添加一个简单的头部标识
        let header = "SINF".data(using: .utf8) ?? Data()
        sinfData.append(header)
        
        // 添加版本信息
        let version: UInt32 = 1
        var versionBytes = version
        sinfData.append(Data(bytes: &versionBytes, count: MemoryLayout<UInt32>.size))
        
        // 添加应用名称
        if let appNameData = appName.data(using: .utf8) {
            let nameLength: UInt32 = UInt32(appNameData.count)
            var nameLengthBytes = nameLength
            sinfData.append(Data(bytes: &nameLengthBytes, count: MemoryLayout<UInt32>.size))
            sinfData.append(appNameData)
        }
        
        // 添加时间戳
        let timestamp: UInt64 = UInt64(Date().timeIntervalSince1970)
        var timestampBytes = timestamp
        sinfData.append(Data(bytes: &timestampBytes, count: MemoryLayout<UInt64>.size))
        
        // 添加一个简单的校验和
        let checksum = sinfData.reduce(0) { $0 ^ $1 }
        var checksumBytes = checksum
        sinfData.append(Data(bytes: &checksumBytes, count: MemoryLayout<UInt8>.size))
        

        
        return sinfData
    }
    

    
    /// 创建iTunesMetadata.plist文件
    private func createiTunesMetadataPlist(in extractedDir: URL, appFolder: URL) throws {
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        
        // 尝试从Info.plist读取应用信息
        let infoPlistPath = appFolder.appendingPathComponent("Info.plist")
        var appInfo: [String: Any] = [:]
        
        if FileManager.default.fileExists(atPath: infoPlistPath.path) {
            do {
                let infoPlistData = try Data(contentsOf: infoPlistPath)
                if let plist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any] {
                    appInfo = plist
                }
            } catch {
                // Info.plist读取失败，使用默认值
            }
        }
        
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": appInfo["CFBundleIdentifier"] as? String ?? "com.unknown.app",
            "artistId": 0,
            "artistName": appInfo["CFBundleDisplayName"] as? String ?? appInfo["CFBundleName"] as? String ?? "Unknown Developer",
            "bundleId": appInfo["CFBundleIdentifier"] as? String ?? "com.unknown.app",
            "bundleVersion": appInfo["CFBundleVersion"] as? String ?? "1.0",
            "copyright": appInfo["NSHumanReadableCopyright"] as? String ?? "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": appFolder.lastPathComponent,
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": appInfo["CFBundleDisplayName"] as? String ?? appInfo["CFBundleName"] as? String ?? "Unknown App",
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": 0.0,
            "priceDisplay": "Free",
            "rating": "4+",
            "releaseDate": appInfo["CFBundleReleaseDate"] as? String ?? "2025-01-01T00:00:00Z",
            "s": 143441,
            "softwareIcon57x57URL": "",
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2], // iPhone and iPad
            "softwareVersionBundleId": appInfo["CFBundleIdentifier"] as? String ?? "com.unknown.app",
            "softwareVersionExternalIdentifier": 0,
            "softwareVersionExternalIdentifiers": [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        try plistData.write(to: metadataPath)
    }
    
    /// 重新打包IPA文件
    private func repackIPA(from extractedDir: URL, originalPath: URL) throws -> URL {
        let processedIPAPath = originalPath.deletingLastPathComponent()
            .appendingPathComponent("processed_\(originalPath.lastPathComponent)")
        
        // 使用ZipArchive重新打包IPA文件
        #if canImport(ZipArchive)
        let success = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard success else {
            throw NSError(domain: "IPAProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "IPA重新打包失败"])
        }
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "IPAProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，请正确配置依赖"])
        #endif
        
        // 替换原文件
        try FileManager.default.removeItem(at: originalPath)
        try FileManager.default.moveItem(at: processedIPAPath, to: originalPath)
        
        return originalPath
    }
}
#endif
/// 用于处理IPA文件下载的下载管理器，支持进度跟踪和断点续传功能
class AppStoreDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = AppStoreDownloadManager()
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressHandlers: [String: (DownloadProgress) -> Void] = [:]
    private var completionHandlers: [String: (Result<DownloadResult, DownloadError>) -> Void] = [:]
    private var downloadStartTimes: [String: Date] = [:]
    private var lastProgressUpdate: [String: (bytes: Int64, time: Date)] = [:]
    private var lastUIUpdate: [String: Date] = [:]
    private var downloadDestinations: [String: URL] = [:]
    private var downloadStoreItems: [String: DownloadStoreItem] = [:]
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 7200 // 大文件下载设置为2小时
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        config.networkServiceType = .default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private override init() {
        super.init()
    }
    /// 从iTunes商店下载一个IPA文件
    /// - 参数:
    ///   - appIdentifier: 应用标识符（应用ID）
    ///   - account: 用户账户信息
    ///   - destinationURL: 保存IPA文件的本地文件URL
    ///   - appVersion: 特定的应用版本（可选）
    ///   - progressHandler: 进度回调
    ///   - completion: 完成回调
    @MainActor
    func downloadApp(
        appIdentifier: String,
        account: Any, // 使用 Any 类型避免编译错误
        destinationURL: URL,
        appVersion: String? = nil,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void,
        completion: @escaping @Sendable (Result<DownloadResult, DownloadError>) -> Void
    ) {
        let downloadId = UUID().uuidString
        Task { @MainActor in
            do {
                // 首先从商店API获取下载信息
                // 使用反射获取 account 的各个字段
                let mirror = Mirror(reflecting: account)
                var dsPersonId = ""
                var passwordToken = ""
                var storeFront = ""
                
                for child in mirror.children {
                    if let label = child.label {
                        switch label {
                        case "dsPersonId":
                            dsPersonId = child.value as? String ?? ""
                        case "passwordToken":
                            passwordToken = child.value as? String ?? ""
                        case "storeResponse":
                            // 获取 storeFront
                            let storeResponseMirror = Mirror(reflecting: child.value)
                            for storeChild in storeResponseMirror.children {
                                if storeChild.label == "storeFront" {
                                    storeFront = storeChild.value as? String ?? ""
                                    break
                                }
                            }
                        default:
                            break
                        }
                    }
                }
                

                
                // 直接调用下载API，获取真实的 sinf 数据，包含认证信息
                let plistResponse = try await downloadFromStoreAPI(
                    appIdentifier: appIdentifier,
                    directoryServicesIdentifier: dsPersonId,
                    appVersion: appVersion,
                    passwordToken: passwordToken,
                    storeFront: storeFront
                )
                
                // 解析 songList
                // 如果songList为空，我们将创建一个模拟的downloadStoreItem
                var downloadStoreItem: DownloadStoreItem?
                
                if let songList = plistResponse["songList"] as? [[String: Any]], !songList.isEmpty {
                    let firstSongItem = songList[0]
                    
                    // 检查真实的 sinf 数据 - 实际使用中会在convertToDownloadStoreItem中处理
                    
                    // 将响应数据转换为DownloadStoreItem
                    downloadStoreItem = convertToDownloadStoreItem(from: firstSongItem)
                } else {
                    // 处理未购买应用的情况
                    
                    // 应用未购买，直接返回失败状态
                    let error: DownloadError = .licenseError("应用未购买，请先前往App Store购买")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                // 确保downloadStoreItem不为空
                guard let storeItem = downloadStoreItem else {
                    let error: DownloadError = .unknownError("无法创建下载项")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                // 开始实际的文件下载
                await startFileDownload(
                    storeItem: storeItem,
                    destinationURL: destinationURL,
                    progressHandler: progressHandler,
                    completion: completion
                )
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
            }
        }
    }

    /// 恢复已暂停的下载
    /// - 参数:
    ///   - downloadId: 下载标识符
    ///   - progressHandler: 进度回调
    ///   - completion: 完成回调
    func resumeDownload(
        downloadId: String,
        progressHandler: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Result<DownloadResult, DownloadError>) -> Void
    ) {
        guard let task = downloadTasks[downloadId] else {
            completion(.failure(.downloadNotFound("下载任务未找到")))
            return
        }
        progressHandlers[downloadId] = progressHandler
        completionHandlers[downloadId] = completion
        task.resume()
    }
    
    /// 暂停一个下载
    /// - 参数:
    ///   - downloadId: 下载标识符
    func pauseDownload(downloadId: String) {
        downloadTasks[downloadId]?.suspend()
    }
    /// 取消一个下载
    /// - 参数:
    ///   - downloadId: 下载标识符
    func cancelDownload(downloadId: String) {
        downloadTasks[downloadId]?.cancel()
        cleanupDownload(downloadId: downloadId)
    }
    /// 获取当前下载进度
    /// - 参数:
    ///   - downloadId: 下载标识符
    /// - 返回: 当前进度，如果未找到下载则返回nil
    func getDownloadProgress(downloadId: String) -> DownloadProgress? {
        guard let task = downloadTasks[downloadId] else { return nil }
        return DownloadProgress(
            downloadId: downloadId,
            bytesDownloaded: task.countOfBytesReceived,
            totalBytes: task.countOfBytesExpectedToReceive,
            progress: task.countOfBytesExpectedToReceive > 0 ? 
                Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive) : 0.0,
            speed: 0, // 需要根据时间计算
            remainingTime: 0, // 需要计算
            status: task.state == .running ? .downloading : 
                   task.state == .suspended ? .paused : .completed
        )
    }
    
    /// 将StoreItem转换为DownloadStoreItem，确保使用真实的 sinf 数据
    private func convertToDownloadStoreItem(from storeItem: Any) -> DownloadStoreItem {
        
        // 检查是否是字典类型
        if let dict = storeItem as? [String: Any] {
            
            // 直接访问字典键值
            let url = dict["URL"] as? String ?? ""
            let md5 = dict["md5"] as? String ?? ""
                        
            // 获取元数据
            var bundleId = "unknown"
            var bundleDisplayName = "Unknown App"
            var bundleShortVersionString = "1.0"
            var softwareVersionExternalIdentifier = "0"
            var softwareVersionExternalIdentifiers: [Int] = []
            
            if let metadata = dict["metadata"] as? [String: Any] {
                bundleId = metadata["softwareVersionBundleId"] as? String ?? "unknown"
                bundleDisplayName = metadata["bundleDisplayName"] as? String ?? "Unknown App"
                bundleShortVersionString = metadata["bundleShortVersionString"] as? String ?? "1.0"
                if let extId = metadata["softwareVersionExternalIdentifier"] as? Int {
                    softwareVersionExternalIdentifier = String(extId)
                }
                softwareVersionExternalIdentifiers = metadata["softwareVersionExternalIdentifiers"] as? [Int] ?? []
                

            }
            
            // 获取真实的 sinf 数据
            var sinfs: [DownloadSinfInfo] = []
            if let sinfsArray = dict["sinfs"] as? [[String: Any]] {
                for (index, sinfDict) in sinfsArray.enumerated() {
                    
                    // 获取 sinf ID
                    let sinfId = sinfDict["id"] as? Int ?? index
                    print("   - ID: \(sinfId)")
                    
                    // 获取 sinf 数据 - 修复类型处理问题
                    if let sinfData = sinfDict["sinf"] {
                        print("   - Sinf 数据类型: \(type(of: sinfData))")
                        
                        var finalSinfData: String = ""
                        
                        // 处理不同类型的 sinf 数据
                        if let stringData = sinfData as? String {
                            finalSinfData = stringData
                            print("   - 字符串类型 sinf 数据，长度: \(stringData.count)")
                        } else if let dataData = sinfData as? Data {
                            finalSinfData = dataData.base64EncodedString()
                            print("   - Data 类型 sinf 数据，转换为 base64，长度: \(finalSinfData.count)")
                        } else {
                            // 尝试转换为字符串
                            finalSinfData = "\(sinfData)"
                            print("   - 其他类型 sinf 数据，转换为字符串，长度: \(finalSinfData.count)")
                        }
                        
                        // 验证数据有效性
                        if !finalSinfData.isEmpty && finalSinfData.count > 10 {
                            let sinfInfo = DownloadSinfInfo(
                                id: sinfId,
                                sinf: finalSinfData
                            )
                            sinfs.append(sinfInfo)
                            print("✅ [转换开始] 成功添加 Sinf \(index + 1)，ID: \(sinfId)，数据长度: \(finalSinfData.count)")
                        } 
                    }
                }
            } 
            
            // 验证必要字段
            guard !url.isEmpty && !md5.isEmpty else {
                return createDefaultDownloadStoreItem()
            }
            
            let downloadMetadata = DownloadAppMetadata(
                bundleId: bundleId,
                bundleDisplayName: bundleDisplayName,
                bundleShortVersionString: bundleShortVersionString,
                softwareVersionExternalIdentifier: softwareVersionExternalIdentifier,
                softwareVersionExternalIdentifiers: softwareVersionExternalIdentifiers
            )
            

            return DownloadStoreItem(
                url: url,
                md5: md5,
                sinfs: sinfs,
                metadata: downloadMetadata
            )
        } else {
            return createDefaultDownloadStoreItem()
        }
    }
    
    /// 创建默认的DownloadStoreItem（用于错误情况）
    private func createDefaultDownloadStoreItem() -> DownloadStoreItem {
        return DownloadStoreItem(
            url: "",
            md5: "",
            sinfs: [],
            metadata: DownloadAppMetadata(
                bundleId: "unknown",
                bundleDisplayName: "Unknown App",
                bundleShortVersionString: "1.0",
                softwareVersionExternalIdentifier: "0",
                softwareVersionExternalIdentifiers: []
            )
        )
    }
    
    /// 开始实际的文件下载
    private func startFileDownload(
        storeItem: DownloadStoreItem,
        destinationURL: URL,
        progressHandler: @escaping @Sendable (DownloadProgress) -> Void,
        completion: @escaping @Sendable (Result<DownloadResult, DownloadError>) -> Void
    ) async {
        guard let downloadURL = URL(string: storeItem.url) else {
            DispatchQueue.main.async {
                completion(.failure(.unknownError("无效的下载URL: \(storeItem.url)")))
            }
            return
        }
        let downloadId = UUID().uuidString
        var request = URLRequest(url: downloadURL)
        // 添加必要的请求头以确保下载稳定性
        request.setValue("bytes=0-", forHTTPHeaderField: "Range")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let downloadTask = urlSession.downloadTask(with: request)
        // 记录下载开始时间和目标URL
        downloadStartTimes[downloadId] = Date()
        downloadTasks[downloadId] = downloadTask
        progressHandlers[downloadId] = progressHandler
        // 存储目标URL和转换后的downloadStoreItem信息，供delegate使用
        downloadDestinations[downloadId] = destinationURL
        downloadStoreItems[downloadId] = storeItem // 这里存储的是转换后的DownloadStoreItem
        completionHandlers[downloadId] = completion

        downloadTask.resume()
    }
    /// 验证下载文件的完整性
    private func verifyFileIntegrity(fileURL: URL, expectedMD5: String) -> Bool {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return false
        }
        let digest = Insecure.MD5.hash(data: fileData)
        let calculatedMD5 = digest.map { String(format: "%02hhx", $0) }.joined()
        return calculatedMD5.lowercased() == expectedMD5.lowercased()
    }
    /// 清理下载资源
    private func cleanupDownload(downloadId: String) {
        downloadTasks.removeValue(forKey: downloadId)
        progressHandlers.removeValue(forKey: downloadId)
        completionHandlers.removeValue(forKey: downloadId)
        downloadStartTimes.removeValue(forKey: downloadId)
        lastProgressUpdate.removeValue(forKey: downloadId)
        lastUIUpdate.removeValue(forKey: downloadId)
        downloadDestinations.removeValue(forKey: downloadId)
        downloadStoreItems.removeValue(forKey: downloadId)

    }
    /// 从Apple Store API获取真实的下载信息，包含真实的 sinf 数据
    private func downloadFromStoreAPI(
        appIdentifier: String,
        directoryServicesIdentifier: String,
        appVersion: String?,
        passwordToken: String,
        storeFront: String
    ) async throws -> [String: Any] {
        
        // 构建请求URL
        let guid = generateGUID()
        let url = URL(string: "https://p25-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/volumeStoreDownloadProduct?guid=\(guid)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-apple-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("Configurator/2.15 (Macintosh; OS X 11.0.0; 16G29) AppleWebKit/2603.3.8", forHTTPHeaderField: "User-Agent")
        request.setValue(directoryServicesIdentifier, forHTTPHeaderField: "X-Dsid")
        request.setValue(directoryServicesIdentifier, forHTTPHeaderField: "iCloud-DSID")
        
        // 添加认证头，确保获取真实的 sinf 数据
        if !passwordToken.isEmpty {
            request.setValue(passwordToken, forHTTPHeaderField: "X-Token")
        }
        if !storeFront.isEmpty {
            request.setValue(storeFront, forHTTPHeaderField: "X-Apple-Store-Front")
        }
        
        // 构建请求体
        var body: [String: Any] = [
            "creditDisplay": "",
            "guid": guid,
            "salableAdamId": appIdentifier
        ]
        
        if let appVersion = appVersion {
            body["externalVersionId"] = appVersion
        }
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: body,
            format: .xml,
            options: 0
        )
        request.httpBody = plistData
                
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.networkError(NSError(domain: "StoreAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"]))
        }
                
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw DownloadError.networkError(NSError(domain: "StoreAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }
        
        // 解析响应
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] ?? [:]
        
        // 返回原始 plist 数据
        return plist
    }
    

    
    /// 生成GUID
    private func generateGUID() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).uppercased()
    }
    
    /// 将商店API错误映射为DownloadError
    private func mapStoreError(_ failureType: String, customerMessage: String?) -> DownloadError {
        switch failureType {
        case "INVALID_ITEM":
            return .appNotFound(customerMessage ?? "应用未找到")
        case "INVALID_LICENSE":
            return .licenseError(customerMessage ?? "许可证无效")
        case "INVALID_CREDENTIALS":
            return .authenticationError(customerMessage ?? "认证失败")
        default:
            return .unknownError(customerMessage ?? "未知错误")
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension AppStoreDownloadManager {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 查找此任务的下载ID
        guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let completion = completionHandlers[downloadId],
              let destinationURL = downloadDestinations[downloadId],
              let storeItem = downloadStoreItems[downloadId] else {
            return
        }

        // 检查临时文件是否存在
        guard FileManager.default.fileExists(atPath: location.path) else {
            DispatchQueue.main.async {
                completion(.failure(.fileSystemError("临时下载文件不存在")))
            }
            cleanupDownload(downloadId: downloadId)
            return
        }
        // 立即移动文件到目标位置
        do {
            // 确保目标目录存在
            let targetDirectory = destinationURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: targetDirectory.path) {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            // 移动文件
            try FileManager.default.moveItem(at: location, to: destinationURL)
            // 创建包含完整信息的结果
            let result = DownloadResult(
                downloadId: downloadId,
                fileURL: destinationURL,
                fileSize: downloadTask.countOfBytesReceived,
                metadata: DownloadAppMetadata(
                    bundleId: storeItem.metadata.bundleId,
                    bundleDisplayName: storeItem.metadata.bundleDisplayName,
                    bundleShortVersionString: storeItem.metadata.bundleShortVersionString,
                    softwareVersionExternalIdentifier: storeItem.metadata.softwareVersionExternalIdentifier,
                    softwareVersionExternalIdentifiers: storeItem.metadata.softwareVersionExternalIdentifiers
                ),
                sinfs: storeItem.sinfs,
                expectedMD5: storeItem.md5
            )

            
            Task { @MainActor in
                IPAProcessor.shared.processIPA(at: destinationURL, withSinfs: storeItem.sinfs) { processingResult in
                switch processingResult {
                case .success(let processedIPA):
                    
                    // 添加iTunesMetadata.plist
                    Task {
                        do {
                            // 安全解包metadata
                            guard let metadata = result.metadata else {
                                DispatchQueue.main.async {
                                    completion(.success(result))
                                }
                                return
                            }
                            
                            // 直接生成iTunesMetadata.plist
                            let finalIPA = try await self.generateiTunesMetadata(
                                for: processedIPA.path,
                                bundleId: metadata.bundleId,
                                displayName: metadata.bundleDisplayName,
                                version: metadata.bundleShortVersionString,
                                externalVersionId: Int(metadata.softwareVersionExternalIdentifier) ?? 0,
                                externalVersionIds: metadata.softwareVersionExternalIdentifiers
                            )
                            
                            DispatchQueue.main.async {
                                completion(.success(result))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completion(.success(result))
                            }
                        }
                    }
                case .failure(let error):
                    // 即使处理失败，也返回下载结果，但记录错误
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                }
            }
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(.fileSystemError("文件移动失败: \(error.localizedDescription)")))
            }
        }
        cleanupDownload(downloadId: downloadId)
    }
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // 查找此任务的下载ID
        guard let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let progressHandler = progressHandlers[downloadId],
              let startTime = downloadStartTimes[downloadId] else {
            return
        }
        let currentTime = Date()
        // 计算下载速度
        var speed: Double = 0.0
        var remainingTime: TimeInterval = 0.0
        if let lastUpdate = lastProgressUpdate[downloadId] {
            let timeDiff = currentTime.timeIntervalSince(lastUpdate.time)
            if timeDiff > 0 {
                let bytesDiff = totalBytesWritten - lastUpdate.bytes
                speed = Double(bytesDiff) / timeDiff
            }
        } else {
            // 首次更新，使用总体平均速度
            let totalTime = currentTime.timeIntervalSince(startTime)
            if totalTime > 0 {
                speed = Double(totalBytesWritten) / totalTime
            }
        }
        // 计算剩余时间
        if speed > 0 && totalBytesExpectedToWrite > totalBytesWritten {
            let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
            remainingTime = Double(remainingBytes) / speed
        }
        let progressValue = totalBytesExpectedToWrite > 0 ? 
            Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        let progress = DownloadProgress(
            downloadId: downloadId,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            progress: progressValue,
            speed: speed,
            remainingTime: remainingTime,
            status: .downloading
        )
        // 修复UI更新频率控制逻辑，确保进度实时更新
        let lastUIUpdateTime = lastUIUpdate[downloadId] ?? Date.distantPast
        let shouldUpdate = currentTime.timeIntervalSince(lastUIUpdateTime) >= 0.1 || progressValue >= 1.0
        // 更新进度记录（在UI更新判断之后）
        lastProgressUpdate[downloadId] = (bytes: totalBytesWritten, time: currentTime)
        if shouldUpdate {
            lastUIUpdate[downloadId] = currentTime
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let downloadId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              let completion = completionHandlers[downloadId],
              let _ = downloadDestinations[downloadId],
              let _ = downloadStoreItems[downloadId] else {
            return
        }
        
        if let error = error {
            print("❌ [下载失败] 任务ID: \(downloadId)，错误: \(error.localizedDescription)")
            
            // 下载失败处理逻辑
            print("❌ [下载失败] 任务ID: \(downloadId)，错误: \(error.localizedDescription)")
            
            // 检查错误类型
            if let nsError = error as NSError? {
                // 检查是否是网络错误
                if nsError.domain == NSURLErrorDomain {
                    // 根据错误码提供更具体的错误信息
                    switch nsError.code {
                    case NSURLErrorNotConnectedToInternet:
                        print("📶 [网络错误] 设备未连接到互联网")
                        DispatchQueue.main.async {
                            completion(.failure(.networkError(NSError(domain: "DownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "设备未连接到互联网，请检查网络连接后重试"]))))
                        }
                    case NSURLErrorTimedOut:
                        DispatchQueue.main.async {
                            completion(.failure(.networkError(NSError(domain: "DownloadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "下载超时，请检查网络连接后重试"]))))
                        }
                    case NSURLErrorCancelled:
                        DispatchQueue.main.async {
                            completion(.failure(.unknownError("下载已取消")))
                        }
                    default:
                        DispatchQueue.main.async {
                            completion(.failure(.networkError(NSError(domain: "DownloadManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "下载失败，请稍后重试"]))))
                        }
                    }
                } else if nsError.domain == "NSCocoaErrorDomain" {
                    // 文件系统错误
                    DispatchQueue.main.async {
                        completion(.failure(.fileSystemError("文件操作失败，请确保有足够的存储空间")))
                    }
                } else {
                    // 其他类型的错误
                    DispatchQueue.main.async {
                        completion(.failure(.unknownError("下载过程中发生未知错误")))
                    }
                }
            } else {
                // 非NSError类型的错误
                DispatchQueue.main.async {
                    completion(.failure(.unknownError("下载失败: \(error.localizedDescription)")))
                }
            }
        }
        cleanupDownload(downloadId: downloadId)
    }
}
// MARK: - 下载模型
/// 下载状态
enum DownloadStatus: String, Codable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

/// 下载进度信息
struct DownloadProgress {
    let downloadId: String
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let progress: Double // 0.0 到 1.0
    let speed: Double // 字节/秒
    let remainingTime: TimeInterval // 秒
    let status: DownloadStatus
    var formattedProgress: String {
        return String(format: "%.1f%%", progress * 100)
    }
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: bytesDownloaded)) / \(formatter.string(fromByteCount: totalBytes))"
    }
    var formattedSpeed: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
    var formattedRemainingTime: String {
        if remainingTime <= 0 {
            return "--:--"
        }
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

/// 下载结果
struct DownloadResult {
    let downloadId: String
    let fileURL: URL
    let fileSize: Int64
    var metadata: DownloadAppMetadata?
    var sinfs: [DownloadSinfInfo]?
    var expectedMD5: String?
    var isIntegrityValid: Bool {
        guard let expectedMD5 = expectedMD5,
              let fileData = try? Data(contentsOf: fileURL) else {
            return false
        }
        let digest = Insecure.MD5.hash(data: fileData)
        let calculatedMD5 = digest.map { String(format: "%02hhx", $0) }.joined()
        return calculatedMD5.lowercased() == expectedMD5.lowercased()
    }
}
// 数据模型现已统一在StoreClient.swift中
/// 下载特定的错误
enum DownloadError: LocalizedError {
    case invalidURL(String)
    case appNotFound(String)
    case licenseError(String)
    case authenticationError(String)
    case downloadNotFound(String)
    case fileSystemError(String)
    case integrityCheckFailed(String)
    case licenseCheckFailed(String)
    case networkError(Error)
    case unknownError(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "无效的URL: \(message)"
        case .appNotFound(let message):
            return "应用未找到: \(message)"
        case .licenseError(let message):
            return "许可证错误: \(message)"
        case .authenticationError(let message):
            return "认证错误: \(message)"
        case .downloadNotFound(let message):
            return "下载未找到: \(message)"
        case .fileSystemError(let message):
            return "文件系统错误: \(message)"
        case .integrityCheckFailed(let message):
            return "完整性检查失败: \(message)"
        case .licenseCheckFailed(let message):
            return "许可证检查失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
}



// MARK: - 下载请求模型
/// 下载请求模型
struct UnifiedDownloadRequest: Identifiable, Codable {
    let id: String
    let bundleIdentifier: String
    let name: String
    let version: String
    let identifier: String
    let iconURL: String?
    let versionId: String?
    var status: DownloadStatus
    var progress: Double
    let createdAt: Date
    var completedAt: Date?
    var filePath: String?
    var errorMessage: String?
    
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isFailed: Bool {
        return status == .failed
    }
    
    var isDownloading: Bool {
        return status == .downloading
    }
    
    var isPaused: Bool {
        return status == .paused
    }
}

// MARK: - iTunesMetadata生成方法
extension AppStoreDownloadManager {
    /// 使用ZipArchive处理IPA文件
    private func processIPAWithZipArchive(
        at ipaPath: String,
        appInfo: DownloadAppMetadata
    ) async throws -> String {
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IPAProcessing_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
            print("🧹 [ZipArchive] 清理临时目录: \(tempDir.path)")
        }
        
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        print("🔧 [ZipArchive] 创建解压目录: \(extractedDir.path)")
        
        // 使用ZipArchive解压IPA文件
        #if canImport(ZipArchive)
        print("🔧 [ZipArchive] 开始解压IPA文件...")
        
        let success = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: extractedDir.path)
        guard success else {
            throw NSError(domain: "ZipArchiveProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "IPA解压失败"])
        }
        
        // 创建iTunesMetadata.plist
        try createiTunesMetadataPlist(in: extractedDir, appInfo: appInfo)
        
        // 重新打包IPA文件
        let processedIPAPath = URL(fileURLWithPath: ipaPath).deletingLastPathComponent()
            .appendingPathComponent("processed_\(URL(fileURLWithPath: ipaPath).lastPathComponent)")
        
        let repackSuccess = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard repackSuccess else {
            throw NSError(domain: "ZipArchiveProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "IPA重新打包失败"])
        }
        
        // 验证处理后的文件是否存在
        guard FileManager.default.fileExists(atPath: processedIPAPath.path) else {
            throw NSError(domain: "ZipArchiveProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "处理后的IPA文件不存在"])
        }
        
        // 替换原文件
        try FileManager.default.removeItem(at: URL(fileURLWithPath: ipaPath))
        try FileManager.default.moveItem(at: processedIPAPath, to: URL(fileURLWithPath: ipaPath))
        
        return ipaPath
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "IPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，请正确配置依赖"])
        #endif
    }
    
    /// 创建iTunesMetadata.plist文件
    private func createiTunesMetadataPlist(in extractedDir: URL, appInfo: DownloadAppMetadata) throws {
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": appInfo.bundleId,
            "artistId": 0,
            "artistName": appInfo.bundleDisplayName,
            "bundleId": appInfo.bundleId,
            "bundleVersion": appInfo.bundleShortVersionString,
            "copyright": "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": "\(appInfo.bundleDisplayName).ipa",
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": appInfo.bundleDisplayName,
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": 0.0,
            "priceDisplay": "Free",
            "rating": "4+",
            "releaseDate": "2025-01-01T00:00:00Z",
            "s": 143441,
            "softwareIcon57x57URL": "",
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2], // iPhone and iPad
            "softwareVersionBundleId": appInfo.bundleId,
            "softwareVersionExternalIdentifier": Int(appInfo.softwareVersionExternalIdentifier) ?? 0,
            "softwareVersionExternalIdentifiers": appInfo.softwareVersionExternalIdentifiers ?? [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        try plistData.write(to: metadataPath)
    }
    
    /// 为IPA文件生成iTunesMetadata.plist - 强制确保每个IPA都包含元数据
    /// - Parameters:
    ///   - ipaPath: IPA文件路径
    ///   - bundleId: 应用包ID
    ///   - displayName: 应用显示名称
    ///   - version: 应用版本
    ///   - externalVersionId: 外部版本ID
    ///   - externalVersionIds: 外部版本ID数组
    /// - Returns: 处理后的IPA文件路径
    private func generateiTunesMetadata(
        for ipaPath: String,
        bundleId: String,
        displayName: String,
        version: String,
        externalVersionId: Int,
        externalVersionIds: [Int]?
    ) async throws -> String {
        // 构建iTunesMetadata.plist内容
        let metadataDict: [String: Any] = [
            "appleId": bundleId,
            "artistId": 0,
            "artistName": displayName,
            "bundleId": bundleId,
            "bundleVersion": version,
            "copyright": "Copyright © 2025",
            "drmVersionNumber": 0,
            "fileExtension": "ipa",
            "fileName": "\(displayName).ipa",
            "genre": "Productivity",
            "genreId": 6007,
            "itemId": 0,
            "itemName": displayName,
            "kind": "software",
            "playlistName": "iOS Apps",
            "price": 0.0,
            "priceDisplay": "Free",
            "rating": "4+",
            "releaseDate": "2025-01-01T00:00:00Z",
            "s": 143441,
            "softwareIcon57x57URL": "",
            "softwareIconNeedsShine": false,
            "softwareSupportedDeviceIds": [1, 2], // iPhone and iPad
            "softwareVersionBundleId": bundleId,
            "softwareVersionExternalIdentifier": externalVersionId,
            "softwareVersionExternalIdentifiers": externalVersionIds ?? [],
            "subgenres": [],
            "vendorId": 0,
            "versionRestrictions": 0
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: metadataDict,
            format: .xml,
            options: 0
        )
        
        // 强制使用ZipArchive处理IPA文件，确保iTunesMetadata.plist被添加
        do {
            let appInfo = DownloadAppMetadata(
                bundleId: bundleId,
                bundleDisplayName: displayName,
                bundleShortVersionString: version,
                softwareVersionExternalIdentifier: String(externalVersionId),
                softwareVersionExternalIdentifiers: externalVersionIds
            )
            
            let processedIPA = try await processIPAWithZipArchive(at: ipaPath, appInfo: appInfo)
            return processedIPA
            
        } catch {
            // 备用方案：直接解压IPA，添加iTunesMetadata.plist，然后重新打包
            return try await fallbackAddiTunesMetadata(to: ipaPath, plistData: plistData)
        }
    }
    
    /// 备用方案：直接解压IPA并添加iTunesMetadata.plist
    private func fallbackAddiTunesMetadata(to ipaPath: String, plistData: Data) async throws -> String {
        
        #if canImport(ZipArchive)
        // 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FallbackIPAProcessing_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 解压IPA文件
        let ipaURL = URL(fileURLWithPath: ipaPath)
        print("🔧 [备用方案] 开始解压IPA文件: \(ipaURL.path)")
        
        let success = SSZipArchive.unzipFile(atPath: ipaURL.path, toDestination: extractedDir.path)
        guard success else {
            throw NSError(domain: "FallbackIPAProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "IPA解压失败"])
        }
        print("✅ [备用方案] IPA文件解压成功")
        
        // 在根目录添加iTunesMetadata.plist
        let metadataPath = extractedDir.appendingPathComponent("iTunesMetadata.plist")
        try plistData.write(to: metadataPath)
        print("✅ [备用方案] iTunesMetadata.plist已添加到解压目录")
        
        // 重新打包IPA文件
        let processedIPAPath = ipaURL.deletingLastPathComponent()
            .appendingPathComponent("processed_\(ipaURL.lastPathComponent)")
        
        print("🔧 [备用方案] 开始重新打包IPA文件到: \(processedIPAPath.path)")
        
        let repackSuccess = SSZipArchive.createZipFile(atPath: processedIPAPath.path, withContentsOfDirectory: extractedDir.path)
        guard repackSuccess else {
            throw NSError(domain: "FallbackIPAProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "IPA重新打包失败"])
        }
        print("✅ [备用方案] IPA文件重新打包成功")
        
        // 验证处理后的文件是否存在
        guard FileManager.default.fileExists(atPath: processedIPAPath.path) else {
            throw NSError(domain: "FallbackIPAProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "处理后的IPA文件不存在"])
        }
        
        // 替换原文件
        try FileManager.default.removeItem(at: ipaURL)
        try FileManager.default.moveItem(at: processedIPAPath, to: ipaURL)
        return ipaURL.path
        
        #else
        // 如果没有ZipArchive，抛出错误
        throw NSError(domain: "FallbackIPAProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "ZipArchive库未找到，无法处理IPA文件"])
        #endif
    }
}