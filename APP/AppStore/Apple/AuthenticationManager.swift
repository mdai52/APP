//
//  AuthenticationManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//
import Foundation
import Security
/// 用于处理用户凭证和会话管理的认证管理器
@MainActor
class AuthenticationManager: @unchecked Sendable {
    static let shared = AuthenticationManager()
    private let keychainService = "ipatool.swift.service"
    private let keychainAccount = "account"
    private let storeRequest = StoreRequest.shared
    private init() {}
    /// 使用Apple ID认证用户
    /// - 参数:
    ///   - email: Apple ID邮箱
    ///   - password: Apple ID密码
    ///   - mfa: 双因素认证代码(可选)
    /// - 返回: 账户信息
    func authenticate(email: String, password: String, mfa: String? = nil) async throws -> Account {
        let response = try await StoreRequest.shared.authenticate(
            email: email,
            password: password,
            mfa: mfa
        )
        // 获取Cookie
        let cookieStrings = getCurrentCookies()
        // 准备账户信息
        let firstName = response.accountInfo.address.firstName
        let lastName = response.accountInfo.address.lastName
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let finalName = name.isEmpty ? email : name
        // 智能地区代码检测
        let detectedCountryCode = detectCountryCode(from: response, email: email)
        let detectedStoreFront = detectStoreFront(from: response, countryCode: detectedCountryCode)
        
        print("🌍 [地区检测] 检测到的地区代码: \(detectedCountryCode)")
        print("🏪 [商店检测] 检测到的StoreFront: \(detectedStoreFront)")
        
        // 使用完整的Account初始化器，确保提供所有必需的参数
        let account = Account(
            name: finalName,
            email: email,
            firstName: firstName,
            lastName: lastName,
            passwordToken: response.passwordToken,
            directoryServicesIdentifier: response.dsPersonId,
            dsPersonId: response.dsPersonId,
            cookies: cookieStrings,
            countryCode: detectedCountryCode,
            storeResponse: Account.AccountStoreResponse(
                directoryServicesIdentifier: response.dsPersonId,
                passwordToken: response.passwordToken,
                storeFront: detectedStoreFront
            )
        )
        // 保存到钥匙串
        do {
            try saveAccountToKeychain(account)
        } catch {
            print("警告: 无法将账户保存到钥匙串: \(error)")
        }
        return account
    }
    /// 从钥匙串加载账户
    /// - 返回: 如果存在则返回已保存的账户
    func loadSavedAccount() -> Account? {
        return loadAccountFromKeychain()
    }
    
    /// 从钥匙串加载所有保存的账户
    /// - 返回: 所有已保存的账户列表
    func loadAllSavedAccounts() -> [Account] {
        // 首先尝试加载新的多账户格式
        let newFormatAccounts = loadAllAccountsFromKeychain()
        if !newFormatAccounts.isEmpty {
            print("🔐 [AuthenticationManager] 加载了 \(newFormatAccounts.count) 个账户（新格式）")
            return newFormatAccounts
        }
        
        // 如果新格式没有数据，尝试加载旧的单账户格式
        if let oldFormatAccount = loadAccountFromKeychain() {
            print("🔐 [AuthenticationManager] 加载了1个账户（旧格式），转换为新格式")
            // 将旧格式账户转换为新格式并保存
            let accounts = [oldFormatAccount]
            try? saveAllAccountsToKeychain(accounts)
            return accounts
        }
        
        print("🔐 [AuthenticationManager] 没有找到任何保存的账户")
        return []
    }
    /// 将账户保存到钥匙串
    /// - 参数 account: 要保存的账户
    /// - 抛出: 如果保存失败则抛出错误
    func saveAccount(_ account: Account) throws {
        try saveAccountToKeychain(account)
    }
    
    /// 将所有账户保存到钥匙串
    /// - 参数 accounts: 要保存的账户列表
    /// - 抛出: 如果保存失败则抛出错误
    func saveAllAccounts(_ accounts: [Account]) throws {
        try saveAllAccountsToKeychain(accounts)
    }
    /// 从钥匙串删除已保存的账户
    /// - 返回: 如果删除成功则返回true
    func deleteSavedAccount() -> Bool {
        return deleteAccountFromKeychain()
    }
    /// 验证账户凭证是否仍然有效
    /// - 参数 account: 要验证的账户
    /// - 返回: 如果账户仍然有效则返回true
    func validateAccount(_ account: Account) async -> Bool {
        // 设置Cookie
        setCookies(account.cookies)
        
        // 检查Cookie是否仍然有效
        guard let cookies = HTTPCookieStorage.shared.cookies else { return false }
        
        var hasValidCookie = false
        for cookie in cookies {
            if cookie.domain.contains("apple.com") {
                if let expiresDate = cookie.expiresDate {
                    if expiresDate.timeIntervalSinceNow > 0 {
                        hasValidCookie = true
                        break
                    }
                } else {
                    // 会话Cookie（没有过期时间）
                    hasValidCookie = true
                    break
                }
            }
        }
        
        return hasValidCookie
    }
    
