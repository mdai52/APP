import Foundation
import SwiftUI
import Combine

@MainActor
class AppStore: ObservableObject {
    static let this = AppStore()
    @Published var savedAccounts: [Account] = []
    @Published var selectedAccount: Account? = nil
    @Published var selectedAccountIndex: Int = 0
    
    private init() {
        loadAccounts()
    }
    
    func setupGUID() {
    }
    
    private func loadAccounts() {
        let allAccounts = AuthenticationManager.shared.loadAllSavedAccounts()
        savedAccounts = allAccounts
        
        if !allAccounts.isEmpty {
            selectedAccount = allAccounts.first
            selectedAccountIndex = 0
            print("[AppStore] 加载了 \(allAccounts.count) 个账户")
            for (index, account) in allAccounts.enumerated() {
                print("[AppStore] 账户 \(index + 1): \(account.email), 地区: \(account.countryCode)")
            }
        } else {
            print("[AppStore] 没有找到保存的账户")
            selectedAccount = nil
            selectedAccountIndex = 0
        }
    }
    /// 登录账户 - 使用 AuthenticationManager 进行认证（支持多账户）
    func loginAccount(email: String, password: String, code: String?) async throws {
        // 直接调用authenticate方法，它会抛出错误或返回成功的账户
        let account = try await AuthenticationManager.shared.authenticate(
            email: email,
            password: password,
            mfa: code
        )
        
        // 检查是否已存在相同邮箱的账户
        if let existingIndex = savedAccounts.firstIndex(where: { $0.email == account.email }) {
            // 更新现有账户
            savedAccounts[existingIndex] = account
            selectedAccountIndex = existingIndex
            print("[AppStore] 更新现有账户: \(account.email), 地区: \(account.countryCode)")
        } else {
            // 添加新账户
            savedAccounts.append(account)
            selectedAccountIndex = savedAccounts.count - 1
            print("[AppStore] 添加新账户: \(account.email), 地区: \(account.countryCode)")
        }
        
        // 设置为当前选中账户
        selectedAccount = account
        
        // 保存所有账户到Keychain
        try AuthenticationManager.shared.saveAllAccounts(savedAccounts)
        
        print("[AppStore] 账户登录成功: \(account.email), 地区: \(account.countryCode), 总账户数: \(savedAccounts.count)")
    }
    /// 登出当前账户
    func logoutAccount() {
        guard let currentAccount = selectedAccount else { return }
        
        // 从账户列表中移除当前账户
        if let index = savedAccounts.firstIndex(where: { $0.email == currentAccount.email }) {
            savedAccounts.remove(at: index)
            
            // 更新选中账户索引
            if savedAccounts.isEmpty {
                selectedAccount = nil
                selectedAccountIndex = 0
            } else {
                // 选择下一个账户，如果超出范围则选择最后一个
                selectedAccountIndex = min(index, savedAccounts.count - 1)
                selectedAccount = savedAccounts[selectedAccountIndex]
            }
        }
        
        // 保存更新后的账户列表到Keychain
        try? AuthenticationManager.shared.saveAllAccounts(savedAccounts)
        
        print("[AppStore] 账户已登出: \(currentAccount.email), 剩余账户数: \(savedAccounts.count)")
    }
    
    /// 删除指定账户
    func deleteAccount(_ account: Account) {
        if let index = savedAccounts.firstIndex(where: { $0.email == account.email }) {
            savedAccounts.remove(at: index)
            
            // 更新选中账户索引
            if savedAccounts.isEmpty {
                selectedAccount = nil
                selectedAccountIndex = 0
            } else {
                // 选择下一个账户，如果超出范围则选择最后一个
                selectedAccountIndex = min(index, savedAccounts.count - 1)
                selectedAccount = savedAccounts[selectedAccountIndex]
            }
        }
        
        // 保存更新后的账户列表到Keychain
        try? AuthenticationManager.shared.saveAllAccounts(savedAccounts)
        
        print("[AppStore] 删除账户: \(account.email), 剩余账户数: \(savedAccounts.count)")
    }
    /// 刷新账户状态
    func refreshAccount() {
        // 重新加载账户数据
        loadAccounts()
        objectWillChange.send()
    }
    
    /// 切换账户
    func switchToAccount(at index: Int) {
        guard index >= 0 && index < savedAccounts.count else { return }
        
        selectedAccountIndex = index
        selectedAccount = savedAccounts[index]
        
        print("[AppStore] 切换到账户: \(selectedAccount?.email ?? "未知"), 索引: \(index)")
    }
    
    /// 切换账户（通过账户对象）
    func switchToAccount(_ account: Account) {
        if let index = savedAccounts.firstIndex(where: { $0.email == account.email }) {
            switchToAccount(at: index)
        }
    }
    /// 更新当前账户信息
    func updateAccount(_ account: Account) {
        // 更新当前账户
        selectedAccount = account
        
        // 更新账户列表中的对应账户
        if let index = savedAccounts.firstIndex(where: { $0.email == account.email }) {
            savedAccounts[index] = account
        }
        
        // 保存所有账户到Keychain
        try? AuthenticationManager.shared.saveAllAccounts(savedAccounts)
        print("[AppStore] 账户信息已更新: \(account.email)")
    }
    /// 刷新当前账户令牌
    func refreshCurrentAccount() async throws {
        guard let account = selectedAccount else {
            print("[AppStore] 没有当前账户需要刷新")
            return
        }
        
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        // 调用AuthenticationManager验证账户
        if await AuthenticationManager.shared.validateAccount(account) {
            // 刷新cookie
            let updatedAccount = AuthenticationManager.shared.refreshCookies(for: account)
            // 更新当前账户信息
            selectedAccount = updatedAccount
            print("[AppStore] 账户令牌已刷新: \(updatedAccount.email)")
        } else {
            print("[AppStore] 账户验证失败，需要重新登录")
            logoutAccount()
        }
    }

    
    /// 设置当前账户的Cookie
    func setCurrentAccountCookies() {
        guard let account = selectedAccount else {
            print("[AppStore] 没有当前账户可设置Cookie")
            return
        }
        // 设置账户的cookie到HTTPCookieStorage
        AuthenticationManager.shared.setCookies(account.cookies)
        print("[AppStore] 已设置账户Cookie: \(account.email)")
    }
    
    /// 获取当前选中账户的地区代码
    var currentAccountRegion: String {
        return selectedAccount?.countryCode ?? "US"
    }
    
    /// 获取所有账户的地区代码列表
    var allAccountRegions: [String] {
        return savedAccounts.map { $0.countryCode }
    }
    
    /// 检查是否有多个账户
    var hasMultipleAccounts: Bool {
        return savedAccounts.count > 1
    }
}
// MARK: - Account 模型
extension AppStore {
    // 账户结构体已移至 AuthenticationManager.swift 以避免重复
}
