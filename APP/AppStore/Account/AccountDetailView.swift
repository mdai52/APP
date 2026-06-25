import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appStore: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDeleteAlert = false
    @State private var isPasswordVisible = false

    var body: some View {
        List {

            Section {
                accountHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }


            Section {
                infoRow(title: "Apple ID", value: account.email, isEmail: true)
                infoRow(title: "姓名", value: account.name)
            } header: {
                Text("基本信息")
            }


            Section {
                infoRow(title: "DSID", value: account.directoryServicesIdentifier, isMonospaced: true)
            } header: {
                Text("账户标识")
            }


            Section {
                HStack {
                    Text("国家/地区")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(flag(country: account.countryCode)) \(countryName(account.countryCode))")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("地区")
            }


            Section {
                HStack {
                    Text("密码 Token")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Spacer()

                    if account.passwordToken.isEmpty {
                        Text("无")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                    } else {
                        Text(isPasswordVisible ? account.passwordToken : String(repeating: "•", count: min(account.passwordToken.count, 16)))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 180, alignment: .trailing)

                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(themeManager.accentColor)
                                .font(.system(size: 14))
                        }
                        .padding(.leading, 4)
                    }
                }
            } header: {
                Text("认证信息")
            } footer: {
                Text("密码 Token 用于自动验证身份，请勿泄露给他人。")
            }


            Section {
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("删除此账户")
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("账户详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("返回") {
                    dismiss()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(themeManager.accentColor)
            }
        }
        .alert("删除账户", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                showingDeleteAlert = false
            }
            Button("删除", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("确定要从设备上删除账户 \(account.email) 吗？\n\n删除后，此账户的所有登录信息和 Cookie 都将被移除。")
        }
    }



    private var accountHeader: some View {
        VStack(spacing: 12) {
            AccountAvatarButton(size: 80)

            VStack(spacing: 4) {
                Text(account.name.isEmpty ? account.email : account.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                if !account.name.isEmpty {
                    Text(account.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    Text(flag(country: account.countryCode))
                        .font(.caption)
                    Text(countryName(account.countryCode))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
    }



    private func infoRow(title: String, value: String, isEmail: Bool = false, isMonospaced: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            if value.isEmpty {
                Text("无")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary.opacity(0.5))
            } else {
                Text(value)
                    .font(isMonospaced ? .system(size: 14, design: .monospaced) : .system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }



    private func deleteAccount() {
        if appStore.savedAccounts.count == 1 {
            appStore.logoutAccount()
        } else {
            appStore.deleteAccount(account)
        }
        dismiss()
    }



    private func flag(country: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in country.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s
    }

    private func countryName(_ code: String) -> String {
        let chineseNames: [String: String] = [
            "CN": "中国大陆", "US": "美国", "JP": "日本", "KR": "韩国",
            "HK": "香港", "TW": "台湾", "SG": "新加坡", "GB": "英国",
            "DE": "德国", "FR": "法国", "AU": "澳大利亚", "CA": "加拿大",
            "BR": "巴西", "IN": "印度", "RU": "俄罗斯", "IT": "意大利",
            "ES": "西班牙", "MX": "墨西哥", "NL": "荷兰", "SE": "瑞典",
            "TR": "土耳其", "AR": "阿根廷", "CL": "智利", "CO": "哥伦比亚",
            "PE": "秘鲁", "PL": "波兰", "SA": "沙特阿拉伯", "TH": "泰国",
            "PH": "菲律宾", "MY": "马来西亚", "ID": "印度尼西亚", "VN": "越南",
            "ZA": "南非", "AE": "阿联酋", "EG": "埃及", "NG": "尼日利亚",
            "IL": "以色列", "BE": "比利时", "CH": "瑞士", "AT": "奥地利",
            "DK": "丹麦", "FI": "芬兰", "NO": "挪威", "IE": "爱尔兰",
            "PT": "葡萄牙", "CZ": "捷克", "HU": "匈牙利", "RO": "罗马尼亚",
            "GR": "希腊", "NZ": "新西兰", "PK": "巴基斯坦", "BD": "孟加拉国"
        ]
        return chineseNames[code.uppercased()] ?? Locale.current.localizedString(forRegionCode: code) ?? code.uppercased()
    }
}
