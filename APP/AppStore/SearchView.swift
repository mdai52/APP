import SwiftUI
import UIKit

 extension Date {
     var iso8601: String {
         let formatter = ISO8601DateFormatter()
         return formatter.string(from: self)
     }
 }

func withTimeout<T>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in

        let timeoutTask = Task { () -> T in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }

        group.addTask { [timeoutTask] in
            defer { timeoutTask.cancel() }
            return try await operation()
        }

        let result = try await group.next()
        group.cancelAll()

        if let result = result {
            return result
        } else {
            throw CancellationError()
        }
    }
}

struct EnhancedAppCard: SwiftUI.View {
    let app: iTunesSearchResult
    let onTap: () -> Void
    let onGetAction: () -> Void
    @Binding var isDownloading: Bool
    @SwiftUI.EnvironmentObject var themeManager: ThemeManager

    var body: some SwiftUI.View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                topSection

                if !getFeatureTags().isEmpty {
                    featuresSection
                }

                if let screenshots = app.screenshotUrls, !screenshots.isEmpty {
                    screenshotsSection(screenshots)
                }
            }
            .padding()
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(0.98)
    }

    private func getFeatureTags() -> [String] {
        var tags: [String] = []

        if let genres = app.genres, !genres.isEmpty {
            tags.append(contentsOf: genres.prefix(3))
        } else if let primaryGenre = app.primaryGenreName {

            tags.append(primaryGenre)
        }

        if let developer = app.artistName, !tags.contains(developer) {
            tags.append(developer)
        }

        let result = Array(Set(tags)).prefix(3).map { $0 }
        print("App: \(app.name), Genres: \(app.genres ?? []), Primary Genre: \(app.primaryGenreName ?? "nil"), Feature Tags: \(result)")
        return result
    }

    private var topSection: some SwiftUI.View {
        HStack(alignment: .center, spacing: 12) {

            appIcon

            VStack(alignment: .leading, spacing: 4) {

                Text(app.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if let developer = app.artistName {
                    Text(developer)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

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

            getButton
        }
    }

    private var featuresSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            Text("功能标签")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(getFeatureTags(), id: \.self) {
                        Text($0)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
            }
        }
    }

    private func screenshotsSection(_ screenshots: [String]) -> some SwiftUI.View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(screenshots.prefix(3), id: \.self) { screenshotURL in
                    if let url = URL(string: screenshotURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.2)
                            }
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

    private var appIcon: some SwiftUI.View {
        AnyView(
            Group {
                if let iconURL = app.artworkUrl100, let url = URL(string: iconURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                    )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "app.fill")
                                .foregroundColor(.gray)
                        )
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                        )
                }
            }
        )
    }

    private var getButton: some SwiftUI.View {
        Group {
            if isDownloading {

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

                Button(action: onGetAction) {
                    Text(app.formattedPrice == "免费" || app.price == 0 ? "获取" : (app.formattedPrice ?? "查看"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
    }

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

    }
}

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

struct AppReview: Codable, Identifiable {
    let id: String
    let userName: String
    let rating: Double
    let title: String
    let content: String
    let date: Date
    let version: String
}

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

                let appID = Int(self.appID) ?? 0
                if appID > 0 {
                    let apiReviews = try await iTunesClient.shared.reviews(id: appID)

                    self.reviews = apiReviews.map { apiReview in

                        let dateFormatter = ISO8601DateFormatter()
                        let date = dateFormatter.date(from: apiReview.updated) ?? Date()

                        return AppReview(
                            id: apiReview.id,
                            userName: apiReview.userName,
                            rating: Double(apiReview.score),
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

struct ReviewCard: SwiftUI.View {
    let review: AppReview

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(review.userName)
                        .font(.headline)

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

struct EnhancedAppDetailView: SwiftUI.View {
    let app: iTunesSearchResult

    var onPrimaryAction: ((iTunesSearchResult) -> Void)? = nil
    @Binding var isDownloading: Bool
    @SwiftUI.Environment(\.dismiss) var dismiss
    @SwiftUI.EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                headerSection

                if let screenshots = app.screenshotUrls, !screenshots.isEmpty {
                    screenshotsSection(screenshots)
                }

                if let rating = app.averageUserRating, rating > 0 {
                    ratingsSection

                    AppReviewsView(appID: String(app.trackId))
                        .padding(.horizontal, 16)
                        .frame(height: 300)
                }

                if let description = app.description {
                    descriptionSection(description)
                }

                informationSection

                if let releaseNotes = app.releaseNotes, !releaseNotes.isEmpty {
                    updateNotesSection(releaseNotes)
                }

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

    private var headerSection: some SwiftUI.View {
        HStack(alignment: .top, spacing: 16) {

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

                HStack(spacing: 8) {

                    Button(action: { onPrimaryAction?(app) }) {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 20, height: 20)
                                .padding(.horizontal, 16)
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
                    .disabled(isDownloading)

                }
            }
        }
        .padding(.vertical)
    }

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

    private var ratingsSection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 16) {
            Text("评分与评论")
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 40) {

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
    @EnvironmentObject var appStore: AppStore
    @StateObject private var regionValidator = RegionValidator.shared
    @StateObject private var sessionManager = SessionManager.shared
    @State var searching = false

    @State var searchRegion: String = ""
    @State var showRegionPicker = false

    @State var isUserSelectedRegion: Bool = false

    @State var uiRefreshTrigger = UUID()

    @State var showLoginSheet = false
    @State var showAccountMenu = false

    @State var isDownloading = false

    @State var purchasingTrackId: Int?

    @State private var cachedAvatarImage: UIImage?

    var effectiveSearchRegion: String {

        if isUserSelectedRegion && !searchRegion.isEmpty {

            return searchRegion
        } else if let currentAccount = appStore.selectedAccount {

            return currentAccount.countryCode
        } else if !searchRegion.isEmpty {

            return searchRegion
        }

        let languageCode = Locale.current.languageCode ?? ""
        return getRegionFromLanguageCode(languageCode)
    }

    private func getRegionFromLanguageCode(_ languageCode: String) -> String {
        switch languageCode {
        case "zh":
            return "CN"
        case "ja":
            return "JP"
        case "ko":
            return "KR"
        case "de":
            return "DE"
        case "fr":
            return "FR"
        case "es":
            return "ES"
        case "it":
            return "IT"
        case "pt":
            return "BR"
        case "ru":
            return "RU"
        case "ar":
            return "SA"
        case "hi":
            return "IN"
        case "th":
            return "TH"
        case "vi":
            return "VN"
        case "id":
            return "ID"
        case "ms":
            return "MY"
        case "tr":
            return "TR"
        case "pl":
            return "PL"
        case "nl":
            return "NL"
        case "sv":
            return "SE"
        case "da":
            return "DK"
        case "no":
            return "NO"
        case "fi":
            return "FI"
        case "cs":
            return "CZ"
        case "hu":
            return "HU"
        case "ro":
            return "RO"
        case "bg":
            return "BG"
        case "hr":
            return "HR"
        case "sk":
            return "SK"
        case "sl":
            return "SI"
        case "et":
            return "EE"
        case "lv":
            return "LV"
        case "lt":
            return "LT"
        case "el":
            return "GR"
        case "he":
            return "IL"
        case "fa":
            return "IR"
        case "ur":
            return "PK"
        case "bn":
            return "BD"
        case "si":
            return "LK"
        case "my":
            return "MM"
        case "km":
            return "KH"
        case "lo":
            return "LA"
        case "ne":
            return "NP"
        case "ka":
            return "GE"
        case "hy":
            return "AM"
        case "az":
            return "AZ"
        case "kk":
            return "KZ"
        case "ky":
            return "KG"
        case "uz":
            return "UZ"
        case "tg":
            return "TJ"
        case "mn":
            return "MN"
        case "bo":
            return "CN"
        case "ug":
            return "CN"
        case "en":
            return "US"
        default:
            return "US"
        }
    }

    var currentRegionDisplayName: String {
        let regionCode = effectiveSearchRegion
        return SearchView.countryCodeMapChinese[regionCode] ?? SearchView.countryCodeMap[regionCode] ?? regionCode
    }

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

    var currentRegionFlag: String {
        flag(country: effectiveSearchRegion)
    }

    var sortedRegionKeys: [String] {
        var regions = Array(SearchView.storeFrontCodeMap.keys)

        if let currentAccount = appStore.selectedAccount {
            let accountRegion = currentAccount.countryCode
            if let index = regions.firstIndex(of: accountRegion) {
                regions.remove(at: index)
                regions.insert(accountRegion, at: 0)
            }
        }

        let commonRegions = ["US", "CN", "HK", "MO", "TW", "JP", "KR", "GB", "DE", "FR", "CA", "AU", "IT", "ES", "NL", "SE", "NO", "DK", "FI", "RU", "BR", "MX", "IN", "SG", "TH", "VN", "MY", "ID", "PH"]

        for commonRegion in commonRegions.reversed() {
            if let index = regions.firstIndex(of: commonRegion) {
                regions.remove(at: index)
                regions.insert(commonRegion, at: 0)
            }
        }

        return regions
    }

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

    var regionKeys: [String] { sortedRegionKeys }

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

    @State var showVersionPicker = false
    @State var selectedApp: iTunesSearchResult?
    @State var availableVersions: [StoreAppVersion] = []
    @State var versionHistory: [iTunesClient.AppVersionInfo] = []

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

                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {

                                modernSearchBar
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateHeader)
                                    .id("searchBar")

                                categorySelector
                                    .scaleEffect(animateHeader ? 1 : 0.95)
                                    .opacity(animateHeader ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateHeader)

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

            sessionManager.startSessionMonitoring()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("[SearchView] 执行智能地区检测")
                detectAndSetRegion()

                print("[SearchView] 初始化完成 - 最终状态:")
                print("  - searchRegion: \(searchRegion)")
                print("  - effectiveSearchRegion: \(effectiveSearchRegion)")
                if let account = appStore.selectedAccount {
                    print("  - 登录账户: \(account.email), 地区: \(account.countryCode)")
                } else {
                    print("  - 未登录账户")
                }

                self.uiRefreshTrigger = UUID()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[SearchView] 强制刷新UI")
                startAnimations()
            }
        }
        .onDisappear {

            sessionManager.stopSessionMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshUI"))) { _ in

            print("[SearchView] 接收到强制刷新通知")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[SearchView] 真机适配强制刷新完成")
                startAnimations()
            }
        }
        .onReceive(appStore.$selectedAccount) { account in

            if let newAccount = account {
                print("[SearchView] 检测到账户变化: \(newAccount.email), 地区: \(newAccount.countryCode)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detectAndSetRegion()

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

    private func detectAndSetRegion() {

        if let currentAccount = appStore.selectedAccount {
            let accountRegion = currentAccount.countryCode
            print("[SearchView] 检测到登录账户: \(currentAccount.email), 地区代码: \(accountRegion)")

            if searchRegion != accountRegion && !isUserSelectedRegion {
                searchRegion = accountRegion
                print("[SearchView] 已将搜索地区更新为账户地区: \(searchRegion)")
            }
        } else {

            let detectedRegion = effectiveSearchRegion
            if searchRegion != detectedRegion && !isUserSelectedRegion {
                searchRegion = detectedRegion
                print("[SearchView] 未检测到登录账户，使用默认地区: \(searchRegion)")
            }
        }

        print("[SearchView] 当前显示地区: \(effectiveSearchRegion), 用户手动选择标志: \(isUserSelectedRegion)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {

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

            self.uiRefreshTrigger = UUID()
        }
    }

    var modernSearchBar: some SwiftUI.View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("游戏、App", text: $searchKey)
                    .font(.body)
                    .focused($searchKeyFocused)
                    .onChange(of: searchKey) { newValue in
                        if !newValue.isEmpty {
                            showSearchSuggestions = true

                            searchSuggestions = getSearchSuggestions(for: newValue)

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
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        searchKeyFocused ? .blue : Color.clear,
                        lineWidth: 2
                    )
            )
            .padding(.top, 8)

            HStack(spacing: 16) {

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

                Spacer()

                compactAccountCapsule

                Spacer()

                smartRegionSelector
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }

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

                if let currentAccount = appStore.selectedAccount {

                    let isRegionValid = (effectiveSearchRegion == currentAccount.countryCode)

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
                        .help(appStore.selectedAccount != nil ? "来自账户: \(SearchView.countryCodeMapChinese[appStore.selectedAccount!.countryCode] ?? SearchView.countryCodeMap[appStore.selectedAccount!.countryCode] ?? appStore.selectedAccount!.countryCode)" : "默认美区")
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
        .id("RegionSelector-\(effectiveSearchRegion)-\(uiRefreshTrigger)")
        .onAppear {

            print("[SearchView] 地区选择器显示，当前地区: \(effectiveSearchRegion)")
        }
    }

    private var compactAccountCapsule: some SwiftUI.View {
        Menu {
            if appStore.selectedAccount == nil {
                Button("登录") { showLoginSheet = true }
            } else {
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
                Button("添加Apple ID") { showLoginSheet = true }
                Divider()
                Button("登出", role: .destructive) { logoutAccount() }
            }
        } label: {
            if let image = cachedAvatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(themeManager.accentColor.opacity(0.5), lineWidth: 1.5))
            } else {
                Image(systemName: appStore.selectedAccount == nil ? "person.circle" : "person.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(appStore.selectedAccount == nil ? .secondary : themeManager.accentColor)
            }
        }
        .onAppear { loadAvatar() }
        .onChange(of: appStore.selectedAccount?.email, perform: { _ in loadAvatar() })
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
                    UserDefaults.standard.set(data, forKey: cacheKey)
                    await MainActor.run { cachedAvatarImage = image }
                }
            } catch {}
        }
    }

    var regionPickerSheet: some SwiftUI.View {
        NavigationView {
            VStack(spacing: 0) {

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

                            if isUserSelectedRegion && !searchRegion.isEmpty {
                                Text("用户手动选择")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            } else if let currentAccount = appStore.selectedAccount {
                                Text("来自登录账户: \(currentAccount.email)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            
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

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("搜索地区...", text: $searchInput)
                        .font(.title3)
                        .onChange(of: searchInput) { newValue in

                            if newValue.isEmpty {

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

                                if isUserSelectedRegion && regionCode == searchRegion {
                                    Image(systemName: "hand.point.up.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                        .help("用户手动选择")
                                } else if let currentAccount = appStore.selectedAccount, regionCode == currentAccount.countryCode {

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

    var accountStatusBar: some SwiftUI.View {
        VStack(spacing: 0) {
            if let currentAccount = appStore.selectedAccount {

                HStack(spacing: 16) {

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

                HStack(spacing: 16) {
                    Image(systemName: "person.circle")
                        .font(.title)
                        .foregroundColor(.secondary)

                    Spacer()

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

    private func selectRegion(_ regionCode: String) {
        searchRegion = regionCode
        isUserSelectedRegion = true
        print("[SearchView] 用户选择地区: \(regionCode)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.uiRefreshTrigger = UUID()
        }

        if !searchResult.isEmpty {
            searchResult = []
            Task {
                await performSearch()
            }
        }

        showRegionPicker = false

        print("[SearchView] 地区选择完成，当前搜索地区: \(searchRegion)")
        print("[SearchView] 用户手动选择标志: \(isUserSelectedRegion)")
        print("[SearchView] effectiveSearchRegion: \(effectiveSearchRegion)")
    }

    var searchHistorySection: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("最近搜索", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        clearSearchHistory()
                    }
                }) {
                    Text("清除全部")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(searchHistory.prefix(8), id: \.self) { history in
                        HStack(spacing: 6) {
                            Button(action: {
                                searchKey = history
                                showSearchHistory = false
                                Task {
                                    await performSearch()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12))
                                    Text(history)
                                        .font(.caption)
                                }
                                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                                .foregroundColor(.primary)
                            }

                            Button(action: {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    removeFromHistory(history)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 15)
        .padding(.horizontal, 16)
    }

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

    var categorySelector: some SwiftUI.View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    var searchResultsSection: some SwiftUI.View {
        VStack(spacing: 16) {
            if !searchResult.isEmpty {

                currentAccountIndicator

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

                }
                .padding(.horizontal, 16)
            }

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

    var searchingIndicator: some SwiftUI.View {
        VStack(spacing: 24) {

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

    var emptyStateView: some SwiftUI.View {
        VStack(spacing: 24) {

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

            if !searchHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索历史")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(searchHistory.prefix(3), id: \.self) { history in
                            HStack(spacing: 4) {
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

                                Button {
                                    withAnimation(.easeInOut) {
                                        removeFromHistory(history)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
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

    func searchErrorView(error: String) -> any SwiftUI.View {
        VStack(spacing: 24) {

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

    var searchResultsGrid: some SwiftUI.View {
        Group {

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

    func resultCardView(item: iTunesSearchResult, index: Int) -> any SwiftUI.View {
        return EnhancedAppCard(app: item, onTap: {

            let appDetailView = EnhancedAppDetailView(
                app: item,
                onPrimaryAction: { appToDownload in

                    handleDownloadApp(appToDownload)
                },
                isDownloading: $isDownloading
            )
            .environmentObject(themeManager)

            let hostingController = UIHostingController(rootView: appDetailView)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.rootViewController?.present(hostingController, animated: true)
            }
        }, onGetAction: {

            handleDownloadApp(item)
        }, isDownloading: $isDownloading)
        .environmentObject(themeManager)
    }

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

        searchHistory.removeAll { $0 == trimmedQuery }

        searchHistory.insert(trimmedQuery, at: 0)

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

                let regionToUse = effectiveSearchRegion
                let response = try await iTunesClient.shared.search(
                    term: searchKey,
                    limit: pageSize,
                    countryCode: regionToUse,
                    deviceFamily: searchType
                )
                let results = response ?? []
                await MainActor.run {

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

    private func bestArtworkURL(from512: String?, fallback100: String?) -> String {
        if var url = from512, !url.isEmpty {

            url = url.replacingOccurrences(of: "/512x512bb", with: "/1024x1024bb")
            return url
        }
        return from512 ?? fallback100 ?? ""
    }

    func purchaseButton(item: iTunesSearchResult) -> some SwiftUI.View {
        Group {
            if (item.price ?? 0.0) == 0.0 {
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

    func purchaseFreeAppIfNeeded(item: iTunesSearchResult) async {
        guard let account = appStore.selectedAccount else {
            purchaseAlertText = "请先登录账号再获取app"
            showPurchaseAlert = true
            return
        }
        let currentId = item.trackId
        await MainActor.run { purchasingTrackId = currentId }
        defer { Task { await MainActor.run { purchasingTrackId = nil } } }

        let check = await PurchaseManager.shared.checkAppOwnership(
            appIdentifier: String(item.trackId),
            account: account,
            countryCode: account.countryCode
        )
        switch check {
        case .success(let owned):
            if owned {

                await MainActor.run {
                    loadVersionsForApp(item)
                }
                return
            } else {

                openAppStorePage(for: item)
                return
            }
        case .failure:

            openAppStorePage(for: item)
            return
        }
    }

    private func openAppStorePage(for item: iTunesSearchResult) {
        let urlStr = item.trackViewUrl
        guard let url = URL(string: urlStr) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    func loadVersionsForApp(_ app: iTunesSearchResult) {

        selectedApp = app
        isLoadingVersions = true
        versionError = nil
        availableVersions = []
        showVersionPicker = true

        Task {
            do {
                print("[SearchView] 开始加载app版本: \(app.trackName)")

                guard let account = appStore.selectedAccount else {
                    throw NSError(domain: "SearchView", code: -1, userInfo: [NSLocalizedDescriptionKey: "未登录账户，无法获取版本信息"])
                }

                let accountCopy = account

                let storeVersionsResult = await StoreClient.shared.getAppVersions(
                    trackId: String(app.trackId),
                    account: accountCopy,
                    countryCode: effectiveSearchRegion
                )

                let histResult = try? await withTimeout(seconds: 3) {
                    try await iTunesClient.shared.versionHistory(id: app.trackId, country: effectiveSearchRegion)
                }
                let hist = histResult ?? []

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

    var versionPickerSheet: some SwiftUI.View {
        NavigationView {
            ZStack {

                LinearGradient(
                    colors: themeManager.selectedTheme == .dark ?
                        [Color(.systemBackground), Color(.secondarySystemBackground)] :
                        [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {

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

                VStack(spacing: 16) {

                    AsyncImage(url: URL(string: selectedApp?.artworkUrl512 ?? "")) {
                        image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    } placeholder: {
                        Image(systemName: "app.fill")
                            .font(.system(size: 64))
                            .foregroundColor(themeManager.accentColor.opacity(0.3))
                    }
                    .frame(width: 100, height: 100)

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
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

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

                ForEach(availableVersions, id: \.versionId) {
                    AnyView(createModernVersionRow(version: $0))
                }
            }
            .padding(.bottom, 24)
        }
    }
    private func createModernVersionRow(version: StoreAppVersion) -> any SwiftUI.View {
        HStack(spacing: 16) {

            VStack(alignment: .leading, spacing: 8) {

                VStack(alignment: .leading, spacing: 4) {

                    Text(getVersionNumber(version: version))
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(themeManager.accentColor.opacity(0.1))
                        )

                    if let date = getVersionDate(version: version) {
                        Text(date)
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
                }

                if let note = shortReleaseNote(for: version) {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

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

            Button(action: {
                Task {
                    if let app = selectedApp {

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

    private func displayVersionTitle(version: StoreAppVersion) -> String {

        if let date = version.formattedReleaseDate {
            return "版本 \(version.versionString) · \(date)"
        }

        if let h = versionHistory.first(where: { $0.version == version.versionString }) {
            return "版本 \(h.version) · \(h.formattedDate)"
        }

        if let h = versionHistory.first(where: { version.versionString.hasPrefix($0.version) || $0.version.hasPrefix(version.versionString) }) {
            return "版本 \(version.versionString) · \(h.formattedDate)"
        }

        if let latestVersion = versionHistory.first {
            return "版本 \(version.versionString) · \(latestVersion.formattedDate)"
        }

        return "版本 \(version.versionString)"
    }

    private func getVersionNumber(version: StoreAppVersion) -> String {
        return "版本 \(version.versionString)"
    }

    private func getVersionDate(version: StoreAppVersion) -> String? {

        if let date = version.formattedReleaseDate {
            return date
        }

        if let h = versionHistory.first(where: { $0.version == version.versionString }) {
            return h.formattedDate
        }

        if let h = versionHistory.first(where: { version.versionString.hasPrefix($0.version) || $0.version.hasPrefix(version.versionString) }) {
            return h.formattedDate
        }

        if let latestVersion = versionHistory.first {
            return latestVersion.formattedDate
        }

        return nil
    }

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

        let downloadId = UnifiedDownloadManager.shared.addDownload(
            bundleIdentifier: app.bundleId,
            name: app.trackName,
            version: version.versionString,
            identifier: appId,
            iconURL: app.artworkUrl512,
            versionId: version.versionId
        )
        print("[SearchView] 已将下载请求添加到下载管理器，ID: \(downloadId)")

        if let request = UnifiedDownloadManager.shared.downloadRequests.first(where: { $0.id == downloadId }) {
            UnifiedDownloadManager.shared.startDownload(for: request)
        } else {
            print("[SearchView] 无法找到刚添加的下载请求")
        }
    }

    var accountMenuSheet: some SwiftUI.View {
        NavigationView {
            if appStore.savedAccounts.isEmpty {

                VStack(spacing: 24) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 48))
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

                multiAccountManagementView
            }
        }
        .navigationViewStyle(.stack)
    }

    var multiAccountManagementView: some SwiftUI.View {
        VStack(spacing: 0) {

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

    private func logoutAccount() {
        print("[SearchView] 用户登出")
        appStore.logoutAccount()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.uiRefreshTrigger = UUID()
        }
    }

    private func refreshRegionSettings() {
        print("🔄 [地区刷新] 开始刷新地区设置")

        guard let account = appStore.selectedAccount else {
            print("🔄 [地区刷新] 没有当前账户，使用系统推荐地区")

            searchRegion = ""
            isUserSelectedRegion = false
            return
        }

        print("🔄 [地区刷新] 刷新账户地区: \(account.email) -> \(account.countryCode)")

        isUserSelectedRegion = false

        searchRegion = account.countryCode

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.uiRefreshTrigger = UUID()
        }

        print("🔄 [地区刷新] 地区设置已刷新: \(searchRegion)")
    }

    private var currentAccountIndicator: some SwiftUI.View {
        HStack(spacing: 12) {

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

                        Text(flag(country: account.countryCode))
                            .font(.caption)

                        Text(SearchView.countryCodeMapChinese[account.countryCode] ?? account.countryCode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

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
        .padding(.horizontal, 16)
    }

    private var versionPickerAccountIndicator: some SwiftUI.View {
        HStack(spacing: 12) {

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

                        Text(flag(country: account.countryCode))
                            .font(.caption2)

                        Text(SearchView.countryCodeMapChinese[account.countryCode] ?? account.countryCode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

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

    private var cacheStatusIndicator: some SwiftUI.View {
        Button(action: {

            print("Cache status indicator tapped")
            if !sessionManager.isSessionValid {

                Task {
                    print("Checking session...")
                    await sessionManager.manualSessionCheck()
                }
            } else {

                print("Resetting session state...")
                sessionManager.resetSessionState()
            }
        }) {
            HStack(spacing: 6) {

                Image(systemName: cacheStatusIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                Text(cacheStatusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cacheStatusGradient)
                    .shadow(color: cacheStatusColor.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(sessionManager.isReconnecting ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: sessionManager.isReconnecting)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(cacheStatusTooltip)
    }

    private var cacheStatusIcon: String {
        if !sessionManager.isSessionValid {
            return "wifi.slash"
        } else if sessionManager.isReconnecting {
            return "arrow.clockwise"
        } else {
            return "checkmark.shield.fill"
        }
    }

    private var cacheStatusColor: Color {
        if !sessionManager.isSessionValid {
            return Color(red: 0.9, green: 0.2, blue: 0.2)
        } else if sessionManager.isReconnecting {
            return Color(red: 0.95, green: 0.6, blue: 0.1)
        } else {
            return Color(red: 0.2, green: 0.7, blue: 0.3)
        }
    }

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

    private var cacheStatusText: String {
        if !sessionManager.isSessionValid {
            return "连接断开"
        } else if sessionManager.isReconnecting {
            return "重新连接中"
        } else {
            return "已连接"
        }
    }

    private var cacheStatusTooltip: String {
        if !sessionManager.isSessionValid {
            return "Apple ID连接已断开，请点击重新验证或重新登录"
        } else if sessionManager.isReconnecting {
            return "正在自动重新连接Apple ID，请稍候..."
        } else {
            return "Apple ID连接正常，可以正常搜索和下载app"
        }
    }

    private func handleDownloadApp(_ app: iTunesSearchResult) {

        guard let account = appStore.selectedAccount else {

            openAppStorePage(for: app)
            return
        }

        Task {
            let check = await PurchaseManager.shared.checkAppOwnership(
                appIdentifier: String(app.trackId),
                account: account,
                countryCode: account.countryCode
            )

            switch check {
            case .success(let owned):
                if owned {

                    await MainActor.run {
                        loadVersionsForApp(app)
                    }
                } else {

                    openAppStorePage(for: app)
                }
            case .failure:

                openAppStorePage(for: app)
            }
        }
    }

}
