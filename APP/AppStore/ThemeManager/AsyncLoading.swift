//
//  AsyncLoading.swift
//  APP
//
//  Created by pxx917144686 on 2026/02/10.
//

import SwiftUI
import Combine

// MARK: - 异步加载状态枚举
enum AsyncLoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
}

// MARK: - 异步加载视图
struct AsyncLoadingView<Input: Hashable, Output, Content: View, LoadingContent: View, ErrorContent: View>: View {
    let input: Input
    let task: @Sendable (Input) async throws -> Output
    let content: (Output) -> Content
    let loadingContent: () -> LoadingContent
    let errorContent: (Error) -> ErrorContent
    let autoRefresh: Bool
    
    @State private var state: AsyncLoadingState<Output> = .idle
    @State private var cancellables = Set<AnyCancellable>()
    
    init(
        input: Input,
        task: @escaping @Sendable (Input) async throws -> Output,
        @ViewBuilder content: @escaping (Output) -> Content,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent = { LoadingStateView(message: "正在加载...", isFullScreen: true) },
        @ViewBuilder errorContent: @escaping (Error) -> ErrorContent = { error in 
            EmptyStateView(
                message: "加载失败: \(error.localizedDescription)",
                imageName: "exclamationmark.triangle"
            )
        },
        autoRefresh: Bool = true
    ) {
        self.input = input
        self.task = task
        self.content = content
        self.loadingContent = loadingContent
        self.errorContent = errorContent
        self.autoRefresh = autoRefresh
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                loadingContent()
            case .loading:
                loadingContent()
            case .success(let output):
                content(output)
            case .failure(let error):
                errorContent(error)
                    .onTapGesture {
                        retry()
                    }
            }
        }
        .onAppear {
            if autoRefresh {
                load()
            }
        }
        .onChange(of: input) {
            if autoRefresh {
                load()
            }
        }
    }
    
    func load() {
        Task {
            await performLoad()
        }
    }
    
    func retry() {
        Task {
            await performLoad()
        }
    }
    
    @Sendable
    private func performLoad() async {
        state = .loading
        do {
            let output = try await task(input)
            state = .success(output)
        } catch {
            state = .failure(error)
        }
    }
}

// MARK: - 带缓存的异步加载
class AsyncCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private var lock = NSLock()
    
    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
    
    func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = value
    }
    
    func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
    
    func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache[key] != nil
    }
}

// MARK: - 带缓存的异步加载视图
struct AsyncCachedLoadingView<Key: Hashable, Value, Content: View, LoadingContent: View, ErrorContent: View>: View {
    let key: Key
    let task: @Sendable (Key) async throws -> Value
    let content: (Value) -> Content
    let loadingContent: () -> LoadingContent
    let errorContent: (Error) -> ErrorContent
    let cache: AsyncCache<Key, Value>
    let forceRefresh: Bool
    
    @State private var state: AsyncLoadingState<Value> = .idle
    
    init(
        key: Key,
        task: @escaping @Sendable (Key) async throws -> Value,
        cache: AsyncCache<Key, Value>,
        forceRefresh: Bool = false,
        @ViewBuilder content: @escaping (Value) -> Content,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent = { LoadingStateView(message: "正在加载...", isFullScreen: true) },
        @ViewBuilder errorContent: @escaping (Error) -> ErrorContent = { error in 
            EmptyStateView(
                message: "加载失败: \(error.localizedDescription)",
                imageName: "exclamationmark.triangle"
            )
        }
    ) {
        self.key = key
        self.task = task
        self.content = content
        self.loadingContent = loadingContent
        self.errorContent = errorContent
        self.cache = cache
        self.forceRefresh = forceRefresh
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                if let cachedValue = cache.get(key) {
                    content(cachedValue)
                } else {
                    loadingContent()
                }
            case .loading:
                if let cachedValue = cache.get(key), !forceRefresh {
                    content(cachedValue)
                        .opacity(0.7)
                        .overlay(
                            loadingContent()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        )
                } else {
                    loadingContent()
                }
            case .success(let value):
                content(value)
            case .failure(let error):
                if let cachedValue = cache.get(key) {
                    content(cachedValue)
                        .opacity(0.7)
                        .overlay(
                            errorContent(error)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.3))
                                .onTapGesture {
                                    retry()
                                }
                        )
                } else {
                    errorContent(error)
                        .onTapGesture {
                            retry()
                        }
                }
            }
        }
        .onAppear {
            if cache.get(key) == nil || forceRefresh {
                load()
            }
        }
        .onChange(of: key) {
            if cache.get(key) == nil || forceRefresh {
                load()
            } else {
                state = .success(cache.get(key)!)
            }
        }
    }
    
    func load() {
        Task {
            await performLoad()
        }
    }
    
    func retry() {
        Task {
            await performLoad()
        }
    }
    
    @Sendable
    private func performLoad() async {
        state = .loading
        do {
            let value = try await task(key)
            cache.set(key, value: value)
            state = .success(value)
        } catch {
            state = .failure(error)
        }
    }
}

