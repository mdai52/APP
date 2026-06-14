import Foundation
import SwiftUI
import Combine

@MainActor
class UnifiedDownloadManager: ObservableObject, @unchecked Sendable {
    static let shared = UnifiedDownloadManager()

    @Published var downloadRequests: [DownloadRequest] = []
    @Published var completedRequests: Set<UUID> = []
    @Published var activeDownloads: Set<UUID> = []

    private let downloadManager = AppStoreDownloadManager.shared
    private let purchaseManager = PurchaseManager.shared

    private init() {

        configureSessionMonitoring()
    }

    private func configureSessionMonitoring() {

        Task { @MainActor in
            restoreDownloadTasks()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.saveDownloadTasks()
                self.pauseAllDownloads()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.checkAndResumeDownloads()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.saveDownloadTasks()
            }
        }
    }

    func addDownload(
        bundleIdentifier: String,
        name: String,
        version: String,
        identifier: Int,
        iconURL: String? = nil,
        versionId: String? = nil
    ) -> UUID {
        print("🔍 [添加下载] 开始添加下载请求")
        print("   - Bundle ID: \(bundleIdentifier)")
        print("   - 名称: \(name)")
        print("   - 版本: \(version)")
        print("   - 标识符: \(identifier)")
        print("   - 版本ID: \(versionId ?? "无")")

        let package = DownloadArchive(
            bundleIdentifier: bundleIdentifier,
            name: name,
            version: version,
            identifier: identifier,
            iconURL: iconURL
        )

        let request = DownloadRequest(
            bundleIdentifier: bundleIdentifier,
            version: version,
            name: name,
            package: package,
            versionId: versionId
        )

        downloadRequests.append(request)
        print("✅ [添加下载] 下载请求已添加，ID: \(request.id)")
        print("📊 [添加下载] 当前下载请求总数: \(downloadRequests.count)")
        print("🖼️ [图标信息] 图标URL: \(request.iconURL ?? "无")")
        print("📦 [包信息] 包名称: \(request.package.name), 标识符: \(request.package.identifier)")
        return request.id
    }

    func deleteDownload(request: DownloadRequest) {
        if let index = downloadRequests.firstIndex(where: { $0.id == request.id }) {
            downloadRequests.remove(at: index)
            activeDownloads.remove(request.id)
            completedRequests.remove(request.id)
            print("🗑️ [删除下载] 已删除下载请求: \(request.name)")
        }
    }

    func startDownload(for request: DownloadRequest) {
        guard !activeDownloads.contains(request.id) else {
            print("⚠️ [下载跳过] 请求 \(request.id) 已在下载队列中")
            return
        }

        print("🚀 [下载启动] 开始下载: \(request.name) v\(request.version)")
        print("🔍 [调试] 下载请求详情:")
        print("   - Bundle ID: \(request.bundleIdentifier)")
        print("   - 版本: \(request.version)")
        print("   - 版本ID: \(request.versionId ?? "无")")
        print("   - 包标识符: \(request.package.identifier)")
        print("   - 包名称: \(request.package.name)")
        print("   - 当前状态: \(request.runtime.status)")
        print("   - 当前进度: \(request.runtime.progressValue)")

        activeDownloads.insert(request.id)
        request.runtime.status = DownloadStatus.downloading
        request.runtime.error = nil

        request.runtime.progress = Progress(totalUnitCount: 0)
        request.runtime.progress.completedUnitCount = 0

        print("✅ [状态更新] 状态已设置为: \(request.runtime.status)")
        print("✅ [进度重置] 进度已重置为: \(request.runtime.progressValue)")

        Task {
            guard let account = AppStore.this.selectedAccount else {
                await MainActor.run {
                    request.runtime.error = "请先添加Apple ID账户"
                    request.runtime.status = DownloadStatus.failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [认证失败] 未找到有效的Apple ID账户")
                }
                return
            }

            print("🔐 [认证信息] 使用账户: \(account.email)")
            print("🏪 [商店信息] StoreFront: \(account.storeResponse.storeFront)")

            AuthenticationManager.shared.setCookies(account.cookies)

            let storeAccount = Account(
                name: account.email,
                email: account.email,
                firstName: account.firstName,
                lastName: account.lastName,
                passwordToken: account.storeResponse.passwordToken,
                directoryServicesIdentifier: account.storeResponse.directoryServicesIdentifier,
                dsPersonId: account.storeResponse.directoryServicesIdentifier,
                cookies: account.cookies,
                countryCode: account.countryCode,
                storeResponse: account.storeResponse
            )

            let isValid = await AuthenticationManager.shared.validateAccount(storeAccount)
            if !isValid {
                await MainActor.run {
                    request.runtime.error = "Apple ID会话已过期，请重新登录"
                    request.runtime.status = DownloadStatus.failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [会话失效] Apple ID会话已过期")
                }
                return
            }

            let regionValidation = (account.countryCode == storeAccount.countryCode)

            if !regionValidation {
                await MainActor.run {
                    request.runtime.error = "地区设置不匹配，请检查账户地区设置"
                    request.runtime.status = DownloadStatus.failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [地区错误] 账户地区与设置不匹配")
                }
                return
            }

            print("🔍 [购买验证] 开始验证应用所有权: \(request.name)")
            let purchaseResult = await purchaseManager.purchaseAppIfNeeded(
                appIdentifier: String(request.package.identifier),
                account: storeAccount,
                countryCode: account.countryCode
            )

            switch purchaseResult {
            case .success(let result):
                print("✅ [购买验证] \(result.message)")

                proceedWithDownload(
                    for: request,
                    storeAccount: storeAccount
                )
            case .failure(let error):
                await MainActor.run {
                    request.runtime.error = error.localizedDescription
                    request.runtime.status = DownloadStatus.failed
                    self.activeDownloads.remove(request.id)
                    print("❌ [购买失败] \(request.name): \(error.localizedDescription)")
                }
            }
        }
    }

    private func proceedWithDownload(
        for request: DownloadRequest,
        storeAccount: Account
    ) {

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sanitizedName = request.package.name.replacingOccurrences(of: "/", with: "_")
        let destinationURL = documentsPath.appendingPathComponent("\(sanitizedName)_\(request.version).ipa")

        print("📁 [文件路径] 目标位置: \(destinationURL.path)")
        print("🆔 [应用信息] ID: \(request.package.identifier), 版本: \(request.versionId ?? request.version)")

        downloadManager.downloadApp(
            appIdentifier: String(request.package.identifier),
            account: storeAccount,
            destinationURL: destinationURL,
            appVersion: request.versionId,
            progressHandler: { downloadProgress in
                Task { @MainActor in

                    request.runtime.updateProgress(
                        completed: downloadProgress.bytesDownloaded,
                        total: downloadProgress.totalBytes
                    )
                    request.runtime.speed = downloadProgress.formattedSpeed

                    switch downloadProgress.status {
                    case .waiting:
                        request.runtime.status = DownloadStatus.waiting
                    case .downloading:
                        request.runtime.status = DownloadStatus.downloading
                    case .paused:
                        request.runtime.status = DownloadStatus.paused
                    case .completed:
                        request.runtime.status = DownloadStatus.completed
                    case .failed:
                        request.runtime.status = DownloadStatus.failed
                    case .cancelled:
                        request.runtime.status = DownloadStatus.cancelled
                    }

                    let progressPercent = Int(downloadProgress.progress * 100)
                    if progressPercent % 1 == 0 && progressPercent > 0 {
                        print("📊 [下载进度] \(request.name): \(progressPercent)% (\(downloadProgress.formattedSize)) - 速度: \(downloadProgress.formattedSpeed)")
                    }

                    request.objectWillChange.send()
                    request.runtime.objectWillChange.send()
                }
            },
            completion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let downloadResult):

                        request.runtime.updateProgress(
                            completed: downloadResult.fileSize,
                            total: downloadResult.fileSize
                        )
                        request.runtime.status = DownloadStatus.completed

                        request.localFilePath = downloadResult.fileURL.path
                        self.completedRequests.insert(request.id)
                        print("✅ [下载完成] \(request.name) 已保存到: \(downloadResult.fileURL.path)")
                        print("📊 [文件信息] 大小: \(ByteCountFormatter().string(fromByteCount: downloadResult.fileSize))")

                        self.saveDownloadTasks()

                    case .failure(let error):
                        request.runtime.error = error.localizedDescription
                        request.runtime.status = DownloadStatus.failed
                        print("❌ [下载失败] \(request.name): \(error.localizedDescription)")
                    }

                    self.activeDownloads.remove(request.id)
                }
            }
        )
    }
}

