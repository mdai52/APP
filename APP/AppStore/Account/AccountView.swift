import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AccountView: View {
    @State private var addSheet = false
    @EnvironmentObject var appStore: AppStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showDeleteAlert = false
    @State private var accountToDelete: Account?
    @State private var selectedAccountForDetail: Account?

    var body: some View {
        NavigationView {
            List {

                Section {
                    if let account = appStore.selectedAccount {
                        accountHeaderCard(account: account)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .onTapGesture {
                                selectedAccountForDetail = account
                            }
                    } else {
                        emptyAccountCard
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }


                if appStore.hasMultipleAccounts {
                    Section {
                        ForEach(Array(appStore.savedAccounts.enumerated()), id: \.element.id) { index, account in
                            Button(action: {
                                appStore.switchToAccount(at: index)
                            }) {
                                accountRow(account: account, isSelected: index == appStore.selectedAccountIndex)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    accountToDelete = account
                                    showDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("所有账户")
                    }
                }


                Section {
                    Button(action: {
                        addSheet.toggle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                            Text("添加 Apple ID")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }

                    if appStore.selectedAccount != nil {
                        Button(role: .destructive, action: {
                            if let account = appStore.selectedAccount {
                                accountToDelete = account
                                showDeleteAlert = true
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.red)
                                Text("退出登录")
                                    .font(.system(size: 15))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }


                if let account = appStore.selectedAccount {
                    Section {
                        NavigationLink(destination: AccountDetailView(account: account)) {
                            HStack {
                                Text("地区")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(flag(country: account.countryCode)) \(countryName(account.countryCode))")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("DSID")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(account.directoryServicesIdentifier)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } header: {
                        Text("账户信息")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Apple ID")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if appStore.selectedAccount != nil {
                        Button(action: { addSheet.toggle() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(themeManager.accentColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $addSheet) {
                AddAccountView()
                    .environmentObject(appStore)
                    .environmentObject(themeManager)
            }
            .sheet(item: $selectedAccountForDetail) { account in
                NavigationView {
                    AccountDetailView(account: account)
                }
                .environmentObject(appStore)
                .environmentObject(themeManager)
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {
                    accountToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let account = accountToDelete {
                        if appStore.savedAccounts.count == 1 {
                            appStore.logoutAccount()
                        } else if let index = appStore.savedAccounts.firstIndex(where: { $0.id == account.id }) {
                            appStore.deleteAccount(account)
                            if index <= appStore.selectedAccountIndex && appStore.selectedAccountIndex > 0 {
                                appStore.selectedAccountIndex -= 1
                            }
                        }
                        accountToDelete = nil
                    }
                }
            } message: {
                if let account = accountToDelete {
                    Text("确定要删除账户 \(account.email) 吗？此操作无法撤销。")
                }
            }
        }
        .navigationViewStyle(.stack)
    }



    private var emptyAccountCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Text("登录您的 Apple ID")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text("使用 Apple ID 下载和管理应用")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                addSheet.toggle()
            }) {
                Text("登录 Apple ID")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.accentColor)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
    }

    private func accountHeaderCard(account: Account) -> some View {
        HStack(spacing: 16) {
            AccountAvatarButton(size: 72)

            VStack(alignment: .leading, spacing: 6) {
                Text(account.name.isEmpty ? account.email : account.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !account.name.isEmpty {
                    Text(account.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(flag(country: account.countryCode))
                            .font(.caption)
                        Text(countryName(account.countryCode))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !account.dsPersonId.isEmpty {
                        Text("DS: \(account.dsPersonId)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                            )
                    }
                }
                .padding(.top, 2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }



    private func accountRow(account: Account, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(themeManager.accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(account.email.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.accentColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(account.email)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(flag(country: account.countryCode) + " " + countryName(account.countryCode))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.accentColor)
            }
        }
        .padding(.vertical, 2)
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

#Preview {
    AccountView()
        .environmentObject(AppStore.this)
        .environmentObject(ThemeManager.shared)
}
