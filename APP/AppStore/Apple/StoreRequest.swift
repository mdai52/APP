import Foundation

class StoreRequestDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        if host.hasSuffix(".apple.com") || host.hasSuffix(".itunes.apple.com") {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

@MainActor
class StoreRequest: @unchecked Sendable {
    static let shared = StoreRequest()

    nonisolated(unsafe) private static var cachedGUID: String?
    private let session: URLSession
    private let baseURL = "https://p25-buy.itunes.apple.com"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300

        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true

        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.tlsMaximumSupportedProtocolVersion = .TLSv13

        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        self.session = URLSession(configuration: config, delegate: StoreRequestDelegate(), delegateQueue: delegateQueue)
    }

    func authenticate(
        email: String,
        password: String,
        mfa: String? = nil
    ) async throws -> StoreAuthResponse {
        print("🚀 [认证] 开始Apple ID认证流程")
        print("📧 [认证] Apple ID: \(email)")
        print("🔐 [认证] 密码长度: \(password.count) 字符")
        print("📱 [认证] 双重认证码: \(mfa != nil ? "已提供(\(mfa!.count)位)" : "未提供")")

        let authenticator = AppleIDAuthenticator.shared

        if let mfa = mfa, !mfa.isEmpty {
            print("🔐 [认证] 检测到验证码，提交2FA")
            do {
                let response = try await authenticator.validate2FACode(mfa)
                print("✅ [认证] 2FA验证成功")
                return response
            } catch {
                print("❌ [认证] 2FA验证失败: \(error.localizedDescription)")
                throw error
            }
        }

        do {
            let response = try await authenticator.authenticate(email: email, password: password)
            print("✅ [认证] SRP认证成功")
            return response
        } catch StoreError.codeRequired {
            print("🔐 [认证] 需要双因素认证码")
            throw StoreError.codeRequired
        } catch {
            print("❌ [认证] SRP认证失败: \(error.localizedDescription)")
            throw error
        }
    }

    func authenticateWith2FA(
        code: String,
        isSMS: Bool = false,
        phoneId: Any? = nil
    ) async throws -> StoreAuthResponse {
        print("🔐 [2FA认证] 提交双因素认证码: \(code.count)位")
        let authenticator = AppleIDAuthenticator.shared
        return try await authenticator.validate2FACode(code)
    }

