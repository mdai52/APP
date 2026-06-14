import SwiftUI
import Foundation

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
    }
}
@MainActor
struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vm: AppStore
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var code: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showTwoFactorField: Bool = false
    @FocusState private var isCodeFieldFocused: Bool
    var body: some View {
        NavigationView {
            ZStack {

                themeManager.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    GeometryReader { geometry in
                        Color.clear
                            .frame(height: geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 44)
                    }
                    .frame(height: 44)

                    VStack(spacing: 0) {
                        Spacer()

                        VStack(spacing: 20) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                            VStack(spacing: 8) {
                                Text("Apple ID")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Text("登录您的账户")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        VStack(spacing: 24) {

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Apple ID")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                TextField("输入您的 Apple ID", text: $email)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("密码")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                SecureField("输入您的密码", text: $password)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }

                            if showTwoFactorField {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("双重认证码")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    TextField("输入6位验证码", text: $code)
                                        .textFieldStyle(ModernTextFieldStyle())
                                        .keyboardType(.numberPad)
                                        .focused($isCodeFieldFocused)
                                        .onChange(of: code) { newValue in

                                            let filtered = String(newValue.filter { $0.isNumber })

                                            if filtered.count > 6 {
                                                code = String(filtered.prefix(6))
                                            } else {
                                                code = filtered
                                            }

                                            if code.count == 6 {

                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                                                    isCodeFieldFocused = false

                                                    Task {
                                                        await authenticate()
                                                    }
                                                }
                                            }
                                        }
                                    Text("请查看您的受信任设备或短信获取验证码")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer()

                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await authenticate()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {

                                    }
                                    Text(isLoading ? "验证中..." : "添加账户")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)

                            if !errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("取消") {
                dismiss()
            }.foregroundColor(.primary))
            .onTapGesture {

                isCodeFieldFocused = false
            }
            .onAppear {

            }
        }
    }
    @MainActor
    private func authenticate() async {

        if email.isEmpty || password.isEmpty {
            errorMessage = "请输入完整的Apple ID和密码"
            return
        }

        if showTwoFactorField && code.count != 6 {
            errorMessage = "请输入6位验证码"

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isCodeFieldFocused = true
            }
            return
        }

        print("🔐 [AddAccountView] 开始认证流程")
        print("📧 [AddAccountView] Apple ID: \(email)")
        print("🔐 [AddAccountView] 密码长度: \(password.count)")
        print("📱 [AddAccountView] 验证码: \(showTwoFactorField ? code : "无")")

        isLoading = true
        errorMessage = ""
        isCodeFieldFocused = false

        do {

            try await vm.loginAccount(
                email: email,
                password: password,
                code: showTwoFactorField ? code : nil
            )

            print("✅ [AddAccountView] 认证成功，关闭视图")

            dismiss()
        } catch {
            print("❌ [AddAccountView] 认证失败: \(error)")
            print("❌ [AddAccountView] 错误类型: \(type(of: error))")

            isLoading = false

            if let storeError = error as? StoreError {
                print("🔍 [AddAccountView] 检测到StoreError: \(storeError)")

                switch storeError {
                case .invalidCredentials:
                    errorMessage = "Apple ID或密码错误，请检查后重试"
                case .codeRequired:
                    handleTwoFactorAuthRequired()
                case .lockedAccount:
                    errorMessage = "您的Apple ID已被锁定，请稍后再试或联系Apple支持"
                case .networkError:
                    errorMessage = "网络连接错误，请检查网络设置后重试"
                case .authenticationFailed:
                    errorMessage = "认证失败，请检查您的网络连接和账户信息"
                case .invalidResponse:
                    errorMessage = "服务器响应无效，请稍后重试"
                case .unknownError:
                    errorMessage = "未知错误，请稍后重试"
                default:
                    errorMessage = "认证过程中发生错误: \(storeError.localizedDescription)"
                }
            } else {

                print("🔍 [AddAccountView] 未知错误类型: \(error)")
                errorMessage = "认证过程中发生错误: \(error.localizedDescription)"
            }
        }
    }

    private func handleTwoFactorAuthRequired() {
        print("🔐 [AddAccountView] 需要双重认证码")

        if !showTwoFactorField {

            withAnimation(.easeInOut(duration: 0.3)) {
                showTwoFactorField = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isCodeFieldFocused = true
            }

            errorMessage = "请查看您的Apple设备上的验证码"
        } else {

            errorMessage = "验证码错误，请重新输入"

            code = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isCodeFieldFocused = true
            }
        }
    }
}
