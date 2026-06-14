import Foundation

@MainActor
class PurchaseManager: @unchecked Sendable {
    static let shared = PurchaseManager()

    private let searchManager = SearchManager.shared
    private init() {}

    func checkAppOwnership(
        appIdentifier: String,
        account: Account,
        countryCode: String = ""
    ) async -> Result<Bool, PurchaseError> {
        do {

            let trackId: String
            if Int(appIdentifier) != nil {
                trackId = appIdentifier
            } else {
                let trackIdResult = await searchManager.getTrackId(
                    bundleIdentifier: appIdentifier,
                    countryCode: countryCode,
                    deviceFamily: DeviceFamily.phone
                )
                switch trackIdResult {
                case .success(let id):
                    trackId = String(id)
                case .failure(let error):
                    return .failure(.appNotFound(error.localizedDescription))
                }
            }
            let downloadResponse = try await StoreRequest.shared.download(
                appIdentifier: trackId,
                directoryServicesIdentifier: account.directoryServicesIdentifier,
                appVersion: nil,
                passwordToken: account.passwordToken,
                storeFront: account.storeResponse.storeFront
            )

            return .success(!downloadResponse.songList.isEmpty)
        } catch let storeError as StoreError {

            if case .invalidLicense = storeError {
                print("🔐 [购买验证] 检测到许可证错误，用户未购买此应用")

                return .success(false)
            }

            return .failure(.networkError(storeError))
        } catch {

            return .failure(.networkError(error))
        }
    }

    func purchaseAppIfNeeded(
        appIdentifier: String,
        account: Account,
        countryCode: String = "",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<PurchaseResult, PurchaseError> {

        let ownershipResult = await checkAppOwnership(
            appIdentifier: appIdentifier,
            account: account,
            countryCode: countryCode
        )
        switch ownershipResult {
        case .success(let isOwned):
            if isOwned {
                let result = PurchaseResult(
                    trackId: appIdentifier,
                    success: true,
                    message: "应用已拥有，无需购买",
                    licenseInfo: nil
                )
                return .success(result)
            } else {

                do {
                    let _ = try await StoreRequest.shared.purchase(
                        appIdentifier: String(appIdentifier),
                        directoryServicesIdentifier: account.directoryServicesIdentifier,
                        passwordToken: account.passwordToken,
                        storeFront: account.storeResponse.storeFront
                    )
                    let result = PurchaseResult(
                        trackId: appIdentifier,
                        success: true,
                        message: "已完成获取（零元购买）",
                        licenseInfo: nil
                    )
                    return .success(result)
                } catch {
                    return .failure(.networkError(error))
                }
            }
        case .failure(let error):

            return .failure(error)
        }
    }

}

struct PurchaseResult {
    let trackId: String
    let success: Bool
    let message: String
    let licenseInfo: LicenseInfo?
}

struct LicenseInfo {
    let licenseId: String
    let purchaseDate: Date
    let expirationDate: Date?
    let isValid: Bool
}

enum PurchaseError: LocalizedError {
    case invalidIdentifier(String)
    case appNotFound(String)
    case priceMismatch(String)
    case invalidCountry(String)
    case passwordTokenExpired(String)
    case licenseAlreadyExists(String)
    case paymentRequired(String)
    case licenseCheckFailed(String)
    case networkError(Error)
    case unknownError(String)
    var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let message):
            return "无效的应用标识符: \(message)"
        case .appNotFound(let message):
            return "应用未找到: \(message)"
        case .priceMismatch(let message):
            return "价格不匹配: \(message)"
        case .invalidCountry(let message):
            return "无效的国家/地区: \(message)"
        case .passwordTokenExpired(let message):
            return "密码令牌已过期: \(message)"
        case .licenseAlreadyExists(let message):
            return "许可证已存在: \(message)"
        case .paymentRequired(let message):
            return "需要付款: \(message)"
        case .licenseCheckFailed(let message):
            return "许可证检查失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
}
