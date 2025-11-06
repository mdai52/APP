import Foundation
import ZIPFoundation
import OSLog

private extension Logger {
    static let fileManager = Logger(subsystem: "com.feather.app", category: "文件管理器")
}

// 文件管理器扩展
public extension FileManager {
    // MARK: - 目录
    
    /// 文档目录
    var documentsDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// 应用缓存目录
    var cachesDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    /// 应用临时目录
    var tempDirectory: URL {
        return temporaryDirectory
    }
    
    /// 应用支持目录
    var applicationSupportDirectory: URL {
        return urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - 应用特定目录
    
    /// 应用数据目录
    var appDataDirectory: URL {
        let url = applicationSupportDirectory.appendingPathComponent("AppData")
        try? createDirectoryIfNeeded(at: url)
        return url
    }
    
    /// 下载目录
    var downloadsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Downloads")
        try? createDirectoryIfNeeded(at: url)
        return url
    }
    
    /// 临时工作目录
    func createTempDirectory(named: String? = nil) -> URL {
        let directoryName = named ?? "temp_\(UUID().uuidString)"
        let tempDir = tempDirectory.appendingPathComponent(directoryName)
        try? createDirectoryIfNeeded(at: tempDir)
        return tempDir
    }
    
    // MARK: - 文件管理
    
    /// 创建目录
    @discardableResult
    func createDirectoryIfNeeded(at url: URL) throws -> Bool {
        if !fileExists(atPath: url.path) {
            do {
                try createDirectory(at: url, withIntermediateDirectories: true)
                Logger.fileManager.info("创建目录: \(url.path, privacy: .public)")
                return true
            } catch {
                Logger.fileManager.error("创建目录失败: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
        return true
    }
    
    /// 删除文件或目录
    @discardableResult
    func removeItemIfExists(at url: URL) -> Bool {
        guard fileExists(atPath: url.path) else { return true }
        
        do {
            try removeItem(at: url)
            Logger.fileManager.info("删除项目: \(url.path, privacy: .public)")
            return true
        } catch {
            Logger.fileManager.error("删除项目失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    /// 移动文件或目录
    @discardableResult
    func moveItem(from source: URL, to destination: URL) -> Bool {
        // 确保目标目录存在
        let destinationDir = destination.deletingLastPathComponent()
        do {
            try createDirectoryIfNeeded(at: destinationDir)
        } catch {
            return false
        }
        
        // 如果目标文件已存在，先删除
        if fileExists(atPath: destination.path) {
            guard removeItemIfExists(at: destination) else { return false }
        }
        
        do {
            try moveItem(at: source, to: destination)
            Logger.fileManager.info("移动项目 从 \(source.path, privacy: .public) 到 \(destination.path, privacy: .public)")
            return true
        } catch {
            Logger.fileManager.error("移动项目失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    /// 复制文件或目录
    @discardableResult
    func copyItem(from source: URL, to destination: URL) -> Bool {
        // 确保目标目录存在
        let destinationDir = destination.deletingLastPathComponent()
        do {
            try createDirectoryIfNeeded(at: destinationDir)
        } catch {
            return false
        }
        
        // 如果目标文件已存在，先删除
        if fileExists(atPath: destination.path) {
            guard removeItemIfExists(at: destination) else { return false }
        }
        
        do {
            try copyItem(at: source, to: destination)
            Logger.fileManager.info("复制项目 从 \(source.path, privacy: .public) 到 \(destination.path, privacy: .public)")
            return true
        } catch {
            Logger.fileManager.error("复制项目失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    /// 获取目录下所有文件
    func contentsOfDirectory(at directory: URL, includeSubdirectories: Bool = false) -> [URL] {
        let options: FileManager.DirectoryEnumerationOptions = includeSubdirectories ? [] : [.skipsSubdirectoryDescendants]
        
        do {
            let contents = try contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: options
            )
            return contents
        } catch {
            Logger.fileManager.error("获取目录内容失败: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    // MARK: - 文件信息
    
    /// 获取文件大小
    func fileSize(at url: URL) -> UInt64 {
        do {
            let attributes = try attributesOfItem(atPath: url.path)
            return attributes[.size] as? UInt64 ?? 0
        } catch {
            Logger.fileManager.error("获取文件大小失败: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }
    
    /// 获取目录大小
    func directorySize(at url: URL) -> UInt64 {
        var totalSize: UInt64 = 0
        
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            do {
                let attributes = try attributesOfItem(atPath: fileURL.path)
                totalSize += attributes[.size] as? UInt64 ?? 0
            } catch {
                Logger.fileManager.error("获取文件属性失败: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        return totalSize
    }
    
    /// 格式化文件大小
    func formatFileSize(_ size: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}