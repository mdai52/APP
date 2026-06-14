import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appStore: AppStore
    @State private var showingDeleteAlert = false
    @State private var isPasswordVisible = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Apple ID")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(spacing: 12) {
                            infoRow(label: "Apple ID", value: account.email)
                            infoRow(label: "姓名", value: account.name)
                            infoRow(label: "DS_ID", value: account.dsPersonId)
                            infoRow(label: "地区", value: account.countryCode)

                            HStack {
                                Text("密码 Token")
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                Text(isPasswordVisible ? account.passwordToken : String(repeating: "*", count: account.passwordToken.count))
                                    .foregroundColor(.primary)

                                Spacer()

                                Button(action: {
                                    isPasswordVisible.toggle()
                                }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(backgroundColor)
                    .cornerRadius(12)

                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("删除账户")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(backgroundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("删除", role: .destructive) {
                    deleteAccount()
                }
                Button("取消", role: .cancel) {
                    print("[AccountDetailView] 取消删除操作")
                    showingDeleteAlert = false
                }
            } message: {
                Text("确定要删除这个账户吗？此操作无法撤销。")
            }
        }
    }

    private var backgroundColor: Color {
        switch colorScheme {
        case .dark:
            return Color(.systemGray6).opacity(0.8)
        case .light:
            return Color(.systemGray6)
        @unknown default:
            return Color(.systemGray6)
        }
    }

    private var backgroundGradient: some View {
        Group {
            if colorScheme == .dark {

                Color.black
                    .ignoresSafeArea()
            } else {

                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private func deleteAccount() {
        print("[AccountDetailView] 登出账户: \(account.email)")

        appStore.logoutAccount()
        print("[AccountDetailView] 账户已登出")

        presentationMode.wrappedValue.dismiss()
    }
}