struct DownloadArchive {
    let bundleIdentifier: String
    let name: String
    let version: String
    let identifier: Int
    let iconURL: String?
    let description: String?

    init(bundleIdentifier: String, name: String, version: String, identifier: Int = 0, iconURL: String? = nil, description: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.identifier = identifier
        self.iconURL = iconURL
        self.description = description
    }
}

class DownloadRuntime: ObservableObject {
    @Published var status: DownloadStatus = DownloadStatus.waiting
    @Published var progress: Progress = Progress(totalUnitCount: 0)
    @Published var speed: String = ""
    @Published var error: String?
    @Published var progressValue: Double = 0.0

    init() {

        progress.completedUnitCount = 0
    }

    @MainActor
    func updateProgress(completed: Int64, total: Int64) {

        progress = Progress(totalUnitCount: total)
        progress.completedUnitCount = completed
        progressValue = total > 0 ? Double(completed) / Double(total) : 0.0

        objectWillChange.send()

        let percent = Int(progressValue * 100)
        print("🔄 [进度更新] \(percent)% (\(ByteCountFormatter().string(fromByteCount: completed))/\(ByteCountFormatter().string(fromByteCount: total)))")

        Task { @MainActor [weak self] in
            self?.objectWillChange.send()
        }
    }
}

class DownloadRequest: Identifiable, ObservableObject, Equatable, @unchecked Sendable {
    let id = UUID()
    let bundleIdentifier: String
    let version: String
    let name: String
    var createdAt: Date
    let package: DownloadArchive
    let versionId: String?
    @Published var localFilePath: String?

