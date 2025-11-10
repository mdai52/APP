//
//  SearchView.swift
//  Created by pxx917144686 on 2025/09/08.
//
import SwiftUI
import UIKit

// UIBlurEffect包装器
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// glassEffect修饰符扩展
 extension View {
     func glassEffect() -> some View {
         self.background(
             BlurView(style: .systemThinMaterial)
         )
         .clipShape(RoundedRectangle(cornerRadius: 16))
         .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
     }
     
     func glassEffect(backgroundColor: Color) -> some View {
         self.background(
             backgroundColor
                 .blendMode(.overlay)
                 .background(BlurView(style: .systemThinMaterial))
         )
         .clipShape(RoundedRectangle(cornerRadius: 16))
         .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
     }
 }


// Date扩展，iso8601格式化
 extension Date {
     var iso8601: String {
         let formatter = ISO8601DateFormatter()
         return formatter.string(from: self)
     }
 }

// 卡片组件
struct EnhancedAppCard: SwiftUI.View {
    let app: iTunesSearchResult
    let onTap: () -> Void
    @Binding var isDownloading: Bool
    @SwiftUI.EnvironmentObject var themeManager: ThemeManager    
    @State private var isPressed = false
    
    var body: some SwiftUI.View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                topSection
                
                // 功能标签区域
                if !getFeatureTags().isEmpty {
                    featuresSection
                }
                