    /// 检查会话是否即将过期
    /// - 参数 account: 要检查的账户
    /// - 返回: 如果会话即将过期则返回true
    func isSessionExpiring(_ account: Account) async -> Bool {
        // 检查Cookie的过期时间
        guard let cookies = HTTPCookieStorage.shared.cookies else { return true }
        
        for cookie in cookies {
            if cookie.domain.contains("apple.com") {
                if let expiresDate = cookie.expiresDate {
                    let timeUntilExpiry = expiresDate.timeIntervalSinceNow
                    // 如果Cookie在5分钟内过期，认为会话即将过期
                    if timeUntilExpiry < 300 {
                        print("🔐 [AuthenticationManager] Cookie即将过期: \(cookie.name)")
                        return true
                    }
                }
            }
        }
        
        return false
    }
    /// 刷新账户的Cookie
    /// - 参数 account: 要刷新Cookie的账户
    /// - 返回: 带有新Cookie的更新后的账户
    func refreshCookies(for account: Account) -> Account {
        let updatedAccount = Account(
            name: account.name,
            email: account.email,
            firstName: account.firstName,
            lastName: account.lastName,
            passwordToken: account.passwordToken,
            directoryServicesIdentifier: account.directoryServicesIdentifier,
            dsPersonId: account.dsPersonId,
            cookies: getCurrentCookies(),
            countryCode: account.countryCode,
            storeResponse: account.storeResponse
        )
        // 保存更新后的账户
        do {
            try saveAccountToKeychain(updatedAccount)
        } catch {
            print("警告: 无法保存更新后的账户: \(error)")
        }
        return updatedAccount
    }
    // MARK: - Cookie管理
    /// 获取当前的Cookie
    private func getCurrentCookies() -> [String] {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return [] }
        return cookies.compactMap { cookie in
            if cookie.domain.contains("apple.com") || cookie.domain.contains("itunes.apple.com") {
                return cookie.description
            }
            return nil
        }
    }
    /// 在HTTPCookieStorage中设置Cookie
    /// - 参数 cookieStrings: 要设置的Cookie字符串数组
    func setCookies(_ cookies: [String]) {
        for cookieString in cookies {
            let components = cookieString.components(separatedBy: ";")
            var cookieDict: [HTTPCookiePropertyKey: Any] = [:]
            for component in components {
                let parts = component.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    if parts[0].lowercased() == "domain" {
                        cookieDict[.domain] = parts[1]
                    } else if parts[0].lowercased() == "path" {
                        cookieDict[.path] = parts[1]
                    } else if parts[0].lowercased() == "secure" {
                        cookieDict[.secure] = true
                    } else {
                        cookieDict[.name] = parts[0]
                        cookieDict[.value] = parts[1]
                    }
                }
            }
            if let _ = cookieDict[.name] as? String, let _ = cookieDict[.value] as? String {
                cookieDict[.domain] = cookieDict[.domain] as? String ?? ".apple.com"
                cookieDict[.path] = cookieDict[.path] as? String ?? "/"
                if let cookie = HTTPCookie(properties: cookieDict) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
    }
    func clearCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in cookies {
            if cookie.domain.contains("apple.com") {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
    // MARK: - 地区检测辅助方法
    
    /// 智能检测地区代码
    private func detectCountryCode(from response: StoreAuthResponse, email: String) -> String {
        print("🌍 [地区检测] 开始检测地区代码，邮箱: \(email)")
        
        // 1. 优先使用服务器返回的地区代码
        if let serverCountryCode = response.accountInfo.countryCode, !serverCountryCode.isEmpty {
            print("🌍 [地区检测] 使用服务器返回的地区代码: \(serverCountryCode)")
            return serverCountryCode
        }
        
        // 2. 从StoreFront中推断地区代码
        if let storeFront = response.accountInfo.storeFront, !storeFront.isEmpty {
            let inferredCountryCode = inferCountryCodeFromStoreFront(storeFront)
            print("🌍 [地区检测] 从StoreFront推断地区代码: \(inferredCountryCode) (StoreFront: \(storeFront))")
            return inferredCountryCode
        }
        
        // 3. 从Cookie中检测地区信息
        let cookieCountryCode = detectCountryCodeFromCookies()
        print("🌍 [地区检测] 从Cookie检测地区代码: \(cookieCountryCode)")
        // 只有当Cookie检测到的不是默认值时才返回
        if cookieCountryCode != "US" {
            return cookieCountryCode
        }
        
        // 4. 从邮箱域名推断地区（作为最后手段，但要谨慎）
        let emailCountryCode = inferCountryCodeFromEmail(email)
        print("🌍 [地区检测] 从邮箱推断地区代码: \(emailCountryCode)")
        // 只有当邮箱推断出具体地区时才返回
        if emailCountryCode != "US" {
            return emailCountryCode
        }
        
        // 5. 如果所有方法都失败，默认返回US（美区）
        print("🌍 [地区检测] 使用默认地区代码: US")
        return "US"
    }
    
    /// 从StoreFront推断地区代码
    private func inferCountryCodeFromStoreFront(_ storeFront: String) -> String {
        // 提取StoreFront的数字部分
        let storeFrontCode = storeFront.components(separatedBy: "-").first ?? storeFront
        print("🔍 [StoreFront解析] 提取的数字部分: \(storeFrontCode)")
        
        // 反向查找地区代码映射
        for (countryCode, code) in Apple.storeFrontCodeMap {
            if code == storeFrontCode {
                print("✅ [地区映射] 找到匹配: StoreFront=\(storeFrontCode) -> 国家代码=\(countryCode)")
                return countryCode
            }
        }
        
        print("❌ [地区映射] 未找到匹配的StoreFront代码: \(storeFrontCode)")
        return "US" // 默认值
    }
    
    /// 从Cookie中检测地区信息
    private func detectCountryCodeFromCookies() -> String {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return "US" }
        
        for cookie in cookies {
            if cookie.domain.contains("apple.com") {
                // 检查Cookie名称和值中是否包含地区信息
                let cookieString = "\(cookie.name)=\(cookie.value)"
                
                // 查找常见的地区标识符
                if cookieString.contains("storefront") || cookieString.contains("storeFront") {
                    // 尝试从Cookie值中提取StoreFront代码
                    let components = cookieString.components(separatedBy: "=")
                    if components.count > 1 {
                        let value = components[1]
                        let storeFrontCode = value.components(separatedBy: "-").first ?? value
                        return inferCountryCodeFromStoreFront(storeFrontCode)
                    }
                }
            }
        }
        
        return "US"
    }
    
    /// 从邮箱域名推断地区代码（保守策略）
    private func inferCountryCodeFromEmail(_ email: String) -> String {
        let domain = email.components(separatedBy: "@").last?.lowercased() ?? ""
        print("🌍 [邮箱检测] 分析邮箱域名: \(domain)")
        
        // 只对明确的地区域名进行推断，避免误判
        // 检查国家代码顶级域名（更可靠）
        if domain.hasSuffix(".cn") {
            print("🌍 [邮箱检测] 检测到.cn域名，推断为中国区")
            return "CN"
        } else if domain.hasSuffix(".jp") {
            print("🌍 [邮箱检测] 检测到.jp域名，推断为日本区")
            return "JP"
        } else if domain.hasSuffix(".kr") {
            print("🌍 [邮箱检测] 检测到.kr域名，推断为韩国区")
            return "KR"
        } else if domain.hasSuffix(".hk") {
            print("🌍 [邮箱检测] 检测到.hk域名，推断为香港区")
            return "HK"
        } else if domain.hasSuffix(".tw") {
            print("🌍 [邮箱检测] 检测到.tw域名，推断为台湾区")
            return "TW"
        } else if domain.hasSuffix(".sg") {
            print("🌍 [邮箱检测] 检测到.sg域名，推断为新加坡区")
            return "SG"
        } else if domain.hasSuffix(".au") {
            print("🌍 [邮箱检测] 检测到.au域名，推断为澳大利亚区")
            return "AU"
        } else if domain.hasSuffix(".ca") {
            print("🌍 [邮箱检测] 检测到.ca域名，推断为加拿大区")
            return "CA"
        } else if domain.hasSuffix(".uk") {
            print("🌍 [邮箱检测] 检测到.uk域名，推断为英国区")
            return "GB"
        } else if domain.hasSuffix(".de") {
            print("🌍 [邮箱检测] 检测到.de域名，推断为德国区")
            return "DE"
        } else if domain.hasSuffix(".fr") {
            print("🌍 [邮箱检测] 检测到.fr域名，推断为法国区")
            return "FR"
        }
        
        // 对于其他域名（包括gmail.com, yahoo.com等），默认返回US
        // 因为用户可能使用任何邮箱注册美区Apple ID
        print("🌍 [邮箱检测] 未检测到明确的地区域名，默认返回美区")
        return "US"
    }
    
    /// 智能检测StoreFront
    private func detectStoreFront(from response: StoreAuthResponse, countryCode: String) -> String {
        // 1. 优先使用服务器返回的StoreFront
        if let serverStoreFront = response.accountInfo.storeFront, !serverStoreFront.isEmpty {
            print("🏪 [商店检测] 使用服务器返回的StoreFront: \(serverStoreFront)")
            return serverStoreFront
        }
        
        // 2. 根据地区代码生成StoreFront
        let storeFrontCode = Apple.storeFrontCodeMap[countryCode] ?? "143441"
        let generatedStoreFront = "\(storeFrontCode)-1,29"
        print("🏪 [商店检测] 根据地区代码生成StoreFront: \(generatedStoreFront)")
        return generatedStoreFront
    }
    
    // MARK: - 钥匙串管理
    /// 将账户保存到钥匙串
    private func saveAccountToKeychain(_ account: Account) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
            kSecValueData as String: data
        ]
        // 删除现有项目
        SecItemDelete(query as CFDictionary)
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.keychainError
        }
    }
    /// 从钥匙串加载账户
    private func loadAccountFromKeychain() -> Account? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(Account.self, from: data)
    }
    /// 从钥匙串删除账户
    private func deleteAccountFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    /// 从钥匙串加载所有账户
    private func loadAllAccountsFromKeychain() -> [Account] {
        // 尝试加载新格式的多账户数据
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data else {
            print("🔐 [AuthenticationManager] 没有找到新格式的账户数据")
            return []
        }
        
        let decoder = JSONDecoder()
        // 尝试解码为账户数组
        if let accounts = try? decoder.decode([Account].self, from: data) {
            print("🔐 [AuthenticationManager] 成功解码账户数组，包含 \(accounts.count) 个账户")
            return accounts
        }
        // 如果失败，尝试解码为单个账户
        else if let account = try? decoder.decode(Account.self, from: data) {
            print("🔐 [AuthenticationManager] 成功解码单个账户，转换为数组")
            return [account]
        }
        else {
            print("🔐 [AuthenticationManager] 无法解码账户数据")
            return []
        }
    }
    
    /// 将所有账户保存到钥匙串
    private func saveAllAccountsToKeychain(_ accounts: [Account]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(accounts)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: self.keychainAccount,
            kSecValueData as String: data
        ]
        
        // 删除现有项目
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.keychainError
        }
    }
    
    // MARK: - 测试和调试方法
    
    /// 测试地区检测功能（仅用于调试）
    func testRegionDetection(email: String) -> String {
        print("🧪 [测试] 开始测试地区检测功能")
        print("📧 [测试] 测试邮箱: \(email)")
        
        let detectedCountryCode = inferCountryCodeFromEmail(email)
        print("🧪 [测试] 检测结果: \(detectedCountryCode)")
        
        return detectedCountryCode
    }
    
    /// 调试地区检测问题
    func debugRegionDetection(account: Account) {
        print("🔍 [调试] 开始调试地区检测问题")
        print("🔍 [调试] 账户邮箱: \(account.email)")
        print("🔍 [调试] 账户地区代码: \(account.countryCode)")
        print("🔍 [调试] 账户StoreFront: \(account.storeResponse.storeFront)")
        
        // 测试邮箱域名推断
        let emailInferred = inferCountryCodeFromEmail(account.email)
        print("🔍 [调试] 邮箱推断结果: \(emailInferred)")
        
        // 测试StoreFront推断
        let storeFrontInferred = inferCountryCodeFromStoreFront(account.storeResponse.storeFront)
        print("🔍 [调试] StoreFront推断结果: \(storeFrontInferred)")
        
        // 检查Cookie
        let cookieInferred = detectCountryCodeFromCookies()
        print("🔍 [调试] Cookie推断结果: \(cookieInferred)")
        
        print("🔍 [调试] 调试完成")
    }
}
// MARK: - 账户模型
// 账户定义现在位于Apple.swift中，以避免重复
