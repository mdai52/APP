import UIKit
import CryptoKit

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    subscript(url: URL) -> UIImage? {
        get {
            return cache.object(forKey: url.absoluteString as NSString)
        }
        set {
            if let image = newValue {
                cache.setObject(image, forKey: url.absoluteString as NSString)
            } else {
                cache.removeObject(forKey: url.absoluteString as NSString)
            }
        }
    }
}

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