                // 截图预览区域
                if let screenshots = app.screenshotUrls, !screenshots.isEmpty {
                    screenshotsSection(screenshots)
                }
            }
            .padding()
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut, value: isPressed)
        .onLongPressGesture(pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    // 获取应用功能标签
    private func getFeatureTags() -> [String] {        
        var tags: [String] = []
        
        // 从genres中提取标签
        if let genres = app.genres, !genres.isEmpty {            
            tags.append(contentsOf: genres.prefix(3))        
        } else if let primaryGenre = app.primaryGenreName {            
            // 使用主要分类作为后备选项
            tags.append(primaryGenre)        
        }
        
        // 添加开发者信息作为标签
        if let developer = app.artistName, !tags.contains(developer) {            
            tags.append(developer)        
        }
        
        // 移除重复标签并限制数量
        let result = Array(Set(tags)).prefix(3).map { $0 }
        print("App: \(app.name), Genres: \(app.genres ?? []), Primary Genre: \(app.primaryGenreName ?? "nil"), Feature Tags: \(result)")
        return result
    }
    
    // 顶部区域
    private var topSection: some SwiftUI.View {
        HStack(alignment: .center, spacing: 12) {
            // app图标
            appIcon
            
            // app信息
            VStack(alignment: .leading, spacing: 4) {
                // app名称
                Text(app.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // 开发者
                if let developer = app.artistName {
                    Text(developer)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 评分
                if let rating = app.averageUserRating, rating > 0, let count = app.userRatingCount, count > 0 {
                    HStack(spacing: 4) {
                        HStack(spacing: 1) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(formatRatingCount(count))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // 获取按钮
            getButton
        }
    }
    
    // 功能标签区域
    private var featuresSection: some SwiftUI.View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(getFeatureTags(), id: \.self) { tag in
                    HStack(spacing: 4) {
                        if tag.contains("社交") {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                        } else if tag.contains("娱乐") {
                            Image(systemName: "film.fill")
                                .font(.system(size: 10))
                        } else if tag.contains("工具") || tag.contains("效率") {
                            Image(systemName: "wrench.fill")
                                .font(.system(size: 10))
                        } else if tag.contains("游戏") {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 10))
                        } else {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 10))
                        }
                        Text(tag)
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }
    
    // 截图预览区域
    private func screenshotsSection(_ screenshots: [String]) -> some SwiftUI.View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(screenshots.prefix(3), id: \.self) { screenshotURL in
                    if let url = URL(string: screenshotURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 120, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }
    
    // app图标
    private var appIcon: some SwiftUI.View {
        Group {
            if let iconURL = app.artworkUrl100, let url = URL(string: iconURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "app.fill")
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "app.fill")
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
    }
    
    // 获取按钮
    private var getButton: some SwiftUI.View {
        Group {
            if isDownloading {
                // 下载中显示加载指示器
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            } else {
                // 正常状态显示按钮
                Text(app.formattedPrice == "免费" || app.price == 0 ? "获取" : (app.formattedPrice ?? "查看"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
        }
    }
    
    // 评分格式化方法
    private func formatRatingCount(_ count: Int) -> String {
        if count >= 10000 {
            return "\(count / 10000)万"
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
    
    
}


// 搜索建议视图
struct SearchSuggestionsView: SwiftUI.View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    @SwiftUI.EnvironmentObject var themeManager: ThemeManager
    
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button(action: {
                    onSelect(suggestion)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text(suggestion)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion != suggestions.last {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .glassEffect()
    }
}

// 负责处理与iTunes API的交互
class APIService: NSObject, URLSessionDelegate {
    static let shared = APIService()
    
    let baseURL = "https://itunes.apple.com"
    
    enum Endpoint {
        case search(term: String, country: String, limit: Int = 20)
        case lookup(id: String)
        case reviews(id: String, page: Int = 1)
        case similar(id: String, limit: Int = 10)
        
        private static let baseURL = "https://itunes.apple.com"
        
        var urlString: String {
            switch self {
            case .search(let term, let country, let limit):
                return "\(Self.baseURL)/search?term=\(term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term)&country=\(country)&media=software&limit=\(limit)"
            case .lookup(let id):
                return "\(Self.baseURL)/lookup?id=\(id)"
            case .reviews(let id, let page):
                return "\(Self.baseURL)/customer-reviews/id=\(id)/page=\(page)"
            case .similar(let id, let limit):
                return "\(Self.baseURL)/similar/id=\(id)/limit=\(limit)"
            }
        }
    }
    
    func post<T: Codable>(urlString: String, parameters: [String: Any], completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.apple", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "com.apple", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(T.self, from: data)
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            }
            
            task.resume()
        } catch {
            completion(.failure(error))
        }
    }
}

// 评论模型
struct AppReview: Codable, Identifiable {
    let id: String
    let userName: String
    let rating: Double
    let title: String
    let content: String
    let date: Date
    let version: String
}

// 空状态视图
struct EmptyStateView: SwiftUI.View {
    let message: String
    let imageName: String
    
    var body: some SwiftUI.View {
        VStack(spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// app评论视图
struct AppReviewsView: SwiftUI.View {
    @State private var reviews: [AppReview] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    let appID: String
    
    var body: some SwiftUI.View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if reviews.isEmpty {
                EmptyStateView(message: "暂无评论", imageName: "star.fill")
            } else {
                List(reviews) { review in
                    ReviewCard(review: review)
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear(perform: fetchReviews)
    }
    
    func fetchReviews() {
        Task {
            self.isLoading = true
            self.errorMessage = nil
            
            do {
                // 使用iTunesClient获取真实评论数据
                let appID = Int(self.appID) ?? 0
                if appID > 0 {
                    let apiReviews = try await iTunesClient.shared.reviews(id: appID)
                    
                    // 映射API返回的数据到我们的AppReview结构
                    self.reviews = apiReviews.map { apiReview in
                        // 处理日期转换
                        let dateFormatter = ISO8601DateFormatter()
                        let date = dateFormatter.date(from: apiReview.updated) ?? Date()
                        
                        return AppReview(
                            id: apiReview.id,
                            userName: apiReview.userName,
                            rating: Double(apiReview.score), // 将Int转换为Double
                            title: apiReview.title,
                            content: apiReview.text,
                            date: date,
                            version: apiReview.version
                        )
                    }
                }
            } catch {
                self.errorMessage = "获取评论失败: \(error.localizedDescription)"
                print("评论获取错误: \(error)")
            }
            self.isLoading = false
        }
    }
}

// 评论卡片视图
struct ReviewCard: SwiftUI.View {
    let review: AppReview
    
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(review.userName)
                        .font(.headline)
                    
                    // 星级评分显示
                    HStack(spacing: 2) {
                        ForEach(1..<6) { star in
                            Image(systemName: star <= Int(review.rating) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= Int(review.rating) ? .yellow : .gray)
                        }
                        Text("\(review.rating)/5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            Text(review.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(review.content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text("版本 \(review.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formattedDate(review.date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// 详情页面
struct EnhancedAppDetailView: SwiftUI.View {
    let app: iTunesSearchResult
    // 主操作回调：由外部（SearchView）决定点击"获取"的逻辑
    var onPrimaryAction: ((iTunesSearchResult) -> Void)? = nil
    @Binding var isDownloading: Bool
    @SwiftUI.Environment(\.dismiss) var dismiss
    @SwiftUI.EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 头部：图标 + 基本信息
                headerSection
                
                // 截图展示
                if let screenshots = app.screenshotUrls, !screenshots.isEmpty {
                    screenshotsSection(screenshots)
                }

                
                // 评分和评论
                if let rating = app.averageUserRating, rating > 0 {
                    ratingsSection
                    // 评论列表
                    AppReviewsView(appID: String(app.trackId))
                        .padding(.horizontal, 16)
                        .frame(height: 300)
                }
                
                // app描述
                if let description = app.description {
                    descriptionSection(description)
                }
                
                // app信息
                informationSection
                
                // 更新信息
                if let releaseNotes = app.releaseNotes, !releaseNotes.isEmpty {
                    updateNotesSection(releaseNotes)
                }
                
                // 技术信息
                technicalInfoSection
            }
            .padding()
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // 头部区域
    private var headerSection: some SwiftUI.View {
        HStack(alignment: .top, spacing: 16) {
            // app图标
            Group {
                if let iconURL = app.artworkUrl512 ?? app.artworkUrl100, let url = URL(string: iconURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // app信息
            VStack(alignment: .leading, spacing: 8) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let developer = app.artistName {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let genre = app.primaryGenreName {
                    Text(genre)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 获取按钮
                Button(action: { onPrimaryAction?(app) }) {
                    if isDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 20, height: 20)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.accentColor)
                            )
                    } else {
                        Text(buttonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.accentColor)
                            )
                    }
                }
                .disabled(isDownloading) // 下载时禁用按钮
            }
        }
        .padding(.vertical)
    }
    
    // 截图区域
    private func screenshotsSection(_ screenshots: [String]) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览")
                .font(.title3)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(screenshots, id: \.self) { screenshotURL in
                        if let url = URL(string: screenshotURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(height: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // 评分区域
    private var ratingsSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 16) {
            Text("评分与评论")
                .font(.title3)
                .fontWeight(.bold)
            
            HStack(spacing: 40) {
                // 平均评分
                VStack(spacing: 8) {
                    Text(String(format: "%.1f", app.averageUserRating ?? 0))
                        .font(.system(size: 48, weight: .bold))
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int((app.averageUserRating ?? 0).rounded()) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let count = app.userRatingCount {
                        Text("\(formatNumber(count)) 个评分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 评分分布
                VStack(alignment: .leading, spacing: 4) {
                    ForEach((1...5).reversed(), id: \.self) { star in
                        HStack(spacing: 8) {
                            Text("\(star)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                    
                                    Rectangle()
                                        .fill(Color.orange)
                                        .frame(width: geometry.size.width * randomPercentage())
                                }
                            }
                            .frame(height: 4)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.selectedTheme == .dark ? Color(.systemGray6) : Color(.systemGray6).opacity(0.5))
            )
        }
    }
    
    // 描述区域
    private func descriptionSection(_ description: String) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            Text("描述")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(6)
        }
    }
    
    // 信息区域
    private var informationSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 16) {
            Text("信息")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                if let seller = app.sellerName {
                    infoRow(title: "开发者", value: seller)
                }
                
                if let size = app.fileSizeBytes, !size.isEmpty {
                    infoRow(title: "大小", value: formatFileSize(size))
                }
                
                if let category = app.primaryGenreName {
                    infoRow(title: "类别", value: category)
                }
                
                if let genres = app.genres, !genres.isEmpty {
                    infoRow(title: "分类", value: genres.joined(separator: ", "))
                }
                
                if !app.version.isEmpty {
                    infoRow(title: "当前版本", value: app.version)
                }
                
                if let minOS = app.minimumOsVersion, !minOS.isEmpty {
                    infoRow(title: "兼容性", value: "需要 iOS \(minOS) 或更高版本")
                }
                
                if let rating = app.contentAdvisoryRating, !rating.isEmpty {
                    infoRow(title: "年龄分级", value: rating)
                }
                
                if let languages = app.languageCodesISO2A, !languages.isEmpty {
                    infoRow(title: "语言", value: "\(languages.count) 种语言")
                }
            }
        }
    }
    
    // 更新信息区域
    private func updateNotesSection(_ notes: String) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            Text("更新信息")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                if !app.version.isEmpty {
                    Text("版本 \(app.version)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            }
        }
    }
    
    // 技术信息区域
    private var technicalInfoSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 16) {
            Text("技术信息")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                infoRow(title: "Bundle ID", value: app.bundleId)
                infoRow(title: "Track ID", value: String(app.trackId))
                
                if let releaseDate = app.releaseDate, !releaseDate.isEmpty {
                    infoRow(title: "首次发布", value: formatReleaseDate(releaseDate))
                }
                
                if let updateDate = app.currentVersionReleaseDate, !updateDate.isEmpty {
                    infoRow(title: "最后更新", value: formatReleaseDate(updateDate))
                }
            }
        }
    }
    
    // 辅助方法
    private func infoRow(title: String, value: String) -> some SwiftUI.View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatFileSize(_ sizeString: String) -> String {
        if let sizeBytes = Double(sizeString) {
            let sizeMB = sizeBytes / (1024 * 1024)
            return String(format: "%.1f MB", sizeMB)
        }
        return sizeString
    }

    private func randomPercentage() -> Double {
        return Double.random(in: 0.1...1.0)
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    var buttonTitle: String {
        if let fp = app.formattedPrice {
            let lower = fp.lowercased()
            if lower.contains("free") || fp == "免费" || app.price == 0 {
                return "获取"
            }
            return fp
        }
        return "获取"
    }
}


// 搜索视图
struct SearchView: SwiftUI.View {
    
    @AppStorage("searchKey") var searchKey = ""
    @AppStorage("searchHistory") var searchHistoryData = Data()
    @FocusState var searchKeyFocused
    @State var searchType = DeviceFamily.phone
    @EnvironmentObject var themeManager: ThemeManager
    
    private var searchBarBackgroundColor: Color {
        switch themeManager.selectedTheme {
        case .light:
            return Color.gray.opacity(0.1)
        case .dark:
            return Color(.systemGray6)
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark ? Color(.systemGray6) : Color.gray.opacity(0.1)
        }
    }
    @EnvironmentObject var appStore: AppStore  // 添加AppStore环境对象
    @StateObject private var regionValidator = RegionValidator.shared
    @StateObject private var sessionManager = SessionManager.shared
    @State var searching = false
        
    // 智能地区检测 - 移除硬编码的US
    @State var searchRegion: String = ""
    @State var showRegionPicker = false
    
    // 添加用户手动选择标志
    @State var isUserSelectedRegion: Bool = false
    
    // UI刷新触发器
    @State var uiRefreshTrigger = UUID()
    
    // 登录相关状态
    @State var showLoginSheet = false
    @State var showAccountMenu = false
    
    // 下载状态管理
    @State var isDownloading = false
    
    // 视图模式枚举

    
    // 智能地区选择器 - 计算属性
    var effectiveSearchRegion: String {
        // 优先级：用户手动选择 > 登录账户地区 > 默认地区
        if isUserSelectedRegion && !searchRegion.isEmpty {
            // 如果用户手动选择了地区，优先使用用户选择
            return searchRegion
        } else if let currentAccount = appStore.selectedAccount {
            // 直接返回登录账户地区
            return currentAccount.countryCode
        } else if !searchRegion.isEmpty {
            // 如果用户手动选择了地区，使用选择
            return searchRegion
        }
        // 默认返回美国地区
        return "US"
    }
    
    // iOS兼容的地区检测方法
    private func getRegionFromLanguageCode(_ languageCode: String) -> String {
        switch languageCode {
        case "zh":
            return "CN" // 中文 -> 中国
        case "ja":
            return "JP" // 日语 -> 日本
        case "ko":
            return "KR" // 韩语 -> 韩国
        case "de":
            return "DE" // 德语 -> 德国
        case "fr":
            return "FR" // 法语 -> 法国
        case "es":
            return "ES" // 西班牙语 -> 西班牙
        case "it":
            return "IT" // 意大利语 -> 意大利
        case "pt":
            return "BR" // 葡萄牙语 -> 巴西
        case "ru":
            return "RU" // 俄语 -> 俄罗斯
        case "ar":
            return "SA" // 阿拉伯语 -> 沙特阿拉伯
        case "hi":
            return "IN" // 印地语 -> 印度
        case "th":
            return "TH" // 泰语 -> 泰国
        case "vi":
            return "VN" // 越南语 -> 越南
        case "id":
            return "ID" // 印尼语 -> 印尼
        case "ms":
            return "MY" // 马来语 -> 马来西亚
        case "tr":
            return "TR" // 土耳其语 -> 土耳其
        case "pl":
            return "PL" // 波兰语 -> 波兰
        case "nl":
            return "NL" // 荷兰语 -> 荷兰
        case "sv":
            return "SE" // 瑞典语 -> 瑞典
        case "da":
            return "DK" // 丹麦语 -> 丹麦
        case "no":
            return "NO" // 挪威语 -> 挪威
        case "fi":
            return "FI" // 芬兰语 -> 芬兰
        case "cs":
            return "CZ" // 捷克语 -> 捷克
        case "hu":
            return "HU" // 匈牙利语 -> 匈牙利
        case "ro":
            return "RO" // 罗马尼亚语 -> 罗马尼亚
        case "bg":
            return "BG" // 保加利亚语 -> 保加利亚
        case "hr":
            return "HR" // 克罗地亚语 -> 克罗地亚
        case "sk":
            return "SK" // 斯洛伐克语 -> 斯洛伐克
        case "sl":
            return "SI" // 斯洛文尼亚语 -> 斯洛文尼亚
        case "et":
            return "EE" // 爱沙尼亚语 -> 爱沙尼亚
        case "lv":
            return "LV" // 拉脱维亚语 -> 拉脱维亚
        case "lt":
            return "LT" // 立陶宛语 -> 立陶宛
        case "el":
            return "GR" // 希腊语 -> 希腊
        case "he":
            return "IL" // 希伯来语 -> 以色列
        case "fa":
            return "IR" // 波斯语 -> 伊朗
        case "ur":
            return "PK" // 乌尔都语 -> 巴基斯坦
        case "bn":
            return "BD" // 孟加拉语 -> 孟加拉国
        case "si":
            return "LK" // 僧伽罗语 -> 斯里兰卡
        case "my":
            return "MM" // 缅甸语 -> 缅甸
        case "km":
            return "KH" // 高棉语 -> 柬埔寨
        case "lo":
            return "LA" // 老挝语 -> 老挝
        case "ne":
            return "NP" // 尼泊尔语 -> 尼泊尔
        case "ka":
            return "GE" // 格鲁吉亚语 -> 格鲁吉亚
        case "hy":
            return "AM" // 亚美尼亚语 -> 亚美尼亚
        case "az":
            return "AZ" // 阿塞拜疆语 -> 阿塞拜疆
        case "kk":
            return "KZ" // 哈萨克语 -> 哈萨克斯坦
        case "ky":
            return "KG" // 吉尔吉斯语 -> 吉尔吉斯斯坦
        case "uz":
            return "UZ" // 乌兹别克语 -> 乌兹别克斯坦
        case "tg":
            return "TJ" // 塔吉克语 -> 塔吉克斯坦
        case "mn":
            return "MN" // 蒙古语 -> 蒙古
        case "bo":
            return "CN" // 藏语 -> 中国
        case "ug":
            return "CN" // 维吾尔语 -> 中国
        case "en":
            return "US" // 英语 -> 美国
        default:
            return "US" // 默认美区
        }
    }
    
    // 当前地区显示名称 - 使用简体中文
    var currentRegionDisplayName: String {
        let regionCode = effectiveSearchRegion
        return SearchView.countryCodeMapChinese[regionCode] ?? SearchView.countryCodeMap[regionCode] ?? regionCode
    }
    
    // 当前地区详细信息
    var currentRegionInfo: String {
        let regionCode = effectiveSearchRegion
        let chineseName = SearchView.countryCodeMapChinese[regionCode] ?? ""
        let englishName = SearchView.countryCodeMap[regionCode] ?? ""
        
        if !chineseName.isEmpty && !englishName.isEmpty {
            return "\(chineseName) (\(englishName))"
        } else if !chineseName.isEmpty {
            return chineseName
        } else if !englishName.isEmpty {
            return englishName
        } else {
            return regionCode
        }
    }
    
    // 当前地区国旗
    var currentRegionFlag: String {
        flag(country: effectiveSearchRegion)
    }
    
    // 获取地区选择器的地区列表 - 优先显示登录账户地区
    var sortedRegionKeys: [String] {
        var regions = Array(SearchView.storeFrontCodeMap.keys)
        
        // 如果有登录账户，将其地区放在第一位
        if let currentAccount = appStore.selectedAccount {
            let accountRegion = currentAccount.countryCode
            if let index = regions.firstIndex(of: accountRegion) {
                regions.remove(at: index)
                regions.insert(accountRegion, at: 0)
            }
        }
        
        // 将常用地区放在前面 - 包含香港、澳门、台湾等中文地区
        let commonRegions = ["US", "CN", "HK", "MO", "TW", "JP", "KR", "GB", "DE", "FR", "CA", "AU", "IT", "ES", "NL", "SE", "NO", "DK", "FI", "RU", "BR", "MX", "IN", "SG", "TH", "VN", "MY", "ID", "PH"]
        
        for commonRegion in commonRegions.reversed() {
            if let index = regions.firstIndex(of: commonRegion) {
                regions.remove(at: index)
                regions.insert(commonRegion, at: 0)
            }
        }
        
        return regions
    }
    
    // Static country code to name mapping (English)
    static let countryCodeMap: [String: String] = [
        "AE": "United Arab Emirates", "AG": "Antigua and Barbuda", "AI": "Anguilla", "AL": "Albania", "AM": "Armenia",
        "AO": "Angola", "AR": "Argentina", "AT": "Austria", "AU": "Australia", "AZ": "Azerbaijan",
        "BB": "Barbados", "BD": "Bangladesh", "BE": "Belgium", "BG": "Bulgaria", "BH": "Bahrain",
        "BM": "Bermuda", "BN": "Brunei", "BO": "Bolivia", "BR": "Brazil", "BS": "Bahamas",
        "BW": "Botswana", "BY": "Belarus", "BZ": "Belize", "CA": "Canada", "CH": "Switzerland",
        "CI": "Côte d'Ivoire", "CL": "Chile", "CN": "China", "CO": "Colombia", "CR": "Costa Rica",
        "CY": "Cyprus", "CZ": "Czech Republic", "DE": "Germany", "DK": "Denmark", "DM": "Dominica",
        "DO": "Dominican Republic", "DZ": "Algeria", "EC": "Ecuador", "EE": "Estonia", "EG": "Egypt",
        "ES": "Spain", "FI": "Finland", "FR": "France", "GB": "United Kingdom", "GD": "Grenada",
        "GE": "Georgia", "GH": "Ghana", "GR": "Greece", "GT": "Guatemala", "GY": "Guyana",
        "HK": "Hong Kong", "HN": "Honduras", "HR": "Croatia", "HU": "Hungary", "ID": "Indonesia",
        "IE": "Ireland", "IL": "Israel", "IN": "India", "IS": "Iceland", "IT": "Italy",
        "JM": "Jamaica", "JO": "Jordan", "JP": "Japan", "KE": "Kenya", "KN": "Saint Kitts and Nevis",
        "KR": "South Korea", "KW": "Kuwait", "KY": "Cayman Islands", "KZ": "Kazakhstan", "LB": "Lebanon",
        "LC": "Saint Lucia", "LI": "Liechtenstein", "LK": "Sri Lanka", "LT": "Lithuania", "LU": "Luxembourg",
        "LV": "Latvia", "MD": "Moldova", "MG": "Madagascar", "MK": "North Macedonia", "ML": "Mali",
        "MN": "Mongolia", "MO": "Macao", "MS": "Montserrat", "MT": "Malta", "MU": "Mauritius",
        "MV": "Maldives", "MX": "Mexico", "MY": "Malaysia", "NE": "Niger", "NG": "Nigeria",
        "NI": "Nicaragua", "NL": "Netherlands", "NO": "Norway", "NP": "Nepal", "NZ": "New Zealand",
        "OM": "Oman", "PA": "Panama", "PE": "Peru", "PH": "Philippines", "PK": "Pakistan",
        "PL": "Poland", "PT": "Portugal", "PY": "Paraguay", "QA": "Qatar", "RO": "Romania",
        "RS": "Serbia", "RU": "Russia", "SA": "Saudi Arabia", "SE": "Sweden", "SG": "Singapore",
        "SI": "Slovenia", "SK": "Slovakia", "SN": "Senegal", "SR": "Suriname", "SV": "El Salvador",
        "TC": "Turks and Caicos", "TH": "Thailand", "TN": "Tunisia", "TR": "Turkey", "TT": "Trinidad and Tobago",
        "TW": "Taiwan", "TZ": "Tanzania", "UA": "Ukraine", "UG": "Uganda", "US": "United States",
        "UY": "Uruguay", "UZ": "Uzbekistan", "VC": "Saint Vincent and the Grenadines", "VE": "Venezuela",
        "VG": "British Virgin Islands", "VN": "Vietnam", "YE": "Yemen", "ZA": "South Africa"
    ]
    
    // Static country code to name mapping (简体中文)
    static let countryCodeMapChinese: [String: String] = [
        "AE": "阿联酋", "AG": "安提瓜和巴布达", "AI": "安圭拉", "AL": "阿尔巴尼亚", "AM": "亚美尼亚",
        "AO": "安哥拉", "AR": "阿根廷", "AT": "奥地利", "AU": "澳大利亚", "AZ": "阿塞拜疆",
        "BB": "巴巴多斯", "BD": "孟加拉国", "BE": "比利时", "BG": "保加利亚", "BH": "巴林",
        "BM": "百慕大", "BN": "文莱", "BO": "玻利维亚", "BR": "巴西", "BS": "巴哈马",
        "BW": "博茨瓦纳", "BY": "白俄罗斯", "BZ": "伯利兹", "CA": "加拿大", "CH": "瑞士",
        "CI": "科特迪瓦", "CL": "智利", "CN": "中国", "CO": "哥伦比亚", "CR": "哥斯达黎加",
        "CY": "塞浦路斯", "CZ": "捷克", "DE": "德国", "DK": "丹麦", "DM": "多米尼克",
        "DO": "多米尼加", "DZ": "阿尔及利亚", "EC": "厄瓜多尔", "EE": "爱沙尼亚", "EG": "埃及",
        "ES": "西班牙", "FI": "芬兰", "FR": "法国", "GB": "英国", "GD": "格林纳达",
        "GE": "格鲁吉亚", "GH": "加纳", "GR": "希腊", "GT": "危地马拉", "GY": "圭亚那",
        "HK": "香港", "HN": "洪都拉斯", "HR": "克罗地亚", "HU": "匈牙利", "ID": "印度尼西亚",
        "IE": "爱尔兰", "IL": "以色列", "IN": "印度", "IS": "冰岛", "IT": "意大利",
        "JM": "牙买加", "JO": "约旦", "JP": "日本", "KE": "肯尼亚", "KN": "圣基茨和尼维斯",
        "KR": "韩国", "KW": "科威特", "KY": "开曼群岛", "KZ": "哈萨克斯坦", "LB": "黎巴嫩",
        "LC": "圣卢西亚", "LI": "列支敦士登", "LK": "斯里兰卡", "LT": "立陶宛", "LU": "卢森堡",
        "LV": "拉脱维亚", "MD": "摩尔多瓦", "MG": "马达加斯加", "MK": "北马其顿", "ML": "马里",
        "MN": "蒙古", "MO": "澳门", "MS": "蒙特塞拉特", "MT": "马耳他", "MU": "毛里求斯",
        "MV": "马尔代夫", "MX": "墨西哥", "MY": "马来西亚", "NE": "尼日尔", "NG": "尼日利亚",
        "NI": "尼加拉瓜", "NL": "荷兰", "NO": "挪威", "NP": "尼泊尔", "NZ": "新西兰",
        "OM": "阿曼", "PA": "巴拿马", "PE": "秘鲁", "PH": "菲律宾", "PK": "巴基斯坦",
        "PL": "波兰", "PT": "葡萄牙", "PY": "巴拉圭", "QA": "卡塔尔", "RO": "罗马尼亚",
        "RS": "塞尔维亚", "RU": "俄罗斯", "SA": "沙特阿拉伯", "SE": "瑞典", "SG": "新加坡",
        "SI": "斯洛文尼亚", "SK": "斯洛伐克", "SN": "塞内加尔", "SR": "苏里南", "SV": "萨尔瓦多",
        "TC": "特克斯和凯科斯群岛", "TH": "泰国", "TN": "突尼斯", "TR": "土耳其", "TT": "特立尼达和多巴哥",
        "TW": "台湾", "TZ": "坦桑尼亚", "UA": "乌克兰", "UG": "乌干达", "US": "美国",
        "UY": "乌拉圭", "UZ": "乌兹别克斯坦", "VC": "圣文森特和格林纳丁斯", "VE": "委内瑞拉",
        "VG": "英属维尔京群岛", "VN": "越南", "YE": "也门", "ZA": "南非"
    ]
    
    static let storeFrontCodeMap = [
        "AE": "143481", "AG": "143540", "AI": "143538", "AL": "143575", "AM": "143524",
        "AO": "143564", "AR": "143505", "AT": "143445", "AU": "143460", "AZ": "143568",
        "BB": "143541", "BD": "143490", "BE": "143446", "BG": "143526", "BH": "143559",
        "BM": "143542", "BN": "143560", "BO": "143556", "BR": "143503", "BS": "143539",
        "BW": "143525", "BY": "143565", "BZ": "143555", "CA": "143455", "CH": "143459",
        "CI": "143527", "CL": "143483", "CN": "143465", "CO": "143501", "CR": "143495",
        "CY": "143557", "CZ": "143489", "DE": "143443", "DK": "143458", "DM": "143545",
        "DO": "143508", "DZ": "143563", "EC": "143509", "EE": "143518", "EG": "143516",
        "ES": "143454", "FI": "143447", "FR": "143442", "GB": "143444", "GD": "143546",
        "GE": "143615", "GH": "143573", "GR": "143448", "GT": "143504", "GY": "143553",
        "HK": "143463", "HN": "143510", "HR": "143494", "HU": "143482", "ID": "143476",
        "IE": "143449", "IL": "143491", "IN": "143467", "IS": "143558", "IT": "143450",
        "JM": "143511", "JO": "143528", "JP": "143462", "KE": "143529", "KN": "143548",
        "KR": "143466", "KW": "143493", "KY": "143544", "KZ": "143517", "LB": "143497",
        "LC": "143549", "LI": "143522", "LK": "143486", "LT": "143520", "LU": "143451",
        "LV": "143519", "MD": "143523", "MG": "143531", "MK": "143530", "ML": "143532",
        "MN": "143592", "MO": "143515", "MS": "143547", "MT": "143521", "MU": "143533",
        "MV": "143488", "MX": "143468", "MY": "143473", "NE": "143534", "NG": "143561",
        "NI": "143512", "NL": "143452", "NO": "143457", "NP": "143484", "NZ": "143461",
        "OM": "143562", "PA": "143485", "PE": "143507", "PH": "143474", "PK": "143477",
        "PL": "143478", "PT": "143453", "PY": "143513", "QA": "143498", "RO": "143487",
        "RS": "143500", "RU": "143469", "SA": "143479", "SE": "143456", "SG": "143464",
        "SI": "143499", "SK": "143496", "SN": "143535", "SR": "143554", "SV": "143506",
        "TC": "143552", "TH": "143475", "TN": "143536", "TR": "143480", "TT": "143551",
        "TW": "143470", "TZ": "143572", "UA": "143492", "UG": "143537", "US": "143441",
        "UY": "143514", "UZ": "143566", "VC": "143550", "VE": "143502", "VG": "143543",
        "VN": "143471", "YE": "143571", "ZA": "143472"
    ]
    
    // 使用排序后的地区列表
    var regionKeys: [String] { sortedRegionKeys }
    
    // 根据搜索输入过滤地区列表
    var filteredRegionKeys: [String] {
        if searchInput.isEmpty {
            return regionKeys
        } else {
            return regionKeys.filter { regionCode in
                let chineseName = SearchView.countryCodeMapChinese[regionCode] ?? ""
                let englishName = SearchView.countryCodeMap[regionCode] ?? ""
                let searchText = searchInput.lowercased()
                
                return regionCode.lowercased().contains(searchText) ||
                       chineseName.lowercased().contains(searchText) ||
                       englishName.lowercased().contains(searchText)
            }
        }
    }
    
    @State var searchInput: String = ""
    @State var searchResult: [iTunesSearchResult] = []
    @State private var currentPage = 1
    @State private var isLoadingMore = false
    private let pageSize = 20
    @State var searchHistory: [String] = []
    @State var showSearchHistory = false
    @State var isHovered = false
    @State var searchError: String? = nil
    @State var searchSuggestions: [String] = []
    @State var isFetchingSuggestions: Bool = false
    @State var searchCache: [String: [iTunesSearchResult]] = [:]
    @State var showSearchSuggestions = false
    @StateObject var vm = AppStore.this
    @State private var animateHeader = false
    @State private var animateCards = false
    @State private var animateSearchBar = false
    @State private var animateResults = false
    

    // 版本选择相关状态
    @State var showVersionPicker = false
    @State var selectedApp: iTunesSearchResult?
    @State var availableVersions: [StoreAppVersion] = []
    @State var versionHistory: [iTunesClient.AppVersionInfo] = []
    // 正在执行“获取”的条目 trackId（避免一次点击影响所有条目按钮）
    @State private var purchasingTrackId: Int? = nil
    @State private var showPurchaseAlert: Bool = false
    @State private var purchaseAlertText: String = ""
    @State var isLoadingVersions = false
    @State var versionError: String?
    var possibleReigon: Set<String> {
        vm.selectedAccount != nil ? Set([vm.selectedAccount!.countryCode]) : Set()
    }
    var body: some SwiftUI.View {
        NavigationView {
            ZStack {
                // 统一背景色 - 与其他界面保持一致
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // 全屏显示，减少顶部空白
                VStack(spacing: 0) {
                    
                    // 主要内容区域
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                // 搜索头部区域
                                modernSearchBar
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateHeader)
                                    .id("searchBar")
                                
                                // 分类选择器
                                categorySelector
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateHeader)
                                
                                // 搜索结果区域
                                searchResultsSection
                                    .scaleEffect(animateResults ? 1 : 0.95)
                                    .opacity(animateResults ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateResults)
                            }
                        }
                        .refreshable {
                            if !searchKey.isEmpty {
                                await performSearch()
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadSearchHistory()
            print("[SearchView] 视图加载完成，开始初始化")
            
            // 启动Apple ID会话监控
            sessionManager.startSessionMonitoring()
            
            // 智能地区检测 - 确保在UI加载后执行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("[SearchView] 执行智能地区检测")
                detectAndSetRegion()
                
                // 打印最终状态
                print("[SearchView] 初始化完成 - 最终状态:")
                print("  - searchRegion: \(searchRegion)")
                print("  - effectiveSearchRegion: \(effectiveSearchRegion)")
                if let account = appStore.selectedAccount {
                    print("  - 登录账户: \(account.email), 地区: \(account.countryCode)")
                } else {
                    print("  - 未登录账户")
                }
                
                // 触发UI刷新
                self.uiRefreshTrigger = UUID()
            }
            
            // 强制刷新UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[SearchView] 强制刷新UI")
                startAnimations()
            }
        }
        .onDisappear {
            // 停止会话监控以节省资源
            sessionManager.stopSessionMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshUI"))) { _ in
            // 接收强制刷新通知 - 真机适配
            print("[SearchView] 接收到强制刷新通知")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[SearchView] 真机适配强制刷新完成")
                startAnimations()
            }
        }
        .onReceive(appStore.$selectedAccount) { account in
            // 监听账户变化，自动更新搜索地区
            if let newAccount = account {
                print("[SearchView] 检测到账户变化: \(newAccount.email), 地区: \(newAccount.countryCode)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detectAndSetRegion()
                    // 强制刷新UI - 使用状态变量触发刷新
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        self.uiRefreshTrigger = UUID()
                    }
                }
            } else {
                print("[SearchView] 账户已登出，重置为默认地区")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detectAndSetRegion()
                }
            }
        }
        .sheet(isPresented: $showVersionPicker) {
            versionPickerSheet
        }
        // 移除查看隐私/评论的弹窗
        .sheet(isPresented: $showRegionPicker) {
            regionPickerSheet
        }
        .sheet(isPresented: $showLoginSheet) {
            AddAccountView()
                .environmentObject(appStore)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showAccountMenu) {
            accountMenuSheet
        }
    }
    
    // 智能地区检测
    private func detectAndSetRegion() {
        // 优先使用账户地区（如果有登录）
        if let currentAccount = appStore.selectedAccount {
            let accountRegion = currentAccount.countryCode
            print("[SearchView] 检测到登录账户: \(currentAccount.email), 地区代码: \(accountRegion)")
            
            // 确保账户地区被正确设置，不依赖其他计算属性
            if searchRegion != accountRegion && !isUserSelectedRegion {
                searchRegion = accountRegion
                print("[SearchView] 已将搜索地区更新为账户地区: \(searchRegion)")
            }
        } else {
            // 如果没有登录账户，使用系统语言检测或默认地区
            let detectedRegion = effectiveSearchRegion
            if searchRegion != detectedRegion && !isUserSelectedRegion {
                searchRegion = detectedRegion
                print("[SearchView] 未检测到登录账户，使用默认地区: \(searchRegion)")
            }
        }
        
        print("[SearchView] 当前显示地区: \(effectiveSearchRegion), 用户手动选择标志: \(isUserSelectedRegion)")
        
        // 延迟验证和UI更新，避免在视图更新过程中触发状态变化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 异步验证地区设置
            Task { @MainActor in
                let validationResult = regionValidator.validateRegionSettings(
                    account: appStore.selectedAccount,
                    searchRegion: searchRegion,
                    effectiveRegion: effectiveSearchRegion
                )
                
                if !validationResult.isValid {
                    print("⚠️ [SearchView] 地区验证失败: \(validationResult.errorMessage ?? "未知错误")")
                    let advice = regionValidator.getRegionValidationAdvice(for: validationResult)
                    for tip in advice {
                        print("💡 [SearchView] 建议: \(tip)")
                    }
                }
            }
            
            // 更新UI刷新触发器
            self.uiRefreshTrigger = UUID()
        }
    }
    
    // 现代化搜索栏
    var modernSearchBar: some SwiftUI.View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                // 搜索输入框
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("游戏、App、故事等", text: $searchKey)
                        .font(.body)
                        .focused($searchKeyFocused)
                        .onChange(of: searchKey) { newValue in
                            if !newValue.isEmpty {
                                showSearchSuggestions = true
                                // 本地建议
                                searchSuggestions = getSearchSuggestions(for: newValue)
                                // 远程联想建议
                                Task { await fetchRemoteSuggestions(for: newValue) }
                            } else {
                                showSearchSuggestions = false
                                searchSuggestions = []
                            }
                        }
                        .onSubmit {
                            showSearchSuggestions = false
                            Task {
                                await performSearch()
                            }
                        }
                    if !searchKey.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchKey = ""
                                searchResult = []
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect()
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            searchKeyFocused ? .blue : Color.clear,
                            lineWidth: 2
                        )
                )

            }
            .padding(.top, 8)
            // 搜索类型、账户与地区同一行
            HStack(spacing: 16) {
                // 搜索类型选择器
                Menu {
                    ForEach(DeviceFamily.allCases, id: \.self) { type in
                        Button {
                            searchType = type
                        } label: {
                            HStack {
                                Image(systemName: "iphone")
                                Text(type.displayName)
                                if searchType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.system(size: 14, weight: .medium))
                        Text(searchType.displayName)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(themeManager.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(themeManager.accentColor.opacity(0.1))
                    )
                }
                
                Spacer(minLength: 12)
                // 账户胶囊（紧凑）
                compactAccountCapsule
                // 智能地区选择器
                smartRegionSelector
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }
    
    // 智能地区选择器
    var smartRegionSelector: some SwiftUI.View {
        Button(action: {
            showRegionPicker = true
        }) {
            HStack(spacing: 8) {
                Text(flag(country: effectiveSearchRegion))
                    .font(.title2)
                Text(SearchView.countryCodeMapChinese[effectiveSearchRegion] ?? SearchView.countryCodeMap[effectiveSearchRegion] ?? effectiveSearchRegion)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                // 显示地区来源指示器
                if let currentAccount = appStore.selectedAccount {
                    // 使用简单的布尔判断，避免在视图更新中调用验证方法
                    let isRegionValid = (effectiveSearchRegion == currentAccount.countryCode)
                    
                    // 移除头像图标，保留帮助文本
                    Text(isRegionValid ? "已验证" : "地区不匹配")
                        .font(.caption2)
                        .foregroundColor(isRegionValid ? .green : .red)
                        .help(isRegionValid ? "来自登录账户: \(currentAccount.email)" : "地区不匹配: 账户(\(currentAccount.countryCode)) vs 设置(\(effectiveSearchRegion))")
                } else if !searchRegion.isEmpty {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .help("用户手动选择")
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                        .help("默认美区")
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                    .overlay(
                        Capsule()
                            .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .id("RegionSelector-\(effectiveSearchRegion)-\(uiRefreshTrigger)") // 强制刷新
        .onAppear {
            // 确保地区选择器显示正确的当前地区
            print("[SearchView] 地区选择器显示，当前地区: \(effectiveSearchRegion)")
        }
    }
    // 紧凑版账户胶囊（显示邮箱与登录/登出入口）
    private var compactAccountCapsule: some SwiftUI.View {
        HStack(spacing: 8) {
            // Apple ID缓存状态指示器
            HStack(spacing: 4) {
                // 移除头像图标
                Text(appStore.selectedAccount == nil ? "未登录" : "已登录")
                    .font(.caption)
                    .foregroundColor(appStore.selectedAccount == nil ? .secondary : themeManager.accentColor)
                
                // 缓存状态指示器
                if appStore.selectedAccount != nil {
                    cacheStatusIndicator
                }
            }
            
            if let acc = appStore.selectedAccount {
                // 显示当前账户信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(acc.email)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // 显示账户数量指示器
                    if appStore.hasMultipleAccounts {
                        Text("\(appStore.savedAccounts.count) 个账户")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("未登录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Menu {
                if appStore.selectedAccount == nil {
                    Button("登录") { showLoginSheet = true }
                } else {
                    // 多账户切换菜单
                    if appStore.hasMultipleAccounts {
                        ForEach(appStore.savedAccounts.indices, id: \.self) { index in
                            let account = appStore.savedAccounts[index]
                            Button(action: {
                                appStore.switchToAccount(at: index)
                            }) {
                                HStack {
                                    Text(account.email)
                                    if index == appStore.selectedAccountIndex {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                    }
                    
                    Button("账户详情") { showAccountMenu = true }
                    Button("新增：添加账户") { showLoginSheet = true }
                    Button("新增：刷新一下，解决地区识别问题") { refreshRegionSettings() }
                    
                    // 缓存管理功能
                    if appStore.selectedAccount != nil {
                        Divider()
                        if !sessionManager.isSessionValid {
                            Button("🔧 修复连接问题") { 
                                Task { await sessionManager.manualSessionCheck() } 
                            }
                        }
                        if sessionManager.isReconnecting {
                            Button("⏹️ 停止重连") { 
                                sessionManager.resetSessionState()
                            }
                        }
                    }
                    
                    Button("登出", role: .destructive) { logoutAccount() }
                }
            } label: {
                HStack {
                    Image(systemName: "person.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
        )
    }
    
    // 地区选择器弹窗
    var regionPickerSheet: some SwiftUI.View {
        NavigationView {
            VStack(spacing: 0) {
                // 当前地区信息
                VStack(spacing: 16) {
                    Text("当前搜索地区")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                                        HStack(spacing: 16) {
                        Text(flag(country: searchRegion.isEmpty ? effectiveSearchRegion : searchRegion))
                            .font(.system(size: 48))
                        VStack(alignment: .leading, spacing: 8) {
                            let displayRegion = searchRegion.isEmpty ? effectiveSearchRegion : searchRegion
                            Text(SearchView.countryCodeMapChinese[displayRegion] ?? SearchView.countryCodeMap[displayRegion] ?? displayRegion)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(currentRegionInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("地区代码: \(displayRegion)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // 显示地区来源
                            if isUserSelectedRegion && !searchRegion.isEmpty {
                                Text("用户手动选择")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else if let currentAccount = appStore.selectedAccount {
                                Text("来自登录账户: \(currentAccount.email)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("默认美区")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                    )
                }
                .padding()
                
                // 地区统计信息
                HStack {
                    Text("共 \(regionKeys.count) 个地区")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let currentAccount = appStore.selectedAccount {
                        Text("登录账户: \(currentAccount.countryCode)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // 地区搜索框 - 统一大小和样式
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("搜索地区...", text: $searchInput)
                        .font(.title3)
                        .onChange(of: searchInput) { newValue in
                            // 实时搜索地区
                            if newValue.isEmpty {
                                // 如果搜索框为空，显示所有地区
                                // 可以在这里添加过滤逻辑
                            }
                        }
                    if !searchInput.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchInput = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.selectedTheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                        .shadow(color: themeManager.selectedTheme == .dark ? .black.opacity(0.3) : .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            .clear,
                            lineWidth: 2
                        )
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // 地区选择列表
                List {
                    ForEach(filteredRegionKeys, id: \.self) { regionCode in
                        Button(action: {
                            selectRegion(regionCode)
                        }) {
                            HStack(spacing: 16) {
                                Text(flag(country: regionCode))
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(SearchView.countryCodeMapChinese[regionCode] ?? SearchView.countryCodeMap[regionCode] ?? regionCode)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                    Text(regionCode)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if regionCode == searchRegion {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.accentColor)
                                        .font(.system(size: 16, weight: .bold))
                                }
                                
                                // 显示地区来源标识
                                if isUserSelectedRegion && regionCode == searchRegion {
                                    Image(systemName: "hand.point.up.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                        .help("用户手动选择")
                                } else if let currentAccount = appStore.selectedAccount, regionCode == currentAccount.countryCode {
                                    // 登录账户地区标识已移除
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("选择搜索地区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("返回") {
                        showRegionPicker = false
                    }
                }
            }
        }
    }
    
    // 账户状态栏
    var accountStatusBar: some SwiftUI.View {
        VStack(spacing: 0) {
            if let currentAccount = appStore.selectedAccount {
                // 已登录状态
                HStack(spacing: 16) {
                    // 账户头像
                    Button(action: {
                        showAccountMenu = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentAccount.email)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    Text(flag(country: currentAccount.countryCode))
                                        .font(.caption)
                                    Text(SearchView.countryCodeMapChinese[currentAccount.countryCode] ?? SearchView.countryCodeMap[currentAccount.countryCode] ?? currentAccount.countryCode)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // 登出按钮
                    Button(action: {
                        logoutAccount()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.caption)
                            Text("登出")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            } else {
                // 未登录状态
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未登录")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text("登录以获得更好的体验")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 登录按钮
                    Button(action: {
                        showLoginSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill.badge.plus")
                                .font(.caption)
                            Text("登录")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.selectedTheme == .dark ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
    
    // 地区选择处理
    private func selectRegion(_ regionCode: String) {
        searchRegion = regionCode
        isUserSelectedRegion = true // 设置用户手动选择标志
        print("[SearchView] 用户选择地区: \(regionCode)")
        
        // 强制更新UI - 使用状态变量触发刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.uiRefreshTrigger = UUID()
        }
        
        // 如果当前有搜索结果，清空并重新搜索
        if !searchResult.isEmpty {
            searchResult = []
            Task {
                await performSearch()
            }
        }
        
        showRegionPicker = false
        
        // 打印调试信息
        print("[SearchView] 地区选择完成，当前搜索地区: \(searchRegion)")
        print("[SearchView] 用户手动选择标志: \(isUserSelectedRegion)")
        print("[SearchView] effectiveSearchRegion: \(effectiveSearchRegion)")
    }
    // 搜索历史区域
    var searchHistorySection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("最近搜索", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清除全部") {
                    withAnimation(.easeInOut) {
                        clearSearchHistory()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchHistory.prefix(8), id: \.self) { history in
                        Button {
                            searchKey = history
                            showSearchHistory = false
                            Task {
                                await performSearch()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                Text(history)
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        Capsule()
                                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 24)
    }
    // 搜索建议区域
    var searchSuggestionsSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("搜索建议")
                    .font(.title3)
                Spacer()
                Button("关闭") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearchSuggestions = false
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .foregroundColor(.blue)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searchSuggestions.prefix(8), id: \.self) { suggestion in
                        Button {
                            searchKey = suggestion
                            showSearchSuggestions = false
                            Task {
                                await performSearch()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                Text(suggestion)
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        Capsule()
                                            .stroke(.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 24)
    }
    // 分类选择器
    var categorySelector: some SwiftUI.View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    // 搜索结果区域
    var searchResultsSection: some SwiftUI.View {
        VStack(spacing: 16) {
            if !searchResult.isEmpty {
                // 当前账户指示器
                currentAccountIndicator
                
                // 结果统计和视图切换器
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("找到 \(searchResult.count) 个结果")
                            .font(.title2)
                            .foregroundColor(.primary)
                        if !searchInput.isEmpty {
                            Text("关于 \"\(searchInput)\"")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // 视图模式切换器
    
                }
                .padding(.horizontal, 16)
            }
            // 搜索结果网格/列表
            if let error = searchError {
                AnyView(searchErrorView(error: error))
            } else if searching {
                AnyView(searchingIndicator)
            } else if searchResult.isEmpty {
                AnyView(emptyStateView)
            } else {
                AnyView(searchResultsGrid)
            }
        }
    }
    // 搜索中指示器
    var searchingIndicator: some SwiftUI.View {
        VStack(spacing: 24) {
            // 动画加载指示器
            ZStack {
                Circle()
                    .stroke(.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .gray],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(searching ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: searching
                    )
            }
            VStack(spacing: 8) {
                Text("正在搜索...")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text("为您寻找最佳结果")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    // 空状态视图
    var emptyStateView: some SwiftUI.View {
        VStack(spacing: 24) {
            // 空状态图标
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .cornerRadius(24)
                .scaleEffect(animateCards ? 1.1 : 1)
                .opacity(animateCards ? 1 : 0.7)
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: animateCards
                )
            VStack(spacing: 8) {
                Text("APP降级")
                    .font(.title)
                    .foregroundColor(.primary)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            // 推荐搜索
            if !searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索历史")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(searchHistory.prefix(3), id: \.self) { history in
                            Button {
                                searchKey = history
                                Task {
                                    await performSearch()
                                }
                            } label: {
                                Text(history)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
    // 搜索错误视图
    func searchErrorView(error: String) -> any SwiftUI.View {
        VStack(spacing: 24) {
            // 错误图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.1), .red.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.red.opacity(0.8))
            }
            VStack(spacing: 8) {
                Text("搜索出现问题")
                    .font(.title)
                    .foregroundColor(.primary)
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            // 重试按钮
            Button {
                searchError = nil
                Task {
                    await performSearch()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("重试")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    // 搜索结果网格
    var searchResultsGrid: some SwiftUI.View {
        Group {
            // 只使用列表布局的EnhancedAppCard
            LazyVStack(spacing: 16) {
                ForEach(searchResult.indices, id: \.self) { index in
                    let item = searchResult[index]
                    AnyView(resultCardView(item: item, index: index))
                }
            }
            .padding(.horizontal, 24)
            .onAppear {
                print("[SearchView] 显示列表视图，结果数量: \(searchResult.count)")
            }
            // 加载更多指示器
            if isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载更多...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
            }
        }
    }
    // 结果卡片视图
    func resultCardView(item: iTunesSearchResult, index: Int) -> any SwiftUI.View {
        return EnhancedAppCard(app: item, onTap: { 
            // 处理app点击事件，显示详情页
            let appDetailView = EnhancedAppDetailView(app: item, onPrimaryAction: { appToDownload in
                // 处理获取/下载按钮点击事件
                handleDownloadApp(appToDownload)
            }, isDownloading: $isDownloading)
            .environmentObject(themeManager)
            
            // 以sheet形式显示详情页
            let hostingController = UIHostingController(rootView: appDetailView)
            UIApplication.shared.windows.first?.rootViewController?.present(hostingController, animated: true)
        }, isDownloading: $isDownloading)
        .environmentObject(themeManager)
    }

    // 辅助方法
    func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateHeader = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateResults = true
        }
    }
    func flag(country: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in country.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
    @MainActor
    func performSearch() async {
        guard !searchKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 使用智能检测的地区
        let regionToUse = effectiveSearchRegion
        print("[SearchView] 执行搜索，使用地区: \(regionToUse)")
        
        withAnimation(.easeInOut) {
            searching = true
            searchResult = []
            currentPage = 1
            searchError = nil
        }
        addToSearchHistory(searchKey)
        showSearchHistory = false
        let cacheKey = "\(searchKey)_\(searchType.rawValue)_\(regionToUse)"
        if let cachedResult = searchCache[cacheKey] {
            await MainActor.run {
                withAnimation(.spring()) {
                    searchResult = cachedResult
                    searching = false
                }
            }
            return
        }
        
        do {
            let response = try await iTunesClient.shared.search(
                term: searchKey,
                limit: pageSize,
                countryCode: regionToUse,
                deviceFamily: searchType
            )
            let results = response ?? []
            await MainActor.run {
                withAnimation(.spring()) {
                    searchResult = results
                    searching = false
                    searchCache[cacheKey] = results
                    updateSearchSuggestions(from: results)
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut) {
                    searching = false
                    searchError = error.localizedDescription
                }
            }
        }
    }
    func loadSearchHistory() {
        if let data = try? JSONDecoder().decode([String].self, from: searchHistoryData) {
            searchHistory = data
        }
    }
    func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            searchHistoryData = data
        }
    }
    func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        // 移除重复项
        searchHistory.removeAll { $0 == trimmedQuery }
        // 添加到开头
        searchHistory.insert(trimmedQuery, at: 0)
        // 限制历史记录数量
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        saveSearchHistory()
    }
    func removeFromHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
        showSearchHistory = false
    }
    func loadMoreResults() {
        guard !isLoadingMore && !searching && !searchKey.isEmpty else { return }
        isLoadingMore = true
        currentPage += 1
        Task {
            do {
                // 使用智能检测的地区
                let regionToUse = effectiveSearchRegion
                let response = try await iTunesClient.shared.search(
                    term: searchKey,
                    limit: pageSize,
                    countryCode: regionToUse,
                    deviceFamily: searchType
                )
                let results = response ?? []
                await MainActor.run {
                    // 只有当返回的结果不为空时才添加
                    if !results.isEmpty {
                        searchResult.append(contentsOf: results)
                    }
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    isLoadingMore = false
                    currentPage -= 1
                    searchError = error.localizedDescription
                }
            }
        }
    }
    func updateSearchSuggestions(from results: [iTunesSearchResult]) {
        var suggestions: Set<String> = []
        for result in results.prefix(10) {
            let appName = result.name
            if !appName.isEmpty {
                suggestions.insert(appName)
            }
            if let artistName = result.artistName, !artistName.isEmpty {
                suggestions.insert(artistName)
            }
        }
        searchSuggestions = Array(suggestions).sorted()
    }
    // 联想建议
    func fetchRemoteSuggestions(for query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if isFetchingSuggestions { return }
        isFetchingSuggestions = true
        defer { isFetchingSuggestions = false }
        let res = await SearchManager.shared.suggest(term: query)
        switch res {
        case .success(let terms):
            let remote = terms.map { $0.term }
            let combined = Array(Set((searchSuggestions + remote))).sorted()
            await MainActor.run { self.searchSuggestions = combined }
        case .failure:
            break
        }
    }
    func clearSearchCache() {
        searchCache.removeAll()
    }
    func getSearchSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        let lowercaseQuery = query.lowercased()
        let historySuggestions = searchHistory.filter { $0.lowercased().contains(lowercaseQuery) }
        let dynamicSuggestions = searchSuggestions.filter { $0.lowercased().contains(lowercaseQuery) }
        return Array(Set(historySuggestions + dynamicSuggestions)).prefix(5).map { $0 }
    }
    // 小组件
   private func starRow(rating: Double?, count: Int?) -> some SwiftUI.View {
        let r = max(0.0, min(rating ?? 0.0, 5.0))
        let full = Int(r)
        let half = (r - Double(full)) >= 0.5
        return HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                if i < full {
                    Image(systemName: "star.fill").foregroundColor(.orange)
                } else if i == full && half {
                    Image(systemName: "star.leadinghalf.filled").foregroundColor(.orange)
                } else {
                    Image(systemName: "star").foregroundColor(.orange.opacity(0.4))
                }
            }
            if let c = count { Text("(\(c))").font(.caption2).foregroundColor(.secondary) }
        }
    }
    func chip(_ text: String) -> some SwiftUI.View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
    }
    // 升级封面图：优先尝试将 512 链接替换为 1024；若无则回退到 512/100
    private func bestArtworkURL(from512: String?, fallback100: String?) -> String {
        if var url = from512, !url.isEmpty {
            // 常见规则：.../512x512bb.jpg → 1024x1024bb.jpg
            url = url.replacingOccurrences(of: "/512x512bb", with: "/1024x1024bb")
            return url
        }
        return from512 ?? fallback100 ?? ""
    }
    // 购买入口（仅对免费 App 用于获取许可）
    func purchaseButton(item: iTunesSearchResult) -> some SwiftUI.View {
        Group {
            if (item.price ?? 0.0) == 0.0 { // 免费app才显示“购买”
                Button {
                    Task { await purchaseFreeAppIfNeeded(item: item) }
                } label: {
                    HStack(spacing: 6) {
                        let loading = (purchasingTrackId == (item.trackId))
                        if loading { ProgressView().scaleEffect(0.7) }
                        Text(loading ? "购买中" : "购买")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(themeManager.accentColor))
                    .foregroundColor(.white)
                }
                .disabled(purchasingTrackId != nil && purchasingTrackId != item.trackId)
                .buttonStyle(.plain)
                .alert("提示", isPresented: $showPurchaseAlert) {
                    Button("好的", role: .cancel) {}
                } message: {
                    Text(purchaseAlertText)
                }
            }
        }
    }
    // 调用购买流程为账户绑定许可
    func purchaseFreeAppIfNeeded(item: iTunesSearchResult) async {
        guard let account = appStore.selectedAccount else {
            purchaseAlertText = "请先登录账号再获取app"
            showPurchaseAlert = true
            return
        }
        let currentId = item.trackId
        await MainActor.run { purchasingTrackId = currentId }
        defer { Task { await MainActor.run { purchasingTrackId = nil } } }
        // 使用 PurchaseManager 先检查拥有
        let check = await PurchaseManager.shared.checkAppOwnership(
            appIdentifier: String(item.trackId),
            account: account,
            countryCode: account.countryCode
        )
        switch check {
        case .success(let owned):
            if owned {
                // 已拥有：直接进入历史版本选择界面
                await MainActor.run {
                    loadVersionsForApp(item)
                }
                return
            } else {
                // 未拥有：直接跳转 App Store
                openAppStorePage(for: item)
                return
            }
        case .failure:
            // 检查失败：直接跳转 App Store，无提示
            openAppStorePage(for: item)
            return
        }
    }
    /// 打开官方 App Store 的该app页面
    private func openAppStorePage(for item: iTunesSearchResult) {
        let urlStr = item.trackViewUrl
        guard let url = URL(string: urlStr) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
    // Version Selection Methods
    func loadVersionsForApp(_ app: iTunesSearchResult) {
        // 首先同步设置selectedApp，确保UI立即更新
        selectedApp = app
        // 然后在Task中异步加载版本信息和更新其他状态
        Task {
            await MainActor.run {
                isLoadingVersions = true
                versionError = nil
                availableVersions = []
                // 显示版本选择器
                showVersionPicker = true
            }
            do {
                print("[SearchView] 开始加载app版本: \(app.trackName)")
                // 获取已保存的账户信息
                guard let account = appStore.selectedAccount else {
                    throw NSError(domain: "SearchView", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录账户，无法获取版本信息"])
                }
                // 并行：StoreClient 版本ID集合 + iTunes 版本历史详情
                let accountCopy = account
                let storeVersionsResult = await StoreClient.shared.getAppVersions(
                    trackId: String(app.trackId),
                    account: accountCopy,
                    countryCode: effectiveSearchRegion
                )
                let hist = try await iTunesClient.shared.versionHistory(id: app.trackId, country: effectiveSearchRegion)
                switch storeVersionsResult {
                case .success(let versions):
                    await MainActor.run {
                        self.availableVersions = versions
                        self.versionHistory = hist
                        self.isLoadingVersions = false
                        print("[SearchView] 成功加载 \(versions.count) 个版本, 历史记录 \(hist.count) 条")
                    }
                case .failure(let error):
                    throw error
                }
            } catch {
                await MainActor.run {
                    self.versionError = error.localizedDescription
                    self.isLoadingVersions = false
                    print("[SearchView] 加载版本失败: \(error)")
                }
            }
        }
    }
    // 现代化版本选择器视图
    var versionPickerSheet: some SwiftUI.View {
        NavigationView {
            ZStack {
                // 现代化背景渐变
                LinearGradient(
                    colors: themeManager.selectedTheme == .dark ? 
                        [Color(.systemBackground), Color(.secondarySystemBackground)] :
                        [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // 版本列表区域 - 直接显示，移除app头部
                VStack {
                    // 当前账户指示器
                    versionPickerAccountIndicator
                    
                    if isLoadingVersions {
                        loadingVersionsView
                    } else if let error = versionError {
                        AnyView(errorView(error: error))
                    } else if availableVersions.isEmpty {
                        emptyVersionsView
                    } else {
                        versionsListView
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeManager.selectedTheme == .dark ? 
                              Color(.secondarySystemBackground).opacity(0.5) : 
                              Color.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("返回") {
                        showVersionPicker = false
                    }
                    .foregroundColor(themeManager.accentColor)
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
    }


    var loadingVersionsView: some SwiftUI.View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载历史版本...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    func errorView(error: String) -> some SwiftUI.View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("加载失败")
                .font(.title2)
                .fontWeight(.semibold)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                if let app = selectedApp {
                    loadVersionsForApp(app)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
   private var emptyVersionsView: some SwiftUI.View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无历史版本")
                .font(.title2)
                .fontWeight(.semibold)
            Text("该app暂时没有可用的历史版本")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var versionsListView: some SwiftUI.View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // app名称标题
                VStack(spacing: 8) {
                    Text(selectedApp?.trackName ?? "APP")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(selectedApp?.artistName ?? "Unknown Developer")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // 版本数量统计
                HStack {
                    Text("历史版本")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(availableVersions.count) 个版本")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // 版本列表
                ForEach(availableVersions, id: \.versionId) {
                    AnyView(createModernVersionRow(version: $0))
                }
            }
            .padding(.bottom, 24)
        }
    }
    private func createModernVersionRow(version: StoreAppVersion) -> any SwiftUI.View {
        HStack(spacing: 16) {
            // 版本信息区域
            VStack(alignment: .leading, spacing: 8) {
                // 版本号 + 发布日期（从 versionHistory 映射）
                HStack(spacing: 8) {
                    Text(displayVersionTitle(version: version))
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                
                // 发布说明（首行）
                if let note = shortReleaseNote(for: version) {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 版本ID
                HStack(spacing: 8) {
                    Image(systemName: "number.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("ID: \(version.versionId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 下载按钮
            Button(action: {
                Task {
                    if let app = selectedApp {
                        // 显示账户确认提示
                        if let account = appStore.selectedAccount {
                            print("[SearchView] 用户确认下载，使用账户: \(account.email) (\(account.countryCode))")
                        }
                        await downloadVersion(app: app, version: version)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                    Text("下载")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.selectedTheme == .dark ? 
                      Color(.secondarySystemBackground).opacity(0.3) : 
                      Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .padding(.horizontal, 24)
    }
    // 映射显示：版本标题（含日期）
    private func displayVersionTitle(version: StoreAppVersion) -> String {
        if let h = versionHistory.first(where: { $0.version == version.versionString }) {
            return "版本 \(h.version) · \(h.formattedDate)"
        }
        return "版本 \(version.versionString)"
    }
    
    // 映射显示：发布说明首段
    private func shortReleaseNote(for version: StoreAppVersion) -> String? {
        if let h = versionHistory.first(where: { $0.version == version.versionString }) {
            if let rn = h.releaseNotes, !rn.isEmpty {
                let firstLine = rn.split(separator: "\n").first.map(String.init) ?? rn
                return firstLine
            }
        }
        return nil
    }
    @MainActor
    func downloadVersion(app: iTunesSearchResult, version: StoreAppVersion) async {
        showVersionPicker = false
        guard let account = appStore.selectedAccount else {
            print("[SearchView] 错误：没有登录账户")
            return
        }
        let appId = app.trackId
        print("[SearchView] 开始下载app: \(app.trackName) 版本: \(version.versionString)")
        print("[SearchView] 使用账户: \(account.email) (\(account.countryCode))")
        // 使用UnifiedDownloadManager添加下载请求并开始下载
        let downloadId = UnifiedDownloadManager.shared.addDownload(
            bundleIdentifier: app.bundleId,
            name: app.trackName,
            version: version.versionString,
            identifier: appId,
            iconURL: app.artworkUrl512,
            versionId: version.versionId
        )
        print("[SearchView] 已将下载请求添加到下载管理器，ID: \(downloadId)")
        // 开始下载
        if let request = UnifiedDownloadManager.shared.downloadRequests.first(where: { $0.id == downloadId }) {
            UnifiedDownloadManager.shared.startDownload(for: request)
        } else {
            print("[SearchView] 无法找到刚添加的下载请求")
        }
    }
    
    
    // 账户菜单弹窗
    var accountMenuSheet: some SwiftUI.View {
        NavigationView {
            if appStore.savedAccounts.isEmpty {
                // 未登录状态
                VStack(spacing: 24) {
                    Text("未登录")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("请先登录账户")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("登录账户") {
                        showAccountMenu = false
                        showLoginSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: themeManager.selectedTheme == .dark ? 
                            [Color(.systemBackground), Color(.secondarySystemBackground)] :
                            [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
                .navigationTitle("账户信息")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") {
                            showAccountMenu = false
                        }
                        .foregroundColor(themeManager.accentColor)
                        .font(.system(size: 16, weight: .medium))
                    }
                }
            } else {
                // 多账户管理界面
                multiAccountManagementView
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // 多账户管理界面
    var multiAccountManagementView: some SwiftUI.View {
        VStack(spacing: 0) {
            // 当前账户详情
            if let currentAccount = appStore.selectedAccount {
                VStack(spacing: 16) {
                    Text("当前账户")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AccountDetailView(account: currentAccount)
    
                        .environmentObject(appStore)
                }
                .padding()
            }
            
            // 所有账户列表
            VStack(spacing: 16) {
                HStack {
                    Text("所有账户")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(appStore.savedAccounts.count) 个账户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )
                }
                .padding(.horizontal)
                
                List {
                    ForEach(appStore.savedAccounts.indices, id: \.self) { index in
                        let account = appStore.savedAccounts[index]
                        let isSelected = index == appStore.selectedAccountIndex
                        
                        HStack(spacing: 12) {
                            // 账户信息
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.email)
                                    .font(.body)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    Text(flag(country: account.countryCode))
                                        .font(.caption)
                                    Text(SearchView.countryCodeMapChinese[account.countryCode] ?? SearchView.countryCodeMap[account.countryCode] ?? account.countryCode)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if isSelected {
                                        Text("当前")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(themeManager.accentColor)
                                            )
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 操作按钮
                            HStack(spacing: 8) {
                                if !isSelected {
                                    Button("切换") {
                                        appStore.switchToAccount(at: index)
                                    }
                                    .font(.caption)
                                    .foregroundColor(themeManager.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(themeManager.accentColor.opacity(0.1))
                                    )
                                }
                                
                                Button("删除") {
                                    appStore.deleteAccount(account)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.1))
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
            
            // 添加账户按钮
            VStack(spacing: 16) {
                Button("添加新账户") {
                    showAccountMenu = false
                    showLoginSheet = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: themeManager.selectedTheme == .dark ? 
                    [Color(.systemBackground), Color(.secondarySystemBackground)] :
                    [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("账户管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("关闭") {
                    showAccountMenu = false
                }
                .foregroundColor(themeManager.accentColor)
                .font(.system(size: 16, weight: .medium))
            }
        }
    }
    
    // 登录/登出功能
    private func logoutAccount() {
        print("[SearchView] 用户登出")
        appStore.logoutAccount()
        
        // 强制刷新UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.uiRefreshTrigger = UUID()
        }
    }
    
    // 地区刷新功能
    private func refreshRegionSettings() {
        print("🔄 [地区刷新] 开始刷新地区设置")
        
        guard let account = appStore.selectedAccount else {
            print("🔄 [地区刷新] 没有当前账户，使用系统推荐地区")
            // 移除默认US设置，让effectiveSearchRegion自动处理
            searchRegion = ""
            isUserSelectedRegion = false
            return
        }
        
        print("🔄 [地区刷新] 刷新账户地区: \(account.email) -> \(account.countryCode)")
        
        // 重置用户手动选择标志
        isUserSelectedRegion = false
        
        // 使用账户的地区代码
        searchRegion = account.countryCode
        
        // 强制刷新UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.uiRefreshTrigger = UUID()
        }
        
        print("🔄 [地区刷新] 地区设置已刷新: \(searchRegion)")
    }
    
    // 当前账户指示器
    private var currentAccountIndicator: some SwiftUI.View {
        HStack(spacing: 12) {
            // 账户信息
            VStack(alignment: .leading, spacing: 2) {
                if let account = appStore.selectedAccount {
                    Text("当前使用账户")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(account.email)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // 地区标签
                        Text(flag(country: account.countryCode))
                            .font(.caption)
                        
                        Text(SearchView.countryCodeMapChinese[account.countryCode] ?? account.countryCode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("未登录账户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 切换账户按钮
            if appStore.hasMultipleAccounts {
                Button("切换账户") {
                    showAccountMenu = true
                }
                .font(.caption)
                .foregroundColor(themeManager.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(themeManager.accentColor.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect()
        .padding(.horizontal, 16)
    }
    
    // 版本选择器账户指示器
    private var versionPickerAccountIndicator: some SwiftUI.View {
        HStack(spacing: 12) {
            // 账户信息
            VStack(alignment: .leading, spacing: 2) {
                if let account = appStore.selectedAccount {
                    Text("使用账户")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Text(account.email)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // 地区标签
                        Text(flag(country: account.countryCode))
                            .font(.caption2)
                        
                        Text(SearchView.countryCodeMapChinese[account.countryCode] ?? account.countryCode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("未登录账户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 切换账户按钮
            if appStore.hasMultipleAccounts {
                Button("切换") {
                    showVersionPicker = false
                    showAccountMenu = true
                }
                .font(.caption2)
                .foregroundColor(themeManager.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(themeManager.accentColor.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6).opacity(0.5))
        )
        .padding(.horizontal, 16)
    }
    
    // Apple ID缓存状态指示器
    private var cacheStatusIndicator: some SwiftUI.View {
        Button(action: {
            // 点击时重新验证或刷新连接
            print("Cache status indicator tapped")
            if !sessionManager.isSessionValid {
                // 如果连接断开，手动检查会话
                Task {
                    print("Checking session...")
                    await sessionManager.manualSessionCheck()
                }
            } else {
                // 如果已连接，重置会话状态
                print("Resetting session state...")
                sessionManager.resetSessionState()
            }
        }) {
            HStack(spacing: 6) {
                // 状态图标
                Image(systemName: cacheStatusIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                // 状态文字
                Text(cacheStatusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10) // 增加水平内边距
            .padding(.vertical, 6) // 增加垂直内边距
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cacheStatusGradient)
                    .shadow(color: cacheStatusColor.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(sessionManager.isReconnecting ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: sessionManager.isReconnecting)
        }
        .buttonStyle(.plain) 
        .contentShape(Rectangle()) // 确保整个区域都可点击
        .help(cacheStatusTooltip)
    }
    
    // 缓存状态图标
    private var cacheStatusIcon: String {
        if !sessionManager.isSessionValid {
            return "wifi.slash"
        } else if sessionManager.isReconnecting {
            return "arrow.clockwise"
        } else {
            return "checkmark.shield.fill"
        }
    }
    
    // 缓存状态颜色
    private var cacheStatusColor: Color {
        if !sessionManager.isSessionValid {
            return Color(red: 0.9, green: 0.2, blue: 0.2) // 现代红色
        } else if sessionManager.isReconnecting {
            return Color(red: 0.95, green: 0.6, blue: 0.1) // 现代橙色
        } else {
            return Color(red: 0.2, green: 0.7, blue: 0.3) // 现代绿色
        }
    }
    
    // 缓存状态渐变背景
    private var cacheStatusGradient: LinearGradient {
        if !sessionManager.isSessionValid {
            return LinearGradient(
                colors: [Color(red: 0.9, green: 0.2, blue: 0.2), Color(red: 0.8, green: 0.1, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if sessionManager.isReconnecting {
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.6, blue: 0.1), Color(red: 0.9, green: 0.5, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.7, blue: 0.3), Color(red: 0.1, green: 0.6, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // 缓存状态文字
    private var cacheStatusText: String {
        if !sessionManager.isSessionValid {
            return "连接断开"
        } else if sessionManager.isReconnecting {
            return "重新连接中"
        } else {
            return "已连接"
        }
    }
    
    // 缓存状态提示
    private var cacheStatusTooltip: String {
        if !sessionManager.isSessionValid {
            return "Apple ID连接已断开，请点击重新验证或重新登录"
        } else if sessionManager.isReconnecting {
            return "正在自动重新连接Apple ID，请稍候..."
        } else {
            return "Apple ID连接正常，可以正常搜索和下载app"
        }
    }
    
    // 处理app下载
    private func handleDownloadApp(_ app: iTunesSearchResult) {
        // 检查是否有登录账户
        guard let account = appStore.selectedAccount else {
            // 没有登录账户，直接跳转到官方App Store
            openAppStorePage(for: app)
            return
        }
        
        // 检查是否有购买记录
        Task {
            let check = await PurchaseManager.shared.checkAppOwnership(
                appIdentifier: String(app.trackId),
                account: account,
                countryCode: account.countryCode
            )
            
            switch check {
            case .success(let owned):
                if owned {
                    // 已拥有：直接进入历史版本选择界面
                    await MainActor.run {
                        loadVersionsForApp(app)
                    }
                } else {
                    // 没有购买记录，跳转到官方App Store
                    openAppStorePage(for: app)
                }
            case .failure:
                // 检查失败，跳转到官方App Store
                openAppStorePage(for: app)
            }
        }
    }
}