    private var cancellables: Set<AnyCancellable> = []
    @Published var runtime: DownloadRuntime { didSet { bindRuntime() } }

    var iconURL: String? {
        return package.iconURL
    }

    var identifier: Int {
        return package.identifier
    }

    init(bundleIdentifier: String, version: String, name: String, package: DownloadArchive, versionId: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.name = name
        self.createdAt = Date()
        self.package = package
        self.versionId = versionId
        self.runtime = DownloadRuntime()

        bindRuntime()
    }

    private func bindRuntime() {
        cancellables.removeAll()
        runtime.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var hint: String {
        if let error = runtime.error {
            return error
        }
        return switch runtime.status {
        case DownloadStatus.waiting:
            "等待中..."
        case DownloadStatus.downloading:
            [
                String(Int(runtime.progressValue * 100)) + "%",
                runtime.speed.isEmpty ? "" : runtime.speed,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        case DownloadStatus.paused:
            "已暂停"
        case DownloadStatus.completed:
            "已完成"
        case DownloadStatus.failed:
            "下载失败"
        case DownloadStatus.cancelled:
            "已取消"
        }
    }

    static func == (lhs: DownloadRequest, rhs: DownloadRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

extension UnifiedDownloadManager {

    func saveDownloadTasks() {
        NSLog("💾 [UnifiedDownloadManager] 开始保存下载任务")

        let saveData = DownloadTasksSaveData(
            downloadRequests: downloadRequests.map { request in
                DownloadRequestSaveData(
                    id: request.id,
                    bundleIdentifier: request.bundleIdentifier,
                    version: request.version,
                    name: request.name,
                    package: request.package,
                    versionId: request.versionId,
                    runtime: DownloadRuntimeSaveData(
                        status: request.runtime.status,
                        progressValue: request.runtime.progressValue,
                        error: request.runtime.error,
                        speed: request.runtime.speed,
                        localFilePath: request.localFilePath
                    ),
                    createdAt: request.createdAt
                )
            },
            completedRequests: Array(completedRequests),
            activeDownloads: Array(activeDownloads)
        )

        do {
            let data = try JSONEncoder().encode(saveData)
            UserDefaults.standard.set(data, forKey: "DownloadTasks")
            UserDefaults.standard.synchronize()
            NSLog("✅ [UnifiedDownloadManager] 下载任务保存成功，共\(downloadRequests.count)个任务")
        } catch {
            NSLog("❌ [UnifiedDownloadManager] 下载任务保存失败: \(error)")
        }
    }

    func restoreDownloadTasks() {
        NSLog("🔄 [UnifiedDownloadManager] 开始恢复下载任务")

        guard let data = UserDefaults.standard.data(forKey: "DownloadTasks") else {
            NSLog("ℹ️ [UnifiedDownloadManager] 没有找到保存的下载任务")
            return
        }

        do {
            let saveData = try JSONDecoder().decode(DownloadTasksSaveData.self, from: data)

            downloadRequests = saveData.downloadRequests.map { saveRequest in
                let request = DownloadRequest(
                    bundleIdentifier: saveRequest.bundleIdentifier,
                    version: saveRequest.version,
                    name: saveRequest.name,
                    package: saveRequest.package,
                    versionId: saveRequest.versionId
                )

                request.runtime.status = saveRequest.runtime.status
                request.runtime.progressValue = saveRequest.runtime.progressValue
                request.runtime.error = saveRequest.runtime.error
                request.runtime.speed = saveRequest.runtime.speed
                request.localFilePath = saveRequest.runtime.localFilePath
                request.createdAt = saveRequest.createdAt

                return request
            }

            completedRequests = Set(saveData.completedRequests)
            activeDownloads = Set(saveData.activeDownloads)

            NSLog("✅ [UnifiedDownloadManager] 下载任务恢复成功，共\(downloadRequests.count)个任务")

            checkAndResumeDownloads()

        } catch {
            NSLog("❌ [UnifiedDownloadManager] 下载任务恢复失败: \(error)")
        }
    }

    func pauseAllDownloads() {
        NSLog("⏸️ [UnifiedDownloadManager] 暂停所有下载任务")

        for request in downloadRequests {
            if request.runtime.status == DownloadStatus.downloading {
                request.runtime.status = DownloadStatus.paused
                activeDownloads.remove(request.id)
                NSLog("⏸️ [UnifiedDownloadManager] 已暂停: \(request.name)")
            }
        }

        saveDownloadTasks()
    }

    private func checkAndResumeDownloads() {
        for request in downloadRequests {

            if let localFilePath = request.localFilePath,
               FileManager.default.fileExists(atPath: localFilePath) {

                if request.runtime.status != DownloadStatus.completed {
                    request.runtime.status = DownloadStatus.completed
                    completedRequests.insert(request.id)
                    activeDownloads.remove(request.id)
                    NSLog("✅ [UnifiedDownloadManager] 标记为已完成(文件存在): \(request.name)")
                }

                if !completedRequests.contains(request.id) {
                    completedRequests.insert(request.id)
                    NSLog("✅ [UnifiedDownloadManager] 补充标记为已完成: \(request.name)")
                }
            } else if request.runtime.status == DownloadStatus.downloading {

                request.runtime.status = DownloadStatus.failed
                request.runtime.error = "文件丢失，请重新下载"
                activeDownloads.remove(request.id)
                NSLog("❌ [UnifiedDownloadManager] 标记丢失文件为失败: \(request.name)")
            }
        }

        saveDownloadTasks()
    }
}

private struct DownloadTasksSaveData: Codable {
    let downloadRequests: [DownloadRequestSaveData]
    let completedRequests: [UUID]
    let activeDownloads: [UUID]
}

private struct DownloadRequestSaveData: Codable {
    let id: UUID
    let bundleIdentifier: String
    let version: String
    let name: String
    let packageIdentifier: Int
    let packageIconURL: String?
    let versionId: String?
    let runtime: DownloadRuntimeSaveData
    var createdAt: Date

    init(id: UUID, bundleIdentifier: String, version: String, name: String, package: DownloadArchive, versionId: String?, runtime: DownloadRuntimeSaveData, createdAt: Date) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.name = name
        self.packageIdentifier = package.identifier
        self.packageIconURL = package.iconURL
        self.versionId = versionId
        self.runtime = runtime
        self.createdAt = createdAt
    }

    var package: DownloadArchive {
        return DownloadArchive(
            bundleIdentifier: bundleIdentifier,
            name: name,
            version: version,
            identifier: packageIdentifier,
            iconURL: packageIconURL
        )
    }
}

private struct DownloadRuntimeSaveData: Codable {
    let status: DownloadStatus
    let progressValue: Double
    let error: String?
    let speed: String
    let localFilePath: String?
}
