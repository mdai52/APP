import SwiftUI
import Combine
import UIKit

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var error: Error?
    
    private var cancellable: AnyCancellable?
    private let url: URL
    
    init(url: URL) {
        self.url = url
        loadImage()
    }
    
    deinit {
        cancel()
    }
    
    func loadImage() {
        // Check cache first
        if let cachedImage = ImageCache.shared[url] {
            self.image = cachedImage
            return
        }
        
        // If not in cache, download it
        let currentURL = url // Capture the URL to avoid strong reference cycle
        cancellable = URLSession.shared.dataTaskPublisher(for: currentURL)
            .map { UIImage(data: $0.data) }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] image in
                    guard let self = self, let image = image else { return }
                    // Cache the image
                    ImageCache.shared[currentURL] = image
                    self.image = image
                }
            )
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}

struct ImageView: View {
    @StateObject private var loader: ImageLoader
    private let placeholder: Image
    private let configuration: (Image) -> Image
    
    init(
        url: URL,
        placeholder: Image = Image(systemName: "photo"),
        configuration: @escaping (Image) -> Image = { $0 }
    ) {
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.placeholder = placeholder
        self.configuration = configuration
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                configuration(Image(uiImage: image))
            } else if loader.error != nil {
                placeholder
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
            }
        }
        .onAppear { loader.loadImage() }
    }
}
