import SwiftUI
import UIKit

struct AccountAvatarButton: View {
    @EnvironmentObject private var appStore: AppStore
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var cachedAvatarImage: UIImage?

    var size: CGFloat = 36

    var body: some View {
        avatarView
            .onAppear { loadAvatar() }
            .onChange(of: appStore.selectedAccount?.email) { _ in
                loadAvatar()
            }
    }

    private var avatarView: some View {
        Group {
            if let image = cachedAvatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(themeManager.accentColor.opacity(0.5), lineWidth: 1.5)
                    )
            } else {
                Image(systemName: appStore.selectedAccount == nil ? "person.circle" : "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(appStore.selectedAccount == nil ? .secondary : themeManager.accentColor)
            }
        }
        .frame(width: size, height: size)
    }

    private func loadAvatar() {
        guard let account = appStore.selectedAccount else {
            cachedAvatarImage = nil
            return
        }
        let cacheKey = "appleid_avatar_\(account.email)"
        if let cached = UserDefaults.standard.data(forKey: cacheKey),
           let image = UIImage(data: cached) {
            cachedAvatarImage = image
            return
        }
        Task {
            AuthenticationManager.shared.setCookies(account.cookies)
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let cookies = HTTPCookieStorage.shared.cookies,
                  !cookies.isEmpty else { return }
            let config = URLSessionConfiguration.default
            let cookieStorage = HTTPCookieStorage()
            cookies.filter { $0.domain.contains("apple.com") }.forEach { cookieStorage.setCookie($0) }
            config.httpCookieStorage = cookieStorage
            let session = URLSession(configuration: config)
            guard let url = URL(string: "https://appleid.apple.com/account/photo") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("https://appleid.apple.com", forHTTPHeaderField: "Referer")
            do {
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let image = UIImage(data: data) {
                    cachedAvatarImage = image
                    if let pngData = image.pngData() {
                        UserDefaults.standard.set(pngData, forKey: cacheKey)
                    }
                }
            } catch {
                print("[AccountAvatarButton] 加载头像失败: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    AccountAvatarButton()
        .environmentObject(AppStore.this)
        .environmentObject(ThemeManager.shared)
}