    func download(
        appIdentifier: String,
        directoryServicesIdentifier: String,
        appVersion: String? = nil,
        passwordToken: String? = nil,
        storeFront: String? = nil
    ) async throws -> StoreDownloadResponse {
        let guid = acquireGUID()
        let url = URL(string: "\(baseURL)/WebObjects/MZFinance.woa/wa/volumeStoreDownloadProduct?guid=\(guid)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-apple-plist", forHTTPHeaderField: "Content-Type")
        request.setValue(getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue(directoryServicesIdentifier, forHTTPHeaderField: "X-Dsid")
        request.setValue(directoryServicesIdentifier, forHTTPHeaderField: "iCloud-DSID")

        if let passwordToken = passwordToken {
            request.setValue(passwordToken, forHTTPHeaderField: "X-Token")
        }
        if let storeFront = storeFront {
            request.setValue(normalizeStoreFront(storeFront), forHTTPHeaderField: "X-Apple-Store-Front")
        }

        var body: [String: Any] = [
            "creditDisplay": "",
            "guid": guid,
            "salableAdamId": appIdentifier
        ]

        if let appVersion = appVersion {

            if let versionId = Int(appVersion) {
                body["externalVersionId"] = versionId
            } else {

                body["externalVersionId"] = appVersion
            }
        }
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: body,
            format: .xml,
            options: 0
        )
        request.httpBody = plistData

        if let bodyString = String(data: plistData, encoding: .utf8) {
            print("[DEBUG] Request body: \(bodyString)")
        }
        print("[DEBUG] Request URL: \(url)")
        print("[DEBUG] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] ?? [:]
        return try parseDownloadResponse(plist: plist, httpResponse: httpResponse)
    }

    func purchase(
        appIdentifier: String,
        directoryServicesIdentifier: String,
        passwordToken: String,
        storeFront: String
    ) async throws -> StorePurchaseResponse {
        let guid = acquireGUID()

        let url = URL(string: "https://buy.itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("application/x-apple-plist", forHTTPHeaderField: "Content-Type")
        request.setValue(getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue(directoryServicesIdentifier, forHTTPHeaderField: "X-Dsid")
        request.setValue(directoryServicesIdentifier, forHTTPHeaderField: "iCloud-DSID")
        request.setValue(normalizeStoreFront(storeFront), forHTTPHeaderField: "X-Apple-Store-Front")
        request.setValue(passwordToken, forHTTPHeaderField: "X-Token")

        var body: [String: Any] = [
            "guid": guid,
            "salableAdamId": appIdentifier,
            "dsPersonId": directoryServicesIdentifier,
            "passwordToken": passwordToken,
            "price": "0",
            "pricingParameters": "STDQ",
            "productType": "C",
            "appExtVrsId": "0",
            "hasAskedToFulfillPreorder": "true",
            "buyWithoutAuthorization": "true",
            "hasDoneAgeCheck": "true",
            "needDiv": "0",
            "origPage": "Software-\(appIdentifier)",
            "origPageLocation": "Buy"
        ]

        body["pg"] = "default"
        body["sd"] = "true"
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: body,
            format: .xml,
            options: 0
        )
        request.httpBody = plistData

        if let bodyString = String(data: plistData, encoding: .utf8) {
            print("[DEBUG][BUY] Request body: \(bodyString)")
        }
        print("[DEBUG][BUY] Request URL: \(url)")
        print("[DEBUG][BUY] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StoreError.invalidResponse
        }
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] ?? [:]
        print("[DEBUG][BUY] HTTP Status Code: \(httpResponse.statusCode)")
        print("[DEBUG][BUY] Response keys: \(plist.keys.sorted())")
        return try parsePurchaseResponse(plist: plist, httpResponse: httpResponse)
    }

    func getUserAgent() -> String {
        return "Configurator/2.17 (Macintosh; OS X 15.2; 24C5089c) AppleWebKit/0620.1.16.11.6"
    }

    private func normalizeStoreFront(_ value: String) -> String {

        let digitsPrefix = value.split(separator: "-").first.map(String.init) ?? value

        return digitsPrefix.split(separator: ",").first.map(String.init) ?? digitsPrefix
    }

    private func acquireGUID() -> String {
        if let g = StoreRequest.cachedGUID, !g.isEmpty, g != "000000000000" { return g }

        let generated = Self.generateFallbackGUID()
        StoreRequest.cachedGUID = generated
        return generated
    }

    private static func generateFallbackGUID() -> String {
        let hex = "0123456789ABCDEF"
        var out = ""
        for _ in 0..<12 { out.append(hex.randomElement()!) }
        return out
    }

    func currentGUID() -> String { acquireGUID() }

    nonisolated static func setGUID(_ guid: String) {
        cachedGUID = guid
    }

    private func parseAuthResponse(
        plist: [String: Any],
        httpResponse: HTTPURLResponse
    ) throws -> StoreAuthResponse {
        print("🔍 [解析开始] parseAuthResponse - 状态码: \(httpResponse.statusCode)")
        if httpResponse.statusCode == 200 {
            print("✅ [状态检查] HTTP 200 - 认证请求成功")

            let possibleKeys = ["dsPersonId", "dsPersonID", "dsid", "DSID", "directoryServicesIdentifier"]
            print("🔍 [DSID搜索] 在根级别搜索可能的DSID键名: \(possibleKeys)")
            for key in possibleKeys {
                if let value = plist[key] {
                    print("🔍 [DEBUG] 找到键 '\(key)': \(value)")
                }
            }
        print("📋 [账户信息] 开始解析accountInfo...")
        let accountInfo = parseAccountInfo(from: plist)
        print("🔐 [令牌解析] 搜索passwordToken...")
        let passwordToken = plist["passwordToken"] as? String ?? ""
        print("🔐 [令牌结果] passwordToken: '\(passwordToken.isEmpty ? "空" : "已获取(\(passwordToken.count)字符)")")

        print("🌍 [地区检测] 开始检测地区信息...")
        if let accountInfo = accountInfo {
            print("🌍 [地区检测] accountInfo.countryCode: '\(accountInfo.countryCode ?? "空")'")
            print("🌍 [地区检测] accountInfo.storeFront: '\(accountInfo.storeFront ?? "空")'")
        } else {
            print("🌍 [地区检测] accountInfo为空，无法获取地区信息")
        }
            print("🆔 [DSID解析] 在根级别搜索dsPersonId...")

            let dsPersonId = (plist["dsPersonId"] as? String) ??
                           (plist["dsPersonID"] as? String) ??
                           (plist["dsid"] as? String) ??
                           (plist["DSID"] as? String) ??
                           (plist["directoryServicesIdentifier"] as? String) ?? ""
            print("🆔 [DSID结果] 根级别dsPersonId: '\(dsPersonId.isEmpty ? "空" : dsPersonId)'")
            print("📡 [Pings解析] 搜索pings数组...")
            let pings = plist["pings"] as? [String]
            print("📡 [Pings结果] pings: \(pings?.count ?? 0) 个项目")

            let accountDsPersonId = accountInfo?.dsPersonId ?? ""
            print("👤 [账户DSID] accountInfo中的dsPersonId: '\(accountDsPersonId.isEmpty ? "空" : accountDsPersonId)'")

            let finalDsPersonId = !dsPersonId.isEmpty ? dsPersonId : accountDsPersonId
            print("✅ [最终DSID] 选定的dsPersonId: '\(finalDsPersonId.isEmpty ? "空" : finalDsPersonId)'")
            print("🏗️ [构建响应] 创建StoreAuthResponse对象...")
            let response = StoreAuthResponse(
                accountInfo: accountInfo ?? StoreAuthResponse.AccountInfo(
                    appleId: "",
                    address: StoreAuthResponse.AccountInfo.Address(
                        firstName: "",
                        lastName: ""
                    ),
                    dsPersonId: finalDsPersonId,
                    countryCode: nil,
                    storeFront: nil
                ),
                passwordToken: passwordToken,
                dsPersonId: finalDsPersonId,
                pings: pings
            )
            print("✅ [响应完成] StoreAuthResponse创建成功")
            print("📊 [响应摘要] AppleID: \(response.accountInfo.appleId)")
            print("📊 [响应摘要] DSID: \(response.dsPersonId.isEmpty ? "空" : response.dsPersonId)")
            print("📊 [响应摘要] Token: \(response.passwordToken.isEmpty ? "空" : "已获取")")
            return response
        } else {
            print("❌ [认证失败] HTTP状态码: \(httpResponse.statusCode)")
            let failureType = plist["failureType"] as? String ?? ""
            let customerMessage = plist["customerMessage"] as? String ?? ""
            print("❌ [失败类型] failureType: \(failureType)")
            print("💬 [客户消息] customerMessage: \(customerMessage)")
            if let errorMessage = plist["errorMessage"] as? String {
                print("💬 [错误消息] errorMessage: \(errorMessage)")
            }
            print("🔍 [错误详情] 完整错误响应: \(plist)")

            if !failureType.isEmpty {
                throw StoreError.fromFailureType(failureType)
            } else if customerMessage == "MZFinance.BadLogin.Configurator_message" {
                throw StoreError.codeRequired
            } else if customerMessage.contains("AMD-Action") {

                print("⚠️ [AMD挑战] 检测到AMD安全挑战，尝试继续处理...")

                let emptyResponse = StoreAuthResponse(
                    accountInfo: StoreAuthResponse.AccountInfo(
                        appleId: "",
                        address: StoreAuthResponse.AccountInfo.Address(
                            firstName: "",
                            lastName: ""
                        ),
                        dsPersonId: "",
                        countryCode: "",
                        storeFront: nil
                    ),
                    passwordToken: "",
                    dsPersonId: "",
                    pings: []
                )
                return emptyResponse
            } else {
                throw StoreError.unknownError
            }
        }
    }

    private func parseAccountInfo(from plist: [String: Any]) -> StoreAuthResponse.AccountInfo? {
        guard let accountInfo = plist["accountInfo"] as? [String: Any] else {
            print("🔍 [DEBUG] parseAccountInfo: 未找到 accountInfo 字段")
            return nil
        }
        print("🔍 [DEBUG] parseAccountInfo: accountInfo 内容: \(accountInfo)")
        print("🔍 [DEBUG] parseAccountInfo: accountInfo 所有键: \(Array(accountInfo.keys))")
        let appleId = accountInfo["appleId"] as? String ?? ""
        let address = accountInfo["address"] as? [String: Any]
        let firstName = address?["firstName"] as? String ?? ""
        let lastName = address?["lastName"] as? String ?? ""

        let possibleKeys = ["dsPersonId", "dsPersonID", "dsid", "DSID", "directoryServicesIdentifier"]
        for key in possibleKeys {
            if let value = accountInfo[key] {
                print("🔍 [DEBUG] parseAccountInfo: 找到键 '\(key)': \(value)")
            }
        }

        let dsPersonId = (accountInfo["dsPersonId"] as? String) ??
                        (accountInfo["dsPersonID"] as? String) ??
                        (accountInfo["dsid"] as? String) ??
                        (accountInfo["DSID"] as? String) ??
                        (accountInfo["directoryServicesIdentifier"] as? String) ?? ""
        print("🔍 [DEBUG] parseAccountInfo: 最终获取的 dsPersonId: '\(dsPersonId)')")

        let countryCode = detectCountryCodeFromAccountInfo(accountInfo)
        let storeFront = detectStoreFrontFromAccountInfo(accountInfo)

        print("🌍 [地区解析] 检测到的countryCode: '\(countryCode ?? "空")'")
        print("🏪 [商店解析] 检测到的storeFront: '\(storeFront ?? "空")'")

        return StoreAuthResponse.AccountInfo(
            appleId: appleId,
            address: StoreAuthResponse.AccountInfo.Address(
                firstName: firstName,
                lastName: lastName
            ),
            dsPersonId: dsPersonId,
            countryCode: countryCode,
            storeFront: storeFront
        )
    }

    private func detectCountryCodeFromAccountInfo(_ accountInfo: [String: Any]) -> String? {

        if let countryCode = accountInfo["countryCode"] as? String, !countryCode.isEmpty {
            print("🌍 [地区检测] 直接获取countryCode: \(countryCode)")
            return countryCode
        }

        if let storeFront = accountInfo["storeFront"] as? String, !storeFront.isEmpty {
            let inferredCountryCode = inferCountryCodeFromStoreFront(storeFront)
            print("🌍 [地区检测] 从storeFront推断countryCode: \(inferredCountryCode)")
            return inferredCountryCode
        }

        let regionFields = ["region", "country", "locale", "territory", "market"]
        for field in regionFields {
            if let value = accountInfo[field] as? String, !value.isEmpty {
                print("🌍 [地区检测] 从\(field)字段获取: \(value)")
                return value.uppercased()
            }
        }

        return nil
    }

    private func detectStoreFrontFromAccountInfo(_ accountInfo: [String: Any]) -> String? {

        if let storeFront = accountInfo["storeFront"] as? String, !storeFront.isEmpty {
            print("🏪 [商店检测] 直接获取storeFront: \(storeFront)")
            return storeFront
        }

        let storeFields = ["storefront", "storeFront", "store_front", "marketId", "market_id"]
        for field in storeFields {
            if let value = accountInfo[field] as? String, !value.isEmpty {
                print("🏪 [商店检测] 从\(field)字段获取: \(value)")
                return value
            }
        }

        return nil
    }

    private func inferCountryCodeFromStoreFront(_ storeFront: String) -> String {

        let storeFrontCode = storeFront.components(separatedBy: "-").first ?? storeFront
        print("🔍 [StoreFront解析] 提取的数字部分: \(storeFrontCode)")

        for (countryCode, code) in Apple.storeFrontCodeMap {
            if code == storeFrontCode {
                print("✅ [地区映射] 找到匹配: StoreFront=\(storeFrontCode) -> 国家代码=\(countryCode)")
                return countryCode
            }
        }

        return ""
    }

    private func parseDownloadResponse(
        plist: [String: Any],
        httpResponse: HTTPURLResponse
    ) throws -> StoreDownloadResponse {

        print("[DEBUG] HTTP Status Code: \(httpResponse.statusCode)")
        print("[DEBUG] Response plist keys: \(plist.keys.sorted())")
        if let songListRaw = plist["songList"] {
            print("[DEBUG] songList type: \(type(of: songListRaw))")
            print("[DEBUG] songList content: \(songListRaw)")
        } else {
            print("[DEBUG] songList not found in response")
        }

        if httpResponse.statusCode == 200 {
            var songList: [StoreItem] = []
            if let songs = plist["songList"] as? [[String: Any]] {
                songList = songs.compactMap { parseStoreItem(from: $0) }
            }
            print("[DEBUG] Parsed songList count: \(songList.count)")

            if songList.isEmpty {
                print("[DEBUG] songList为空，用户可能未购买此应用")
                throw StoreError.invalidLicense
            }

            let dsPersonId = plist["dsPersonID"] as? String ?? ""
            let jingleDocType = plist["jingleDocType"] as? String
            let jingleAction = plist["jingleAction"] as? String
            let pings = plist["pings"] as? [String]
            return StoreDownloadResponse(
                songList: songList,
                dsPersonId: dsPersonId,
                jingleDocType: jingleDocType,
                jingleAction: jingleAction,
                pings: pings
            )
        } else {
            let failureType = plist["failureType"] as? String ?? "unknownError"
            print("[DEBUG] Error response - failureType: \(failureType)")
            throw StoreError.fromFailureType(failureType)
        }
    }

    private func parseStoreItem(from dict: [String: Any]) -> StoreItem? {
        guard let url = dict["URL"] as? String,
              let md5 = dict["md5"] as? String else {
            return nil
        }
        var sinfs: [SinfInfo] = []
        if let sinfsArray = dict["sinfs"] as? [[String: Any]] {
            sinfs = sinfsArray.compactMap { sinfDict in
                guard let id = sinfDict["id"] as? Int,
                      let sinfString = sinfDict["sinf"] as? String else {
                    return nil
                }
                return SinfInfo(id: id, sinf: sinfString)
            }
        }
        var metadata: AppMetadata
        if let metadataDict = dict["metadata"] as? [String: Any] {

            let bundleId = metadataDict["softwareVersionBundleId"] as? String ??
                          metadataDict["bundle-identifier"] as? String ?? ""
            let bundleDisplayName = metadataDict["bundleDisplayName"] as? String ??
                                   metadataDict["itemName"] as? String ??
                                   metadataDict["item-name"] as? String ?? ""
            let bundleShortVersionString = metadataDict["bundleShortVersionString"] as? String ??
                                          metadataDict["bundle-short-version-string"] as? String ?? ""
            let softwareVersionExternalIdentifier = String(metadataDict["softwareVersionExternalIdentifier"] as? Int ?? 0)
            let softwareVersionExternalIdentifiers = metadataDict["softwareVersionExternalIdentifiers"] as? [Int]
            print("[DEBUG] 解析metadata字段:")
            print("[DEBUG] - bundleId: \(bundleId)")
            print("[DEBUG] - bundleDisplayName: \(bundleDisplayName)")
            print("[DEBUG] - bundleShortVersionString: \(bundleShortVersionString)")
            print("[DEBUG] - softwareVersionExternalIdentifier: \(softwareVersionExternalIdentifier)")
            print("[DEBUG] - softwareVersionExternalIdentifiers count: \(softwareVersionExternalIdentifiers?.count ?? 0)")
            metadata = AppMetadata(
                bundleId: bundleId,
                bundleDisplayName: bundleDisplayName,
                bundleShortVersionString: bundleShortVersionString,
                softwareVersionExternalIdentifier: softwareVersionExternalIdentifier,
                softwareVersionExternalIdentifiers: softwareVersionExternalIdentifiers
            )
        } else {
            metadata = AppMetadata(
                bundleId: "",
                bundleDisplayName: "",
                bundleShortVersionString: "",
                softwareVersionExternalIdentifier: "",
                softwareVersionExternalIdentifiers: nil
            )
        }
        return StoreItem(
            url: url,
            md5: md5,
            sinfs: sinfs,
            metadata: metadata
        )
    }

    private func parsePurchaseResponse(
        plist: [String: Any],
        httpResponse: HTTPURLResponse
    ) throws -> StorePurchaseResponse {
        if httpResponse.statusCode == 200 {

            if plist["dialog"] != nil || plist["failureType"] != nil {
                throw StoreError.userInteractionRequired
            }
            let dsPersonId = plist["dsPersonID"] as? String ?? ""
            let jingleDocType = plist["jingleDocType"] as? String
            let jingleAction = plist["jingleAction"] as? String
            let pings = plist["pings"] as? [String]
            return StorePurchaseResponse(
                dsPersonId: dsPersonId,
                jingleDocType: jingleDocType,
                jingleAction: jingleAction,
                pings: pings
            )
        } else {
            throw StoreError.fromFailureType(plist["failureType"] as? String ?? "unknownError")
        }
    }
}

public enum StoreError: Error, LocalizedError, Equatable {
    case networkError(Error)
    case invalidResponse
    case authenticationFailed
    case accountNotFound
    case invalidCredentials
    case serverError(Int)
    case unknown(String)
    case genericError
    case invalidItem
    case invalidLicense
    case unknownError
    case codeRequired
    case lockedAccount
    case keychainError
    case userInteractionRequired
    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed"
        case .accountNotFound:
            return "Account not found"
        case .invalidCredentials:
            return "Invalid credentials"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .genericError:
            return "Generic error occurred"
        case .invalidItem:
            return "Invalid item"
        case .invalidLicense:
            return "Invalid license"
        case .codeRequired:
            return "Verification code required"
        case .lockedAccount:
            return "Account is locked"
        case .keychainError:
            return "Keychain error occurred"
        case .userInteractionRequired:
            return "需要在 App Store 完成一次身份验证/获取"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
    public static func fromFailureType(_ failureType: String) -> StoreError {
        switch failureType {
        case "authenticationFailed":
            return .authenticationFailed
        case "accountNotFound":
            return .accountNotFound
        case "invalidCredentials":
            return .invalidCredentials
        case "codeRequired":
            return .codeRequired
        case "lockedAccount":
            return .lockedAccount
        default:
            return .unknownError
        }
    }
    public static func == (lhs: StoreError, rhs: StoreError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
             (.authenticationFailed, .authenticationFailed),
             (.accountNotFound, .accountNotFound),
             (.invalidCredentials, .invalidCredentials),
             (.genericError, .genericError),
             (.invalidItem, .invalidItem),
             (.invalidLicense, .invalidLicense),
             (.unknownError, .unknownError):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
struct StoreAuthResponse: Codable {
    let accountInfo: AccountInfo
    let passwordToken: String
    let dsPersonId: String
    let pings: [String]?
    struct AccountInfo: Codable {
        let appleId: String
        let address: Address
        let dsPersonId: String
        let countryCode: String?
        let storeFront: String?
        struct Address: Codable {
            let firstName: String
            let lastName: String
        }
    }
}

struct StoreDownloadResponse: Codable {
    let songList: [StoreItem]
    let dsPersonId: String
    let jingleDocType: String?
    let jingleAction: String?
    let pings: [String]?
}

struct StorePurchaseResponse: Codable {
    let dsPersonId: String
    let jingleDocType: String?
    let jingleAction: String?
    let pings: [String]?
}

struct StoreItem: Codable {
    let url: String
    let md5: String
    let sinfs: [SinfInfo]
    let metadata: AppMetadata
}

struct AppMetadata: Codable {
    let bundleId: String
    let bundleDisplayName: String
    let bundleShortVersionString: String
    let softwareVersionExternalIdentifier: String
    let softwareVersionExternalIdentifiers: [Int]?
    enum CodingKeys: String, CodingKey {
        case bundleId = "softwareVersionBundleId"
        case bundleDisplayName
        case bundleShortVersionString
        case softwareVersionExternalIdentifier
        case softwareVersionExternalIdentifiers
    }
}

struct SinfInfo: Codable {
    let id: Int
    let sinf: String
}