// MARK: - 图片缓存
class ImageCache {
    static let shared = ImageCache()
    
    private var cache = AsyncCache<URL, UIImage>()
    private var lock = NSLock()
    
    private init() {}
    
    func get(_ url: URL) -> UIImage? {
        return cache.get(url)
    }
    
    func set(_ url: URL, image: UIImage) {
        cache.set(url, value: image)
    }
    
    func remove(_ url: URL) {
        cache.remove(url)
    }
    
    func clear() {
        cache.clear()
    }
    
    func contains(_ url: URL) -> Bool {
        return cache.contains(url)
    }
    
    func prefetch(_ urls: [URL]) {
        for url in urls {
            if !contains(url) {
                Task {
                    await loadImage(from: url)
                }
            }
        }
    }
    
    @Sendable
    private func loadImage(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                set(url, image: image)
            }
        } catch {
            print("Failed to prefetch image: \(error)")
        }
    }
}

// MARK: - 高级异步图片加载
struct AdvancedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let transition: AnyTransition
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var error: Error?
    
    init(
        url: URL?, 
        @ViewBuilder content: @escaping (Image) -> Content,
        transition: AnyTransition = .opacity
    ) {
        self.url = url
        self.content = content
        self.transition = transition
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
                    .transition(transition)
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .defaultSkeleton(isLoading: true)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .opacity(0.5)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            isLoading = false
            error = nil
            return
        }
        
        // 检查缓存
        if let cachedImage = ImageCache.shared.get(url) {
            image = cachedImage
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let loadedImage = UIImage(data: data) {
                    // 保存到缓存
                    ImageCache.shared.set(url, image: loadedImage)
                    await MainActor.run {
                        image = loadedImage
                        isLoading = false
                    }
                } else {
                    throw NSError(domain: "AdvancedAsyncImage", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 分页加载
struct PaginationView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let loadMore: () -> Void
    let hasMore: Bool
    let isLoadingMore: Bool
    let threshold: CGFloat
    
    init(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content,
        loadMore: @escaping () -> Void,
        hasMore: Bool,
        isLoadingMore: Bool,
        threshold: CGFloat = 200
    ) {
        self.items = items
        self.content = content
        self.loadMore = loadMore
        self.hasMore = hasMore
        self.isLoadingMore = isLoadingMore
        self.threshold = threshold
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) {
                    content($0)
                }
                
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if hasMore {
                    Color.clear
                        .frame(height: threshold)
                        .onAppear {
                            loadMore()
                        }
                }
            }
        }
    }
}

// MARK: - 无限滚动视图
struct InfiniteScrollView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let loadMore: () async -> Void
    let hasMore: Bool
    let isLoadingMore: Bool
    let threshold: CGFloat
    
    init(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content,
        loadMore: @escaping () async -> Void,
        hasMore: Bool,
        isLoadingMore: Bool,
        threshold: CGFloat = 200
    ) {
        self.items = items
        self.content = content
        self.loadMore = loadMore
        self.hasMore = hasMore
        self.isLoadingMore = isLoadingMore
        self.threshold = threshold
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items) {
                    content($0)
                }
                
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if hasMore {
                    Color.clear
                        .frame(height: threshold)
                        .onAppear {
                            Task {
                                await loadMore()
                            }
                        }
                }
            }
        }
    }
}
