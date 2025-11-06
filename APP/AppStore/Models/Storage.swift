import CoreData
import Foundation
import OSLog
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// 核心数据存储管理类，提供数据持久化相关方法
public final class Storage: ObservableObject {
    // MARK: - Core Data 核心栈
    
    public let persistentContainer: NSPersistentContainer
    
    /// 核心数据上下文
    public private(set) var context: NSManagedObjectContext
    
    /// 发布上下文变化的发布者
    public var contextPublisher: AnyPublisher<NSManagedObjectContext, Never> {
        $contextValue.eraseToAnyPublisher()
    }
    
    @Published private var contextValue: NSManagedObjectContext
    
    /// 共享的Storage单例
    public static let shared = Storage()
    private let logger = Logger(subsystem: "com.feather.app", category: "Storage")
    
    private init() {
        // 初始化persistentContainer
        let container = NSPersistentContainer(name: "Feather")
        
        // 加载持久化存储
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        
        // 等待加载完成
        _ = semaphore.wait(timeout: .distantFuture)
        
        // 处理加载错误
        if let error = loadError as NSError? {
            logger.error("未解决的错误: \(error), \(error.userInfo)")
        }
        
        self.persistentContainer = container
        
        // 初始化上下文
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        self.context = context
        self.contextValue = context
        
        // 设置应用进入后台时自动保存
        setupAppLifecycleNotifications()
    }
    
    // MARK: - 私有方法
    
    private func setupAppLifecycleNotifications() {
        // 设置应用进入后台时自动保存
        #if canImport(UIKit)
        let notificationName = UIApplication.willResignActiveNotification
        #elseif canImport(AppKit)
        let notificationName = NSApplication.willResignActiveNotification
        #else
        let notificationName = NSNotification.Name("ApplicationWillResignActive")
        #endif
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveContext),
            name: notificationName,
            object: nil
        )
    }
    
    // MARK: - 公开方法
    
    /// 保存上下文
    @objc public func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                logger.error("未解决的错误: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// 获取应用的存储目录
    public func getAppDirectory(for app: AppInfoPresentable) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsDirectory?.appendingPathComponent("Apps/\(app.bundleIdentifier ?? "")")
    }
    
    /// 清空指定请求的上下文
    public func clearContext(request: NSFetchRequest<NSFetchRequestResult>) {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            logger.error("清空上下文时出错: \(error.localizedDescription)")
        }
    }
    
    /// 计算指定实体的记录数
    public func countContent<T: NSManagedObject>(for type: T.Type, entityName: String) -> String {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        do {
            let count = try context.count(for: request)
            return "\(count)"
        } catch {
            logger.error("计算\(entityName)数量时出错: \(error.localizedDescription)")
            return "0"
        }
    }
    
    /// 添加导入的应用
    public func addImported(uuid: String, appName: String?, appIdentifier: String?, appVersion: String?, appIcon: String?, completion: @escaping (Bool) -> Void) {
        let context = self.persistentContainer.viewContext
        
        context.perform {
            let imported = NSEntityDescription.insertNewObject(forEntityName: "Imported", into: context)
            imported.setValue(UUID(uuidString: uuid) ?? UUID(), forKey: "id")
            imported.setValue(appName, forKey: "name")
            imported.setValue(appIdentifier, forKey: "bundleIdentifier")
            imported.setValue(appVersion, forKey: "version")
            imported.setValue(Date(), forKey: "date")
            
            do {
                try context.save()
                self.logger.info("成功添加导入的应用: \(appName ?? "")")
                completion(true)
            } catch {
                self.logger.error("保存导入的应用失败: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
}

// MARK: - Core Data 保存支持

extension Storage {
    /// 带完成回调的保存上下文方法
    func saveContextWithCompletion(completion: @escaping (Error?) -> Void) {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                completion(nil)
            } catch {
                let nsError = error as NSError
                logger.error("保存上下文时出错: \(nsError), \(nsError.userInfo)")
                completion(error)
            }
        } else {
            completion(nil)
        }
    }
    
    /// 在后台执行任务
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
}
